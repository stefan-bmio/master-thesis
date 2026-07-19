<?php
declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/feedback-store.php';

final class FeedbackStoreTest extends TestCase
{
    #[DataProvider('counts')]
    public function testSoftLimitDecision(int $count, bool $expected): void
    {
        self::assertSame($expected, feedback_is_below_soft_limit($count));
    }

    /**
     * @return iterable<string, array{int, bool}>
     */
    public static function counts(): iterable
    {
        yield 'empty table' => [0, true];
        yield 'entry 200 can be stored' => [199, true];
        yield '200 entries reached' => [200, false];
        yield 'soft limit already exceeded' => [201, false];
    }
}
