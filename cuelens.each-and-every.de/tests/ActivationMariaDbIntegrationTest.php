<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/activation.php';

final class ActivationMariaDbIntegrationTest extends TestCase
{
    private const EMAIL = 'participant@example.org';
    private const FIRST_TOKEN = '550e8400-e29b-41d4-a716-446655440000';
    private const SECOND_TOKEN = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';
    private const SECRET = 'integration-test-secret';

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
                email VARCHAR(255) NOT NULL PRIMARY KEY,
                doi TINYINT(1) NOT NULL DEFAULT 0,
                studyinfo TINYINT(1) NOT NULL DEFAULT 0,
                dataprot TINYINT(1) NOT NULL DEFAULT 0,
                app_token_hash CHAR(64) NULL,
                activation_valid_through DATETIME NULL,
                app_token_issued_at TIMESTAMP NULL
            ) ENGINE=InnoDB'
        );
        $this->pdo->prepare(
            'INSERT INTO register (email, doi, studyinfo, dataprot) VALUES (:email, 1, 1, 1)'
        )->execute([':email' => self::EMAIL]);
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

        confirm_activation_token($this->pdo, self::EMAIL, $token, self::SECRET);

        $confirmed = $this->registration();
        self::assertNull($confirmed['app_token_hash']);
        self::assertNull($confirmed['activation_valid_through']);
        self::assertNotNull($confirmed['app_token_issued_at']);
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
            confirm_activation_token($this->pdo, self::EMAIL, self::FIRST_TOKEN, self::SECRET);
            self::fail('The overwritten token must be rejected.');
        } catch (ActivationRejectedException) {
            self::assertNull($this->registration()['app_token_issued_at']);
        }

        confirm_activation_token($this->pdo, self::EMAIL, self::SECOND_TOKEN, self::SECRET);
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
        confirm_activation_token($this->pdo, self::EMAIL, self::FIRST_TOKEN, self::SECRET);
    }

    /** @return array<string, mixed> */
    private function registration(): array
    {
        $row = $this->pdo->query(
            'SELECT app_token_hash, activation_valid_through, app_token_issued_at FROM register'
        )->fetch(PDO::FETCH_ASSOC);
        self::assertIsArray($row);
        return $row;
    }
}
