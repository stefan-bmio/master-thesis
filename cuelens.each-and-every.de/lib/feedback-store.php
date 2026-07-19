<?php
declare(strict_types=1);

const FEEDBACK_SOFT_LIMIT = 200;
const FEEDBACK_STORED = 'stored';
const FEEDBACK_DISCARDED = 'discarded';

function store_feedback_with_soft_limit(
    PDO $pdo,
    ?string $source,
    ?string $comment,
    ?string $appVersion
): string {
    $countStatement = $pdo->prepare('SELECT COUNT(*) FROM feedback');
    $countStatement->execute();
    $count = (int) $countStatement->fetchColumn();

    if (!feedback_is_below_soft_limit($count)) {
        return FEEDBACK_DISCARDED;
    }

    $insert = $pdo->prepare(
        'INSERT INTO feedback (source, comment, app_version)
         VALUES (:source, :comment, :app_version)'
    );
    $insert->execute([
        ':source' => $source,
        ':comment' => $comment,
        ':app_version' => $appVersion,
    ]);

    return FEEDBACK_STORED;
}

function feedback_is_below_soft_limit(int $count): bool
{
    return $count < FEEDBACK_SOFT_LIMIT;
}
