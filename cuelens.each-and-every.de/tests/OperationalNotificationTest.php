<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/operational-notification.php';

final class OperationalNotificationTest extends TestCase
{
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
        $sent = send_operational_notification(
            OPERATIONAL_EVENT_ACTIVATION_COMPLETED,
            'activation_endpoint',
            null,
            static fn (array $notification): bool => false
        );

        self::assertFalse($sent);
    }

    public function testRejectsUnsupportedEventType(): void
    {
        $this->expectException(InvalidArgumentException::class);

        build_operational_notification('unknown_event', 'test_component');
    }
}
