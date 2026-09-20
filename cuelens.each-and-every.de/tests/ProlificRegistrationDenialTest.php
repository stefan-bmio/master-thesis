<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/error-log.php';

final class ProlificRegistrationDenialTest extends TestCase
{
    protected function tearDown(): void
    {
        // Prevent the shutdown handler from sending real mail during tests.
        $GLOBALS['cuelens_operational_notifications'] = [];
    }

    public function testEachDenialCreatesOneLogAndOneCorrelatedNotification(): void
    {
        $GLOBALS['cuelens_operational_notifications'] = [];
        $logs = [];
        $writer = static function (string $message, string $cause) use (&$logs): void {
            $logs[] = json_decode($cause, true, 32, JSON_THROW_ON_ERROR);
        };
        report_prolific_registration_denied([], [], $writer);
        report_prolific_registration_denied([], ['REJECTED', 'SCREENED OUT'], $writer);

        self::assertCount(2, $logs);
        self::assertSame('participant_not_found', $logs[0]['reason']);
        self::assertSame([], $logs[0]['submission_statuses']);
        self::assertSame('submission_status_not_allowed', $logs[1]['reason']);
        self::assertSame(['REJECTED', 'SCREENED OUT'], $logs[1]['submission_statuses']);
        $notifications = $GLOBALS['cuelens_operational_notifications'];
        self::assertCount(2, $notifications);
        foreach ($notifications as $index => $notification) {
            self::assertSame('[CueLens] Prolific-Registrierung nicht zugelassen', $notification['subject']);
            self::assertStringContainsString('Request-ID: ' . $logs[$index]['request_id'], $notification['body']);
            self::assertStringContainsString('Ereignis: prolific_registration_denied', $notification['body']);
            self::assertStringNotContainsString('REJECTED', $notification['body']);
            self::assertStringNotContainsString('participant_id', json_encode($logs[$index]));
        }
    }

    public function testLoggingFailureStillQueuesOnlyTheDenialNotification(): void
    {
        $GLOBALS['cuelens_operational_notifications'] = [];
        $path = tempnam(sys_get_temp_dir(), 'denial-log-');
        $previous = ini_set('error_log', $path);
        try {
            report_prolific_registration_denied([], ['REJECTED'], static function (): void {
                throw new RuntimeException('sensitive database detail');
            });
            self::assertCount(1, $GLOBALS['cuelens_operational_notifications']);
            self::assertStringContainsString('request_id=', file_get_contents($path));
            self::assertStringNotContainsString('sensitive database detail', file_get_contents($path));
        } finally {
            ini_set('error_log', $previous);
            unlink($path);
        }
    }
}
