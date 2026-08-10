<?php
declare(strict_types=1);

const COMPLETION_MODE_COMPENSATION_CODE = 'COMPENSATION_CODE';
const COMPLETION_MODE_PROLIFIC_MANUAL = 'PROLIFIC_MANUAL';

function is_supported_completion_mode(string $completionMode): bool
{
    return in_array(
        $completionMode,
        [COMPLETION_MODE_COMPENSATION_CODE, COMPLETION_MODE_PROLIFIC_MANUAL],
        true
    );
}
