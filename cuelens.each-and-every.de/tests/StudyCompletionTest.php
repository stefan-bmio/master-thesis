<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/study-completion.php';

final class StudyCompletionTest extends TestCase
{
    public function testConditionAllocationAndTotalCountRemainUnchanged(): void
    {
        self::assertSame(20, TOTAL_SUBMISSION_COUNT);
        self::assertSame('CUE_MATCHING', condition_code_for_index(1));
        self::assertSame('CUE_MATCHING', condition_code_for_index(10));
        self::assertSame('CUE_LABELING', condition_code_for_index(11));
        self::assertSame('CUE_LABELING', condition_code_for_index(20));
    }

    public function testGeneratedCompensationCodeIsUuidV4(): void
    {
        self::assertMatchesRegularExpression(
            '/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/D',
            generate_compensation_uuid_v4()
        );
    }

    public function testCompletionResponsesKeepChannelsExplicitAndNonIdentifying(): void
    {
        $direct = completed_study_response(
            COMPLETION_MODE_COMPENSATION_CODE,
            '550e8400-e29b-41d4-a716-446655440000'
        );
        self::assertSame([
            'success' => true,
            'status' => 'complete',
            'situation_index' => 20,
            'condition_code' => 'CUE_LABELING',
            'compensation_code' => '550e8400-e29b-41d4-a716-446655440000',
        ], $direct);
        self::assertArrayNotHasKey('completion_mode', $direct);

        $prolific = completed_study_response(COMPLETION_MODE_PROLIFIC_MANUAL);
        self::assertSame([
            'success' => true,
            'status' => 'complete',
            'situation_index' => 20,
            'condition_code' => 'CUE_LABELING',
            'completion_mode' => 'PROLIFIC_MANUAL',
        ], $prolific);
        self::assertArrayNotHasKey('compensation_code', $prolific);

        $this->expectException(RuntimeException::class);
        completed_study_response('UNKNOWN');
    }
}
