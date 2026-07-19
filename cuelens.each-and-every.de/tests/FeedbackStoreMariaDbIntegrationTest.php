<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/feedback-store.php';

final class FeedbackStoreMariaDbIntegrationTest extends TestCase
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
            'CREATE TEMPORARY TABLE feedback (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                source TEXT NULL,
                comment TEXT NULL,
                app_version VARCHAR(64) NULL
            ) ENGINE=InnoDB'
        );
    }

    public function testSoftLimitAndDeletionBehaviorAgainstMariaDb(): void
    {
        $insert = $this->pdo->prepare(
            'INSERT INTO feedback (source, comment, app_version) VALUES (NULL, :comment, NULL)'
        );
        for ($index = 0; $index < FEEDBACK_SOFT_LIMIT - 1; $index++) {
            $insert->execute([':comment' => 'existing-' . $index]);
        }

        self::assertSame(
            FEEDBACK_STORED,
            store_feedback_with_soft_limit($this->pdo, 'Flyer', 'entry-200', '1.0')
        );
        self::assertSame(FEEDBACK_SOFT_LIMIT, $this->feedbackCount());

        self::assertSame(
            FEEDBACK_DISCARDED,
            store_feedback_with_soft_limit($this->pdo, 'Flyer', 'entry-201', '1.0')
        );
        self::assertSame(FEEDBACK_SOFT_LIMIT, $this->feedbackCount());

        $this->pdo->exec('DELETE FROM feedback ORDER BY id LIMIT 2');
        self::assertSame(
            FEEDBACK_STORED,
            store_feedback_with_soft_limit($this->pdo, 'Flyer', 'after-deletion', '1.0')
        );
        self::assertSame(FEEDBACK_SOFT_LIMIT - 1, $this->feedbackCount());
    }

    private function feedbackCount(): int
    {
        return (int) $this->pdo->query('SELECT COUNT(*) FROM feedback')->fetchColumn();
    }
}
