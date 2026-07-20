<?php
declare(strict_types=1);

const FEATURE_NEXT_STUDY_RUN = 'next_study_run_enabled';

function feature_enabled(PDO $pdo, string $featureKey): bool
{
    $statement = $pdo->prepare(
        'SELECT enabled FROM feature_toggle WHERE feature_key = :feature_key'
    );
    $statement->execute([':feature_key' => $featureKey]);
    $value = $statement->fetchColumn();
    if ($value === false) {
        throw new RuntimeException('Missing feature toggle.');
    }

    return parse_feature_toggle_value($value);
}

function parse_feature_toggle_value(mixed $value): bool
{
    return match ((string) $value) {
        '0' => false,
        '1' => true,
        default => throw new RuntimeException('Invalid feature toggle value.'),
    };
}
