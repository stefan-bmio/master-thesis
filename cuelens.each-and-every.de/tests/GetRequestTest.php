<?php

declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\PreserveGlobalState;
use PHPUnit\Framework\Attributes\RunInSeparateProcess;
use PHPUnit\Framework\TestCase;

final class GetRequestTest extends TestCase
{
    /**
     * @return array<string, array{string}>
     */
    public static function formPageProvider(): array
    {
        return [
            'German registration form' => ['index-de.php'],
            'English registration form' => ['index-en.php'],
        ];
    }

    #[DataProvider('formPageProvider')]
    #[RunInSeparateProcess]
    #[PreserveGlobalState(false)]
    public function testRegistrationFormGetRequestDoesNotRequireDatabase(string $page): void
    {
        $_GET = [];
        $_POST = [];
        $_REQUEST = [];
        $_SERVER['REQUEST_METHOD'] = 'GET';

        ob_start();
        require __DIR__ . '/../' . $page;
        $output = ob_get_clean();

        $statusCode = http_response_code();
        if ($statusCode === false) {
            $statusCode = 200;
        }

        self::assertNotSame(500, $statusCode);
        self::assertStringNotContainsString('Database error', $output);
        self::assertStringContainsString(
            '<form method="post" action="" data-registration-mode="invalid">',
            $output
        );
        self::assertStringContainsString('name="participant_identifier"', $output);
        self::assertStringContainsString('data-registration-mode="invalid"', $output);
    }

    public function testProlificSuccessPagesContainNoSubmittedIdentifier(): void
    {
        foreach (['registered-de.php', 'registered-en.php'] as $page) {
            $output = file_get_contents(__DIR__ . '/../' . $page);
            self::assertNotFalse($output);
            self::assertStringContainsString('download', $output);
            self::assertStringNotContainsString('participant_identifier', $output);
        }
    }

    public function testRegistrationPagesContainLocalizedProlificEligibilityErrors(): void
    {
        $germanPage = file_get_contents(__DIR__ . '/../index-de.php');
        $englishPage = file_get_contents(__DIR__ . '/../index-en.php');

        self::assertNotFalse($germanPage);
        self::assertNotFalse($englishPage);
        self::assertStringContainsString(
            'Diese Prolific-ID ist nicht für die CueLens-Studie registriert.',
            $germanPage
        );
        self::assertStringContainsString(
            'Die Prolific-ID konnte vorübergehend nicht geprüft werden.',
            $germanPage
        );
        self::assertStringContainsString(
            'This Prolific ID is not registered for the CueLens study.',
            $englishPage
        );
        self::assertStringContainsString(
            'The Prolific ID could not be checked temporarily.',
            $englishPage
        );
    }

    #[RunInSeparateProcess]
    #[PreserveGlobalState(false)]
    public function testIneligibleProlificRegistrationShowsExactErrorBeforeDatabaseAccess(): void
    {
        $csrfToken = str_repeat('a', 64);
        $previousSessionSavePath = session_save_path();
        self::assertNotFalse(ini_set('session.save_path', sys_get_temp_dir()));
        session_id('cuelens-prolific-validation-' . bin2hex(random_bytes(16)));
        self::assertTrue(session_start());

        try {
            $_SESSION['csrf_token'] = $csrfToken;
            self::assertTrue(session_write_close());

            $_GET = [];
            $_REQUEST = [];
            $_POST = [
                'participant_identifier' => 'AbCdEf1234567890GhIjKlMn',
                'age' => '30',
                'cigarettes' => '10',
                'studyinfo' => 'on',
                'dataprot' => 'on',
                'csrf_token' => $csrfToken,
            ];
            $_SERVER['REQUEST_METHOD'] = 'POST';
            $checkedParticipantId = null;
            $prolificSubmissionValidator = static function (
                array $hostConfig,
                string $participantId
            ) use (&$checkedParticipantId): bool {
                $checkedParticipantId = $participantId;
                return false;
            };

            ob_start();
            require __DIR__ . '/../index-de.php';
            $output = ob_get_clean();

            self::assertSame('AbCdEf1234567890GhIjKlMn', $checkedParticipantId);
            self::assertStringContainsString(
                'Diese Prolific-ID ist nicht für die CueLens-Studie registriert.',
                $output
            );
        } finally {
            if (session_status() === PHP_SESSION_ACTIVE) {
                session_destroy();
            }
            ini_set('session.save_path', $previousSessionSavePath);
        }
    }
}
