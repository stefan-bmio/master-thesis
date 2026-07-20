<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/token-identity.php';

final class TokenIdentityTest extends TestCase
{
    private const SECRET = 'test-secret';
    private const TOKEN = '550E8400-E29B-41D4-A716-446655440000';

    public function testHashesAreStableCaseInsensitiveAndDomainSeparated(): void
    {
        $validHash = valid_app_token_hash(self::SECRET, self::TOKEN);
        $participantId = participant_id_for_app_token(self::SECRET, self::TOKEN);

        self::assertSame(
            $validHash,
            valid_app_token_hash(self::SECRET, strtolower(self::TOKEN))
        );
        self::assertSame(64, strlen($validHash));
        self::assertNotSame($validHash, $participantId);
    }
}
