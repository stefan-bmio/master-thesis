<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/activation.php';

final class ActivationTest extends TestCase
{
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';

    public function testNormalizesEmailAndRecognizesUuidV4(): void
    {
        self::assertSame(
            'participant@example.org',
            normalize_activation_email('  Participant@Example.ORG ')
        );
        self::assertTrue(is_uuid_v4(self::TOKEN));
        self::assertFalse(is_uuid_v4('550e8400-e29b-11d4-a716-446655440000'));
        self::assertFalse(is_uuid_v4('not-a-token'));
    }

    public function testTokenHashIsBoundToSecretEmailAndToken(): void
    {
        $hash = activation_token_hash('secret', 'Participant@Example.ORG', self::TOKEN);

        self::assertSame(
            $hash,
            activation_token_hash('secret', 'participant@example.org', strtoupper(self::TOKEN))
        );
        self::assertNotSame(
            $hash,
            activation_token_hash('other-secret', 'participant@example.org', self::TOKEN)
        );
        self::assertNotSame(
            $hash,
            activation_token_hash('secret', 'other@example.org', self::TOKEN)
        );
        self::assertNotSame(
            $hash,
            activation_token_hash('secret', 'participant@example.org', generate_activation_uuid_v4())
        );
    }

    public function testGeneratedTokenIsUuidV4(): void
    {
        self::assertTrue(is_uuid_v4(generate_activation_uuid_v4()));
    }
}
