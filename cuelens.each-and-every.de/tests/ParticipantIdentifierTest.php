<?php
declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/participant-identifier.php';

final class ParticipantIdentifierTest extends TestCase
{
    #[DataProvider('validProlificIdProvider')]
    public function testAcceptsProlificIdsAndPreservesCase(string $input, string $expected): void
    {
        $identifier = ParticipantIdentifier::parse($input);

        self::assertSame(ParticipantIdentifier::PROLIFIC, $identifier->channel());
        self::assertSame($expected, $identifier->value());
        self::assertSame($expected, $identifier->activationValue());
        self::assertSame($expected, $identifier->prolificId());
        self::assertNull($identifier->email());
    }

    /** @return iterable<string, array{string, string}> */
    public static function validProlificIdProvider(): iterable
    {
        yield 'mixed case' => ['AbCdEf1234567890GhIjKlMn', 'AbCdEf1234567890GhIjKlMn'];
        yield 'surrounding whitespace' => [" \tAbCdEf1234567890GhIjKlMn\r\n", 'AbCdEf1234567890GhIjKlMn'];
        yield 'digits only' => ['123456789012345678901234', '123456789012345678901234'];
    }

    public function testAcceptsEmailWithoutChangingItsStoredSpelling(): void
    {
        $identifier = ParticipantIdentifier::parse('  Participant@Example.ORG  ');

        self::assertSame(ParticipantIdentifier::DIRECT, $identifier->channel());
        self::assertSame('Participant@Example.ORG', $identifier->value());
        self::assertSame('participant@example.org', $identifier->activationValue());
        self::assertSame('Participant@Example.ORG', $identifier->email());
        self::assertNull($identifier->prolificId());
    }

    #[DataProvider('invalidIdentifierProvider')]
    public function testRejectsInvalidIdentifiers(string $input): void
    {
        $this->expectException(InvalidArgumentException::class);

        ParticipantIdentifier::parse($input);
    }

    /** @return iterable<string, array{string}> */
    public static function invalidIdentifierProvider(): iterable
    {
        yield 'empty' => [''];
        yield 'whitespace' => ['   '];
        yield '23 characters' => ['AbCdEf1234567890GhIjKlM'];
        yield '25 characters' => ['AbCdEf1234567890GhIjKlMnO'];
        yield 'internal whitespace' => ['AbCdEf123456 7890GhIjKlM'];
        yield 'punctuation' => ['AbCdEf1234567890GhIjKlM-'];
        yield 'unicode look alike' => ['AbCdEf1234567890GhIjKlMö'];
        yield 'line break inside' => ["AbCdEf123456\n890GhIjKlMn"];
        yield 'malformed email' => ['participant@example'];
    }
}
