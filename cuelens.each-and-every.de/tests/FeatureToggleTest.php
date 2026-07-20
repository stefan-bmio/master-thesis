<?php
declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/feature-toggle.php';

final class FeatureToggleTest extends TestCase
{
    /** @return iterable<string, array{mixed, bool}> */
    public static function validValues(): iterable
    {
        yield 'disabled string' => ['0', false];
        yield 'disabled integer' => [0, false];
        yield 'enabled string' => ['1', true];
        yield 'enabled integer' => [1, true];
    }

    #[DataProvider('validValues')]
    public function testParsesStrictBooleanDatabaseValues(mixed $value, bool $expected): void
    {
        self::assertSame($expected, parse_feature_toggle_value($value));
    }

    public function testRejectsInvalidDatabaseValue(): void
    {
        $this->expectException(RuntimeException::class);
        parse_feature_toggle_value('true');
    }
}
