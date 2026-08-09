<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/study-completion.php';

final class StudyCompletionMariaDbIntegrationTest extends TestCase
{
    private const SECRET = 'integration-test-pseudonym-secret';
    private const DIRECT_TOKEN = '550e8400-e29b-41d4-a716-446655440000';
    private const PROLIFIC_TOKEN = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';
    private const COMPENSATION_CODE = '123e4567-e89b-42d3-a456-426614174000';
    private const PROLIFIC_ID = 'AbCdEfGhIjKlMnOpQrStUv12';

    private PDO $researchPdo;
    private PDO $administrativePdo;

    protected function setUp(): void
    {
        $database = getenv('CUELENS_TEST_CRAVING_DB_NAME');
        $user = getenv('CUELENS_TEST_CRAVING_DB_USER');
        $administrativeDatabase = getenv('CUELENS_TEST_DB_NAME');
        $administrativeUser = getenv('CUELENS_TEST_DB_USER');
        if (
            $database === false || $database === '' ||
            $user === false || $user === '' ||
            $administrativeDatabase === false || $administrativeDatabase === '' ||
            $administrativeUser === false || $administrativeUser === ''
        ) {
            self::markTestSkipped('Set both isolated MariaDB test database configurations.');
        }

        $this->researchPdo = $this->pdo(
            getenv('CUELENS_TEST_CRAVING_DB_HOST') ?: '127.0.0.1',
            getenv('CUELENS_TEST_CRAVING_DB_PORT') ?: '3306',
            $database,
            $user,
            getenv('CUELENS_TEST_CRAVING_DB_PASS') ?: ''
        );
        $this->administrativePdo = $this->pdo(
            getenv('CUELENS_TEST_DB_HOST') ?: '127.0.0.1',
            getenv('CUELENS_TEST_DB_PORT') ?: '3306',
            $administrativeDatabase,
            $administrativeUser,
            getenv('CUELENS_TEST_DB_PASS') ?: ''
        );

        $this->researchPdo->exec(
            'CREATE TEMPORARY TABLE valid_app_token_hashes (
                hash CHAR(64) NOT NULL PRIMARY KEY,
                completion_mode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
            ) ENGINE=InnoDB'
        );
        $this->researchPdo->exec(
            'CREATE TEMPORARY TABLE self_reports (
                participant_id CHAR(64) NOT NULL,
                condition_code ENUM(\'CUE_MATCHING\', \'CUE_LABELING\') NOT NULL,
                craving TINYINT NOT NULL,
                CHECK (craving BETWEEN 0 AND 100)
            ) ENGINE=InnoDB'
        );
        $this->researchPdo->exec(
            'CREATE TEMPORARY TABLE compensation_code (
                compensation_code CHAR(36) NOT NULL PRIMARY KEY,
                confirmed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB'
        );
        $this->administrativePdo->exec(
            'CREATE TEMPORARY TABLE register (
                registration_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                registration_channel VARCHAR(16) NOT NULL,
                prolific_id CHAR(24) CHARACTER SET ascii COLLATE ascii_bin NULL,
                app_token_issued_at TIMESTAMP NULL,
                registration_token_hash CHAR(64) NULL UNIQUE,
                study_completed_at DATETIME NULL,
                completion_notification_queued_at DATETIME NULL
            ) ENGINE=InnoDB'
        );

        $allowlist = $this->researchPdo->prepare(
            'INSERT INTO valid_app_token_hashes (hash, completion_mode)
             VALUES (:hash, :completion_mode)'
        );
        $allowlist->execute([
            ':hash' => valid_app_token_hash(self::SECRET, self::DIRECT_TOKEN),
            ':completion_mode' => COMPLETION_MODE_COMPENSATION_CODE,
        ]);
        $allowlist->execute([
            ':hash' => valid_app_token_hash(self::SECRET, self::PROLIFIC_TOKEN),
            ':completion_mode' => COMPLETION_MODE_PROLIFIC_MANUAL,
        ]);

        $registration = $this->administrativePdo->prepare(
            'INSERT INTO register
                (registration_channel, prolific_id, app_token_issued_at, registration_token_hash)
             VALUES
                (\'PROLIFIC\', :prolific_id, CURRENT_TIMESTAMP, :registration_token_hash)'
        );
        $registration->execute([
            ':prolific_id' => self::PROLIFIC_ID,
            ':registration_token_hash' => registration_token_hash(
                self::SECRET,
                self::PROLIFIC_TOKEN
            ),
        ]);
    }

    public function testDirectReportsAndCompensationConfirmationRemainUnchanged(): void
    {
        $administrativeConnections = 0;
        $notifications = 0;
        for ($index = 1; $index <= 19; $index++) {
            self::assertSame(
                [
                    'success' => true,
                    'situation_index' => $index,
                    'condition_code' => condition_code_for_index($index),
                ],
                $this->submit(
                    self::DIRECT_TOKEN,
                    static fn (): string => self::COMPENSATION_CODE,
                    function () use (&$administrativeConnections): PDO {
                        $administrativeConnections++;
                        return $this->administrativePdo;
                    },
                    function () use (&$notifications): void {
                        $notifications++;
                    }
                )
            );
        }

        $completion = $this->submit(
            self::DIRECT_TOKEN,
            static fn (): string => self::COMPENSATION_CODE,
            function () use (&$administrativeConnections): PDO {
                $administrativeConnections++;
                return $this->administrativePdo;
            },
            function () use (&$notifications): void {
                $notifications++;
            }
        );
        self::assertSame(
            completed_study_response(COMPLETION_MODE_COMPENSATION_CODE, self::COMPENSATION_CODE),
            $completion
        );
        self::assertSame(20, $this->reportCount(self::DIRECT_TOKEN));
        self::assertSame(
            self::COMPENSATION_CODE,
            $this->researchPdo->query(
                'SELECT compensation_code FROM compensation_code'
            )->fetchColumn()
        );
        self::assertSame(0, $administrativeConnections);
        self::assertSame(0, $notifications);

        confirm_compensation_code($this->researchPdo, self::COMPENSATION_CODE);
        $confirmedAt = $this->researchPdo->query(
            'SELECT confirmed_at FROM compensation_code'
        )->fetchColumn();
        self::assertIsString($confirmedAt);
        confirm_compensation_code($this->researchPdo, self::COMPENSATION_CODE);
        self::assertSame(
            $confirmedAt,
            $this->researchPdo->query('SELECT confirmed_at FROM compensation_code')->fetchColumn()
        );

        try {
            $this->submit(self::DIRECT_TOKEN);
            self::fail('The existing direct retry protocol must continue rejecting report 21.');
        } catch (StudySubmissionRejectedException $error) {
            self::assertSame('Study is already complete.', $error->getMessage());
        }
        self::assertSame(20, $this->reportCount(self::DIRECT_TOKEN));
    }

    public function testProlificCompletionIsDataMinimizedAndIdempotent(): void
    {
        $administrativeConnections = 0;
        $notifications = 0;
        for ($index = 1; $index <= 19; $index++) {
            $result = $this->submit(
                self::PROLIFIC_TOKEN,
                null,
                function () use (&$administrativeConnections): PDO {
                    $administrativeConnections++;
                    return $this->administrativePdo;
                },
                function () use (&$notifications): void {
                    $notifications++;
                }
            );
            self::assertSame($index, $result['situation_index']);
            self::assertArrayNotHasKey('completion_mode', $result);
        }
        self::assertSame(0, $administrativeConnections);

        $completion = $this->submit(
            self::PROLIFIC_TOKEN,
            null,
            function () use (&$administrativeConnections): PDO {
                $administrativeConnections++;
                return $this->administrativePdo;
            },
            function () use (&$notifications): void {
                $notifications++;
            }
        );
        self::assertSame(
            completed_study_response(COMPLETION_MODE_PROLIFIC_MANUAL),
            $completion
        );
        self::assertSame(1, $administrativeConnections);
        self::assertSame(1, $notifications);
        self::assertSame(20, $this->reportCount(self::PROLIFIC_TOKEN));
        self::assertSame(0, (int) $this->researchPdo->query(
            'SELECT COUNT(*) FROM compensation_code'
        )->fetchColumn());

        $administrativeRow = $this->administrativePdo->query(
            'SELECT study_completed_at, completion_notification_queued_at FROM register'
        )->fetch(PDO::FETCH_ASSOC);
        self::assertIsArray($administrativeRow);
        self::assertNotNull($administrativeRow['study_completed_at']);
        self::assertNotNull($administrativeRow['completion_notification_queued_at']);

        self::assertSame(
            $completion,
            $this->submit(
                self::PROLIFIC_TOKEN,
                null,
                function () use (&$administrativeConnections): PDO {
                    $administrativeConnections++;
                    return $this->administrativePdo;
                },
                function () use (&$notifications): void {
                    $notifications++;
                }
            )
        );
        self::assertSame(2, $administrativeConnections);
        self::assertSame(1, $notifications);
        self::assertSame(20, $this->reportCount(self::PROLIFIC_TOKEN));
        self::assertSame(
            $administrativeRow,
            $this->administrativePdo->query(
                'SELECT study_completed_at, completion_notification_queued_at FROM register'
            )->fetch(PDO::FETCH_ASSOC)
        );

        $researchSchema = $this->researchPdo->query(
            'SHOW COLUMNS FROM self_reports'
        )->fetchAll(PDO::FETCH_COLUMN);
        self::assertSame(['participant_id', 'condition_code', 'craving'], $researchSchema);
        $serializedResearchRows = json_encode(
            $this->researchPdo->query('SELECT * FROM self_reports')->fetchAll(),
            JSON_THROW_ON_ERROR
        );
        self::assertStringNotContainsString(self::PROLIFIC_ID, $serializedResearchRows);
        self::assertStringNotContainsString(hash('sha256', self::PROLIFIC_ID), $serializedResearchRows);
        self::assertStringNotContainsString('@', $serializedResearchRows);
    }

    public function testRetryRecoversAdministrativeFailureAfterTwentiethReport(): void
    {
        for ($index = 1; $index <= 19; $index++) {
            $this->submit(self::PROLIFIC_TOKEN);
        }

        try {
            $this->submit(
                self::PROLIFIC_TOKEN,
                null,
                static function (): PDO {
                    throw new RuntimeException('Simulated administrative database outage.');
                }
            );
            self::fail('Administrative completion failure must be retryable.');
        } catch (StudyCompletionPersistenceException) {
            self::assertSame(20, $this->reportCount(self::PROLIFIC_TOKEN));
        }

        $notifications = 0;
        $completion = $this->submit(
            self::PROLIFIC_TOKEN,
            null,
            fn (): PDO => $this->administrativePdo,
            function () use (&$notifications): void {
                $notifications++;
            }
        );
        self::assertSame(
            completed_study_response(COMPLETION_MODE_PROLIFIC_MANUAL),
            $completion
        );
        self::assertSame(20, $this->reportCount(self::PROLIFIC_TOKEN));
        self::assertSame(1, $notifications);
    }

    public function testProlificCompletionRequiresMatchingActivatedAdministrativeRegistration(): void
    {
        $this->administrativePdo->exec('UPDATE register SET app_token_issued_at = NULL');
        for ($index = 1; $index <= 19; $index++) {
            $this->submit(self::PROLIFIC_TOKEN);
        }

        try {
            $this->submit(
                self::PROLIFIC_TOKEN,
                null,
                fn (): PDO => $this->administrativePdo
            );
            self::fail('Only an activated Prolific registration may be marked complete.');
        } catch (StudyCompletionPersistenceException) {
            self::assertSame(20, $this->reportCount(self::PROLIFIC_TOKEN));
        }
    }

    /**
     * @param null|callable(): string $codeGenerator
     * @param null|callable(): PDO $administrativePdoFactory
     * @param null|callable(): void $notifier
     * @return array<string, mixed>
     */
    private function submit(
        string $token,
        ?callable $codeGenerator = null,
        ?callable $administrativePdoFactory = null,
        ?callable $notifier = null
    ): array {
        return submit_study_report(
            $this->researchPdo,
            $token,
            50,
            self::SECRET,
            $administrativePdoFactory,
            $codeGenerator,
            $notifier
        );
    }

    private function reportCount(string $token): int
    {
        $stmt = $this->researchPdo->prepare(
            'SELECT COUNT(*) FROM self_reports WHERE participant_id = :participant_id'
        );
        $stmt->execute([
            ':participant_id' => participant_id_for_app_token(self::SECRET, $token),
        ]);
        return (int) $stmt->fetchColumn();
    }

    private function pdo(
        string $host,
        string $port,
        string $database,
        string $user,
        string $password
    ): PDO {
        return new PDO(
            "mysql:host={$host};port={$port};dbname={$database};charset=utf8mb4",
            $user,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
    }
}
