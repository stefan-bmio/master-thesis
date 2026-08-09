<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/activation.php';

final class ActivationMariaDbIntegrationTest extends TestCase
{
    private const EMAIL = 'participant@example.org';
    private const PROLIFIC_ID = 'AbCdEfGhIjKlMnOpQrStUv12';
    private const FIRST_TOKEN = '550e8400-e29b-41d4-a716-446655440000';
    private const SECOND_TOKEN = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';
    private const SECRET = 'integration-test-secret';
    private const PSEUDONYM_SECRET = 'integration-test-pseudonym-secret';

    private PDO $pdo;
    private PDO $cravingPdo;

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
        $cravingHost = getenv('CUELENS_TEST_CRAVING_DB_HOST') ?: $host;
        $cravingPort = getenv('CUELENS_TEST_CRAVING_DB_PORT') ?: $port;
        $cravingDatabase = getenv('CUELENS_TEST_CRAVING_DB_NAME') ?: $database;
        $cravingUser = getenv('CUELENS_TEST_CRAVING_DB_USER') ?: $user;
        $cravingPassword = getenv('CUELENS_TEST_CRAVING_DB_PASS') ?: $password;
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
        $this->cravingPdo = new PDO(
            "mysql:host={$cravingHost};port={$cravingPort};dbname={$cravingDatabase};charset=utf8mb4",
            $cravingUser,
            $cravingPassword,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        $this->pdo->exec(
            'CREATE TEMPORARY TABLE register (
                registration_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                registration_channel VARCHAR(16) NOT NULL DEFAULT \'DIRECT\',
                email VARCHAR(255) NULL UNIQUE,
                prolific_id CHAR(24) CHARACTER SET ascii COLLATE ascii_bin NULL UNIQUE,
                doi TINYINT(1) NOT NULL DEFAULT 0,
                registration_confirmed_at DATETIME NULL,
                studyinfo TINYINT(1) NOT NULL DEFAULT 0,
                dataprot TINYINT(1) NOT NULL DEFAULT 0,
                app_token_hash CHAR(64) NULL,
                activation_valid_through DATETIME NULL,
                app_token_issued_at TIMESTAMP NULL,
                registration_token_hash CHAR(64) NULL UNIQUE,
                dataprot_accepted_at DATETIME NULL
            ) ENGINE=InnoDB'
        );
        $this->cravingPdo->exec(
            'CREATE TEMPORARY TABLE valid_app_token_hashes (
                hash CHAR(64) NOT NULL PRIMARY KEY,
                completion_mode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin
                    NOT NULL DEFAULT \'COMPENSATION_CODE\'
            ) ENGINE=InnoDB'
        );
        $this->pdo->prepare(
            'INSERT INTO register
                (registration_channel, email, doi, registration_confirmed_at, studyinfo, dataprot)
             VALUES
                (\'DIRECT\', :email, 1, CURRENT_TIMESTAMP, 1, 1)'
        )->execute([':email' => self::EMAIL]);
        $this->pdo->prepare(
            'INSERT INTO register
                (registration_channel, prolific_id, doi, registration_confirmed_at, studyinfo, dataprot)
             VALUES
                (\'PROLIFIC\', :prolific_id, 0, CURRENT_TIMESTAMP, 1, 1)'
        )->execute([':prolific_id' => self::PROLIFIC_ID]);
    }

    public function testRequestAndConfirmationCommitActivationInTwoSteps(): void
    {
        $token = request_activation_token(
            $this->pdo,
            ' Participant@Example.ORG ',
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );

        self::assertSame(self::FIRST_TOKEN, $token);
        $pending = $this->registration();
        self::assertSame(
            activation_token_hash(self::SECRET, self::EMAIL, self::FIRST_TOKEN),
            $pending['app_token_hash']
        );
        self::assertNotNull($pending['activation_valid_through']);
        self::assertNull($pending['app_token_issued_at']);

        $this->confirm($token);

        $confirmed = $this->registration();
        self::assertNull($confirmed['app_token_hash']);
        self::assertNull($confirmed['activation_valid_through']);
        self::assertNotNull($confirmed['app_token_issued_at']);
        self::assertSame(
            registration_token_hash(self::PSEUDONYM_SECRET, $token),
            $confirmed['registration_token_hash']
        );
        self::assertSame(
            valid_app_token_hash(self::PSEUDONYM_SECRET, $token),
            $this->cravingPdo->query('SELECT hash FROM valid_app_token_hashes')->fetchColumn()
        );
        self::assertSame(
            COMPLETION_MODE_COMPENSATION_CODE,
            $this->cravingPdo->query(
                'SELECT completion_mode FROM valid_app_token_hashes'
            )->fetchColumn()
        );
    }

    public function testProlificRequestAndConfirmationStoreOnlyTokenHashAndCompletionMode(): void
    {
        $token = request_activation_token(
            $this->pdo,
            ParticipantIdentifier::parse(self::PROLIFIC_ID),
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );

        self::assertSame(self::FIRST_TOKEN, $token);
        self::assertSame(
            activation_token_hash_for_identifier(
                self::SECRET,
                ParticipantIdentifier::parse(self::PROLIFIC_ID),
                self::FIRST_TOKEN
            ),
            $this->registration(self::PROLIFIC_ID)['app_token_hash']
        );

        $this->confirmIdentifier(self::PROLIFIC_ID, $token);

        $registration = $this->registration(self::PROLIFIC_ID);
        self::assertNotNull($registration['app_token_issued_at']);
        self::assertSame(
            registration_token_hash(self::PSEUDONYM_SECRET, $token),
            $registration['registration_token_hash']
        );
        $allowlistRow = $this->cravingPdo->query(
            'SELECT * FROM valid_app_token_hashes'
        )->fetch(PDO::FETCH_ASSOC);
        self::assertSame(
            [
                'hash' => valid_app_token_hash(self::PSEUDONYM_SECRET, $token),
                'completion_mode' => COMPLETION_MODE_PROLIFIC_MANUAL,
            ],
            $allowlistRow
        );
        self::assertNotContains(self::EMAIL, $allowlistRow);
        self::assertNotContains(self::PROLIFIC_ID, $allowlistRow);
    }

    public function testNewRequestOverwritesPendingTokenAndRejectsOldToken(): void
    {
        request_activation_token(
            $this->pdo,
            self::EMAIL,
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );
        request_activation_token(
            $this->pdo,
            self::EMAIL,
            self::SECRET,
            static fn (): string => self::SECOND_TOKEN
        );

        try {
            $this->confirm(self::FIRST_TOKEN);
            self::fail('The overwritten token must be rejected.');
        } catch (ActivationRejectedException) {
            self::assertNull($this->registration()['app_token_issued_at']);
        }

        $this->confirm(self::SECOND_TOKEN);
        self::assertNotNull($this->registration()['app_token_issued_at']);
    }

    public function testExpiredConfirmationIsRejected(): void
    {
        request_activation_token(
            $this->pdo,
            self::EMAIL,
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );
        $this->pdo->exec(
            "UPDATE register SET activation_valid_through = DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 SECOND)"
        );

        $this->expectException(ActivationRejectedException::class);
        $this->confirm(self::FIRST_TOKEN);
    }

    public function testRegistrationWithResetConsentCanStillActivate(): void
    {
        $this->pdo->exec('UPDATE register SET dataprot = 0, dataprot_accepted_at = NULL');

        $token = request_activation_token(
            $this->pdo,
            self::EMAIL,
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );
        $this->confirm($token);

        $registration = $this->registration();
        self::assertSame(0, (int) $registration['dataprot']);
        self::assertNotNull($registration['app_token_issued_at']);
        self::assertSame(
            registration_token_hash(self::PSEUDONYM_SECRET, $token),
            $registration['registration_token_hash']
        );
    }

    public function testPendingTokenCannotBeConfirmedThroughTheOtherIdentifierChannel(): void
    {
        $directToken = request_activation_token(
            $this->pdo,
            self::EMAIL,
            self::SECRET,
            static fn (): string => self::FIRST_TOKEN
        );
        try {
            $this->confirmIdentifier(self::PROLIFIC_ID, $directToken);
            self::fail('A direct token must not be confirmed through a Prolific registration.');
        } catch (ActivationRejectedException) {
            self::assertNull($this->registration(self::EMAIL)['app_token_issued_at']);
        }

        $prolificToken = request_activation_token(
            $this->pdo,
            self::PROLIFIC_ID,
            self::SECRET,
            static fn (): string => self::SECOND_TOKEN
        );
        try {
            $this->confirmIdentifier(self::EMAIL, $prolificToken);
            self::fail('A Prolific token must not be confirmed through a direct registration.');
        } catch (ActivationRejectedException) {
            self::assertNull($this->registration(self::PROLIFIC_ID)['app_token_issued_at']);
        }
    }

    public function testResearchMigrationBackfillsConstrainsAndRollsBackCompletionMode(): void
    {
        $this->cravingPdo->exec('DROP TEMPORARY TABLE valid_app_token_hashes');
        $this->cravingPdo->exec(
            'CREATE TEMPORARY TABLE valid_app_token_hashes (
                hash CHAR(64) NOT NULL PRIMARY KEY
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci'
        );
        $this->cravingPdo->exec(
            "INSERT INTO valid_app_token_hashes (hash) VALUES ('" . str_repeat('a', 64) . "')"
        );

        $this->applyMigration(
            $this->cravingPdo,
            dirname(__DIR__) . '/sql/migrations/002_activation_completion_mode_up.sql'
        );
        self::assertSame(
            COMPLETION_MODE_COMPENSATION_CODE,
            $this->cravingPdo->query(
                'SELECT completion_mode FROM valid_app_token_hashes'
            )->fetchColumn()
        );
        foreach (['UNKNOWN', 'prolific_manual'] as $invalidMode) {
            try {
                $update = $this->cravingPdo->prepare(
                    'UPDATE valid_app_token_hashes SET completion_mode = :completion_mode'
                );
                $update->execute([':completion_mode' => $invalidMode]);
                self::fail('The completion-mode check constraint must reject invalid values.');
            } catch (PDOException) {
                self::assertTrue(true);
            }
        }

        $this->applyMigration(
            $this->cravingPdo,
            dirname(__DIR__) . '/sql/migrations/002_activation_completion_mode_down.sql'
        );
        $schema = $this->cravingPdo->query(
            'SHOW CREATE TABLE valid_app_token_hashes'
        )->fetch(PDO::FETCH_NUM);
        self::assertIsArray($schema);
        self::assertStringNotContainsString('completion_mode', $schema[1]);
    }

    /** @return array<string, mixed> */
    private function registration(string $identifier = self::EMAIL): array
    {
        $participantIdentifier = ParticipantIdentifier::parse($identifier);
        $column = $participantIdentifier->channel() === ParticipantIdentifier::DIRECT
            ? 'email'
            : 'prolific_id';
        $query = $this->pdo->prepare(
            'SELECT app_token_hash,
                    activation_valid_through,
                    app_token_issued_at,
                    registration_token_hash,
                    dataprot
               FROM register
              WHERE registration_channel = :registration_channel
                AND ' . $column . ' = :identifier'
        );
        $query->execute([
            ':registration_channel' => $participantIdentifier->channel(),
            ':identifier' => $participantIdentifier->activationValue(),
        ]);
        $row = $query->fetch(PDO::FETCH_ASSOC);
        self::assertIsArray($row);
        return $row;
    }

    private function confirm(string $token): void
    {
        $this->confirmIdentifier(self::EMAIL, $token);
    }

    private function confirmIdentifier(string $identifier, string $token): void
    {
        confirm_activation_token(
            $this->pdo,
            $this->cravingPdo,
            $identifier,
            $token,
            self::SECRET,
            self::PSEUDONYM_SECRET
        );
    }

    private function applyMigration(PDO $pdo, string $path): void
    {
        $sql = file_get_contents($path);
        self::assertNotFalse($sql, 'Migration file must be readable.');
        $sql = preg_replace('/^--.*$/m', '', $sql);
        self::assertIsString($sql);
        foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
            $pdo->exec($statement);
        }
    }
}
