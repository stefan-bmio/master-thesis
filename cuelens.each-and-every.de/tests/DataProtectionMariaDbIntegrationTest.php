<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/data-protection-consent.php';

final class DataProtectionMariaDbIntegrationTest extends TestCase
{
    private const SECRET = 'integration-test-pseudonym-secret';
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';

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
                dataprot TINYINT(1) NOT NULL DEFAULT 0,
                registration_token_hash CHAR(64) NULL UNIQUE,
                dataprot_accepted_at DATETIME NULL
            ) ENGINE=InnoDB'
        );
        $insert = $this->pdo->prepare(
            'INSERT INTO register (email, dataprot, registration_token_hash)
             VALUES (:email, 0, :registration_token_hash)'
        );
        $insert->execute([
            ':email' => 'participant@example.org',
            ':registration_token_hash' => registration_token_hash(self::SECRET, self::TOKEN),
        ]);
    }

    public function testReadsAndAcceptsConsentIdempotently(): void
    {
        self::assertFalse(data_protection_status($this->pdo, self::SECRET, self::TOKEN));

        accept_data_protection($this->pdo, self::SECRET, self::TOKEN);
        self::assertTrue(data_protection_status($this->pdo, self::SECRET, self::TOKEN));
        $firstAcceptedAt = $this->pdo->query(
            'SELECT dataprot_accepted_at FROM register'
        )->fetchColumn();
        self::assertIsString($firstAcceptedAt);

        sleep(1);
        accept_data_protection($this->pdo, self::SECRET, self::TOKEN);
        self::assertSame(
            $firstAcceptedAt,
            $this->pdo->query('SELECT dataprot_accepted_at FROM register')->fetchColumn()
        );
    }

    public function testUnknownTokenIsRejected(): void
    {
        $this->expectException(DataProtectionAuthenticationException::class);
        data_protection_status(
            $this->pdo,
            self::SECRET,
            '6ba7b810-9dad-41d1-80b4-00c04fd430c8'
        );
    }
}
