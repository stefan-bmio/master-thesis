<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/error-log.php';

final class OperationalNotificationTest extends TestCase
{
    public function testBuildsDataMinimizedProlificCompletionNotification(): void
    {
        $notification = build_operational_notification(
            OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED,
            'submission_endpoint',
            null,
            '123e4567-e89b-42d3-a456-426614174000',
            new DateTimeImmutable('2026-08-09T18:45:00Z')
        );

        self::assertSame('[CueLens] Prolific-Teilnahme abgeschlossen', $notification['subject']);
        self::assertStringContainsString('Ereignis: prolific_study_completed', $notification['body']);
        self::assertStringContainsString('Zeitpunkt: 2026-08-09T18:45:00Z', $notification['body']);
        self::assertStringContainsString('Komponente: submission_endpoint', $notification['body']);
        self::assertStringContainsString(
            'Request-ID: 123e4567-e89b-42d3-a456-426614174000',
            $notification['body']
        );
        foreach ([
            'AbCdEfGhIjKlMnOpQrStUv12',
            'participant@example.org',
            '550e8400-e29b-41d4-a716-446655440000',
            str_repeat('a', 64),
            'craving=87',
            'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
            'IBAN',
            'BIC',
            'Test Person',
        ] as $sensitiveValue) {
            self::assertStringNotContainsString($sensitiveValue, $notification['body']);
        }
    }

    public function testProlificCompletionNotificationTransportFailureIsNonFatal(): void
    {
        $logFile = tempnam(sys_get_temp_dir(), 'cuelens-prolific-completion-notification-');
        self::assertNotFalse($logFile);
        $previousErrorLog = ini_set('error_log', $logFile);

        try {
            $sent = send_operational_notification(
                OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED,
                'submission_endpoint',
                null,
                static fn (array $notification): bool => false
            );
            $loggedMessage = file_get_contents($logFile);
        } finally {
            ini_set('error_log', is_string($previousErrorLog) ? $previousErrorLog : '');
            unlink($logFile);
        }

        self::assertFalse($sent);
        self::assertIsString($loggedMessage);
        self::assertStringContainsString('Operational notification failed: unexpected', $loggedMessage);
    }

    public function testBuildsDataMinimizedProlificRegistrationNotification(): void
    {
        $notification = build_operational_notification(
            OPERATIONAL_EVENT_PROLIFIC_REGISTRATION_CREATED,
            'registration_form',
            null,
            '123e4567-e89b-42d3-a456-426614174000',
            new DateTimeImmutable('2026-08-09T12:34:56Z')
        );

        self::assertSame('[CueLens] Neue Prolific-Registrierung', $notification['subject']);
        self::assertStringContainsString('Ereignis: prolific_registration_created', $notification['body']);
        self::assertStringContainsString('Zeitpunkt: 2026-08-09T12:34:56Z', $notification['body']);
        self::assertStringContainsString('Komponente: registration_form', $notification['body']);
        self::assertStringNotContainsString('AbCdEf1234567890GhIjKlMn', $notification['body']);
        self::assertStringNotContainsString('@', $notification['body']);
        self::assertStringNotContainsString('IBAN', $notification['body']);
        self::assertStringNotContainsString('BIC', $notification['body']);
        self::assertStringNotContainsString('Double-Opt-In', $notification['body']);
    }

    public function testBuildsDataMinimizedFeedbackNotification(): void
    {
        $notification = build_operational_notification(
            OPERATIONAL_EVENT_FEEDBACK_RECEIVED,
            'feedback_endpoint',
            null,
            '123e4567-e89b-42d3-a456-426614174000',
            new DateTimeImmutable('2026-07-19T12:34:56Z')
        );

        self::assertSame('[CueLens] Neues Feedback', $notification['subject']);
        self::assertStringContainsString('Ereignis: feedback_received', $notification['body']);
        self::assertStringContainsString('Zeitpunkt: 2026-07-19T12:34:56Z', $notification['body']);
        self::assertStringContainsString('Komponente: feedback_endpoint', $notification['body']);
        self::assertStringContainsString(
            'Request-ID: 123e4567-e89b-42d3-a456-426614174000',
            $notification['body']
        );
        self::assertStringNotContainsString('source', $notification['body']);
        self::assertStringNotContainsString('comment', $notification['body']);
        self::assertStringNotContainsString('app_token', $notification['body']);
        self::assertStringNotContainsString('@', $notification['body']);
    }

    public function testBuildsSanitizedServerErrorNotification(): void
    {
        $notification = build_operational_notification(
            OPERATIONAL_EVENT_SERVER_ERROR,
            "submission\nBcc: attacker@example.org",
            "database\nsecret",
            '123e4567-e89b-42d3-a456-426614174000'
        );

        self::assertSame('[CueLens] Serverfehler', $notification['subject']);
        self::assertStringContainsString('Komponente: unknown', $notification['body']);
        self::assertStringNotContainsString('attacker', $notification['body']);
        self::assertStringNotContainsString('secret', $notification['body']);
        self::assertStringNotContainsString('Bcc:', $notification['subject']);
    }

    public function testTransportFailureDoesNotEscape(): void
    {
        $logFile = tempnam(sys_get_temp_dir(), 'cuelens-notification-test-');
        self::assertNotFalse($logFile);
        $previousErrorLog = ini_set('error_log', $logFile);

        try {
            $sent = send_operational_notification(
                OPERATIONAL_EVENT_ACTIVATION_COMPLETED,
                'activation_endpoint',
                null,
                static fn (array $notification): bool => false
            );
            $loggedMessage = file_get_contents($logFile);
        } finally {
            ini_set('error_log', is_string($previousErrorLog) ? $previousErrorLog : '');
            unlink($logFile);
        }

        self::assertNotFalse($loggedMessage);
        self::assertStringContainsString(
            'Operational notification failed: unexpected',
            $loggedMessage
        );
        self::assertFalse($sent);
    }

    public function testBuildsDataMinimizedClientErrorNotification(): void
    {
        $notification = build_operational_notification(
            OPERATIONAL_EVENT_CLIENT_ERROR,
            'dataprot_endpoint',
            'http_401',
            '123e4567-e89b-42d3-a456-426614174000',
            new DateTimeImmutable('2026-07-19T12:34:56Z')
        );

        self::assertSame('[CueLens] Clientfehler', $notification['subject']);
        self::assertStringContainsString('Ereignis: client_error', $notification['body']);
        self::assertStringContainsString('Fehlerkategorie: http_401', $notification['body']);
        self::assertStringNotContainsString('app_token', $notification['body']);
        self::assertStringNotContainsString('Authorization', $notification['body']);
        self::assertStringNotContainsString('@', $notification['body']);
    }

    public function testClientErrorReporterCanBeReplacedWithoutDatabaseOrEmailAccess(): void
    {
        $reported = null;
        $GLOBALS['cuelens_http_client_error_reporter'] = static function (
            int $statusCode,
            string $component,
            string $dbConfigFile
        ) use (&$reported): void {
            $reported = [$statusCode, $component, $dbConfigFile];
        };

        try {
            report_http_client_error(405, 'feature_endpoint', '/not/read/in/test.php');
        } finally {
            unset($GLOBALS['cuelens_http_client_error_reporter']);
        }

        self::assertSame(
            [405, 'feature_endpoint', '/not/read/in/test.php'],
            $reported
        );
    }

    public function testRejectsUnsupportedEventType(): void
    {
        $this->expectException(InvalidArgumentException::class);

        build_operational_notification('unknown_event', 'test_component');
    }
}
