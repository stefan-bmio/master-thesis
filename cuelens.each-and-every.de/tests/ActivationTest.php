<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/activation.php';

final class ActivationTest extends TestCase
{
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';
    private const PROLIFIC_ID = 'AbCdEfGhIjKlMnOpQrStUv12';

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
            '8ae7c0274d37ba8c2cc8015f42e3746dd30920a73e8f1322f3a13347cff46d1b',
            $hash,
            'The legacy activation:v1 input must remain byte-for-byte compatible.'
        );
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

    public function testProlificHashUsesSeparateDomainAndPreservesIdentifierCase(): void
    {
        $identifier = ParticipantIdentifier::parse(self::PROLIFIC_ID);
        $lowercaseIdentifier = ParticipantIdentifier::parse(strtolower(self::PROLIFIC_ID));
        $prolificHash = activation_token_hash_for_identifier('secret', $identifier, self::TOKEN);

        self::assertSame(
            hash_hmac(
                'sha256',
                "activation:prolific:v1\0" . self::PROLIFIC_ID . "\0" . self::TOKEN,
                'secret'
            ),
            $prolificHash
        );
        self::assertNotSame(
            $prolificHash,
            activation_token_hash_for_identifier('secret', $lowercaseIdentifier, self::TOKEN)
        );
        self::assertNotSame(
            activation_token_hash('secret', 'participant@example.org', self::TOKEN),
            $prolificHash
        );
    }

    /** @dataProvider malformedIdentifierProvider */
    public function testActivationRejectsMalformedIdentifiers(string $value): void
    {
        $this->expectException(InvalidArgumentException::class);
        activation_identifier($value);
    }

    /** @return iterable<string, array{string}> */
    public static function malformedIdentifierProvider(): iterable
    {
        yield 'empty' => [''];
        yield 'invalid email' => ['participant-at-example.org'];
        yield 'short prolific ID' => ['AbCdEfGhIjKlMnOpQrStUv1'];
        yield 'prolific ID with punctuation' => ['AbCdEfGhIjKlMnOpQrStUv1!'];
    }

    public function testMapsAdministrativeChannelToNonIdentifyingCompletionMode(): void
    {
        self::assertSame(
            COMPLETION_MODE_COMPENSATION_CODE,
            completion_mode_for_registration_channel(ParticipantIdentifier::DIRECT)
        );
        self::assertSame(
            COMPLETION_MODE_PROLIFIC_MANUAL,
            completion_mode_for_registration_channel(ParticipantIdentifier::PROLIFIC)
        );

        $this->expectException(RuntimeException::class);
        completion_mode_for_registration_channel('UNKNOWN');
    }
}
