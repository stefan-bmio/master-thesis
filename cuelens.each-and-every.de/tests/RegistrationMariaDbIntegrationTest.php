<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/registration.php';

final class RegistrationMariaDbIntegrationTest extends TestCase
{
    private PDO $pdo;

    protected function setUp(): void
    {
        $database = getenv('CUELENS_TEST_DB_NAME');
        $user = getenv('CUELENS_TEST_DB_USER');
        if ($database === false || $database === '' || $user === false || $user === '') {
            self::markTestSkipped(
                'Set CUELENS_TEST_DB_NAME and CUELENS_TEST_DB_USER for the MariaDB integration test.'
            );
        }

        $host = getenv('CUELENS_TEST_DB_HOST') ?: '127.0.0.1';
        $port = getenv('CUELENS_TEST_DB_PORT') ?: '3306';
        $password = getenv('CUELENS_TEST_DB_PASS') ?: '';
        $this->pdo = new PDO(
            "mysql:host={$host};port={$port};dbname={$database};charset=utf8mb4",
            $user,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        $this->pdo->exec(
            'CREATE TEMPORARY TABLE register (
                created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                email varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                name varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                iban varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                bic varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                age int NOT NULL,
                cigarettes int NOT NULL,
                studyinfo tinyint(1) DEFAULT 0,
                dataprot tinyint(1) DEFAULT 0,
                doi_token varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                doi tinyint(1) NOT NULL DEFAULT 0,
                app_token_issued_at timestamp NULL DEFAULT NULL,
                app_token_hash char(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
                activation_valid_through timestamp NULL DEFAULT NULL,
                registration_token_hash char(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
                dataprot_accepted_at datetime DEFAULT NULL,
                PRIMARY KEY (email),
                UNIQUE KEY registration_token_hash (registration_token_hash)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci'
        );

        $this->pdo->exec(
            "INSERT INTO register
                (email, name, iban, bic, age, cigarettes, doi_token, doi, studyinfo, dataprot)
             VALUES
                ('existing@example.org', 'Existing Person', 'DE001', 'BIC001', 45, 15, 'hash', 1, 1, 1)"
        );

        $this->applyMigration(dirname(__DIR__) . '/sql/migrations/001_registration_channels_up.sql');
        if ($this->name() !== 'testMigrationPreservesDirectRowsAndBackfillsConfirmation') {
            $this->pdo->exec('DELETE FROM register');
        }
    }

    public function testMigrationPreservesDirectRowsAndBackfillsConfirmation(): void
    {
        $row = $this->pdo->query(
            "SELECT registration_id, registration_channel, email, name, iban, bic,
                    prolific_id, registration_confirmed_at
               FROM register
              WHERE email = 'existing@example.org'"
        )->fetch();

        self::assertGreaterThan(0, (int) $row['registration_id']);
        self::assertSame('DIRECT', $row['registration_channel']);
        self::assertSame('Existing Person', $row['name']);
        self::assertSame('DE001', $row['iban']);
        self::assertSame('BIC001', $row['bic']);
        self::assertNull($row['prolific_id']);
        self::assertNotNull($row['registration_confirmed_at']);
    }

    public function testStoresDirectRegistrationWithExistingAdministrativeValues(): void
    {
        $creation = create_registration(
            $this->pdo,
            $this->submission($this->validDirectPost()),
            static fn (): string => str_repeat('a', 64)
        );
        $row = $this->pdo->query('SELECT * FROM register')->fetch();

        self::assertSame(ParticipantIdentifier::DIRECT, $creation->channel());
        self::assertSame(str_repeat('a', 64), $creation->doubleOptInToken());
        self::assertSame('Participant@Example.ORG', $row['email']);
        self::assertSame('Test Person', $row['name']);
        self::assertSame('DE89370400440532013000', $row['iban']);
        self::assertSame('COBADEFFXXX', $row['bic']);
        self::assertSame(hash('sha256', str_repeat('a', 64)), $row['doi_token']);
        self::assertSame('DIRECT', $row['registration_channel']);
        self::assertNull($row['prolific_id']);
        self::assertNull($row['registration_confirmed_at']);
    }

    public function testStoresProlificRegistrationWithoutPersonalOrDoubleOptInData(): void
    {
        $post = $this->validDirectPost();
        $post['participant_identifier'] = 'AbCdEf1234567890GhIjKlMn';
        $creation = create_registration($this->pdo, $this->submission($post));
        $row = $this->pdo->query('SELECT * FROM register')->fetch();

        self::assertSame(ParticipantIdentifier::PROLIFIC, $creation->channel());
        self::assertNull($creation->doubleOptInToken());
        self::assertSame('PROLIFIC', $row['registration_channel']);
        self::assertSame('AbCdEf1234567890GhIjKlMn', $row['prolific_id']);
        self::assertNull($row['email']);
        self::assertNull($row['name']);
        self::assertNull($row['iban']);
        self::assertNull($row['bic']);
        self::assertNull($row['doi_token']);
        self::assertNotNull($row['registration_confirmed_at']);
    }

    public function testRejectsDuplicateIdentifiersByTheirChannel(): void
    {
        $direct = $this->submission($this->validDirectPost());
        create_registration($this->pdo, $direct, static fn (): string => str_repeat('a', 64));
        try {
            create_registration($this->pdo, $direct, static fn (): string => str_repeat('b', 64));
            self::fail('Duplicate direct email must be rejected.');
        } catch (DuplicateRegistrationException $error) {
            self::assertSame(ParticipantIdentifier::DIRECT, $error->channel());
        }

        $post = $this->validDirectPost();
        $post['participant_identifier'] = 'AbCdEf1234567890GhIjKlMn';
        $prolific = $this->submission($post);
        create_registration($this->pdo, $prolific);
        try {
            create_registration($this->pdo, $prolific);
            self::fail('Duplicate Prolific ID must be rejected.');
        } catch (DuplicateRegistrationException $error) {
            self::assertSame(ParticipantIdentifier::PROLIFIC, $error->channel());
        }
    }

    public function testConfirmsOnlyDirectRegistrationAndSetsGenericTimestamp(): void
    {
        $creation = create_registration(
            $this->pdo,
            $this->submission($this->validDirectPost()),
            static fn (): string => str_repeat('c', 64)
        );

        self::assertTrue(confirm_direct_registration(
            $this->pdo,
            hash('sha256', (string) $creation->doubleOptInToken())
        ));
        $row = $this->pdo->query('SELECT doi, registration_confirmed_at FROM register')->fetch();
        self::assertSame(1, (int) $row['doi']);
        self::assertNotNull($row['registration_confirmed_at']);
        self::assertFalse(confirm_direct_registration($this->pdo, hash('sha256', 'unknown')));
    }

    public function testRollbackRestoresEmailPrimaryKeyBeforeProlificRegistrationOpens(): void
    {
        $this->applyMigration(dirname(__DIR__) . '/sql/migrations/001_registration_channels_down.sql');
        $schema = $this->pdo->query('SHOW CREATE TABLE register')->fetch(PDO::FETCH_NUM);

        self::assertIsArray($schema);
        self::assertStringContainsString('PRIMARY KEY (`email`)', $schema[1]);
        self::assertStringNotContainsString('`registration_id`', $schema[1]);
        self::assertStringNotContainsString('`prolific_id`', $schema[1]);
        self::assertMatchesRegularExpression('/`email` varchar\(255\).* NOT NULL/', $schema[1]);
    }

    private function applyMigration(string $path): void
    {
        $sql = file_get_contents($path);
        self::assertNotFalse($sql, 'Migration file must be readable.');
        $sql = preg_replace('/^--.*$/m', '', $sql);
        self::assertIsString($sql);
        foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
            $this->pdo->exec($statement);
        }
    }

    private function submission(array $post): RegistrationSubmission
    {
        $result = validate_registration_submission($post);
        self::assertTrue($result->isValid());
        return $result->submission();
    }

    /** @return array<string, string> */
    private function validDirectPost(): array
    {
        return [
            'participant_identifier' => ' Participant@Example.ORG ',
            'name' => ' Test Person ',
            'iban' => ' DE89370400440532013000 ',
            'bic' => ' COBADEFFXXX ',
            'age' => '30',
            'cigarettes' => '10',
            'studyinfo' => 'on',
            'dataprot' => 'on',
        ];
    }
}
