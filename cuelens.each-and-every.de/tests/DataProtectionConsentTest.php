<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/data-protection-consent.php';

final class DataProtectionConsentTest extends TestCase
{
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';

    public function testExtractsAndNormalizesAppTokenFromPayload(): void
    {
        self::assertSame(
            self::TOKEN,
            data_protection_app_token([
                'app_token' => strtoupper(self::TOKEN),
            ])
        );
    }

    /** @dataProvider invalidTokenPayloadProvider */
    public function testRejectsInvalidTokenPayload(array $payload): void
    {
        self::assertNull(data_protection_app_token($payload));
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function invalidTokenPayloadProvider(): iterable
    {
        yield 'missing field' => [[]];
        yield 'non-string field' => [['app_token' => 42]];
        yield 'not UUID v4' => [[
            'app_token' => '550e8400-e29b-11d4-a716-446655440000',
        ]];
    }
}
