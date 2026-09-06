<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/participant-identifier.php';

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$rawIdentifier = getenv('CUELENS_APP_REVIEW_EMAIL');
if (!is_string($rawIdentifier) || $rawIdentifier === '') {
    fwrite(STDERR, "CUELENS_APP_REVIEW_EMAIL is required.\n");
    exit(2);
}

try {
    $identifier = ParticipantIdentifier::parse($rawIdentifier);
    if ($identifier->channel() !== ParticipantIdentifier::DIRECT) {
        throw new InvalidArgumentException('The review account must use direct registration.');
    }
    $config = require dirname(__DIR__) . '/config/cuelens-signup.php';
    if (!is_array($config)) {
        throw new RuntimeException('Invalid database configuration.');
    }
    foreach (['host', 'dbname', 'user', 'pass'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || $config[$key] === '') {
            throw new RuntimeException('Incomplete database configuration.');
        }
    }
    $pdo = new PDO(
        "mysql:host={$config['host']};dbname={$config['dbname']};charset=utf8mb4",
        $config['user'],
        $config['pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );

    $pdo->beginTransaction();
    $target = $pdo->prepare(
        'SELECT registration_id
           FROM register
          WHERE registration_channel = \'DIRECT\'
            AND email = :email
            AND registration_confirmed_at IS NOT NULL
            AND studyinfo = 1
          FOR UPDATE'
    );
    $target->execute([':email' => $identifier->activationValue()]);
    $targets = $target->fetchAll(PDO::FETCH_COLUMN);
    if (count($targets) !== 1) {
        throw new RuntimeException('Exactly one eligible direct registration is required.');
    }

    $existing = $pdo->prepare(
        'SELECT COUNT(*)
           FROM register
          WHERE is_app_review_account = 1
            AND registration_id <> :registration_id'
    );
    $existing->execute([':registration_id' => $targets[0]]);
    if ((int) $existing->fetchColumn() !== 0) {
        throw new RuntimeException('A different App Review account is already configured.');
    }

    $update = $pdo->prepare(
        'UPDATE register
            SET is_app_review_account = 1
          WHERE registration_id = :registration_id'
    );
    $update->execute([':registration_id' => $targets[0]]);
    $pdo->commit();
    fwrite(STDOUT, "App Review account configured.\n");
} catch (Throwable $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    fwrite(STDERR, 'App Review account was not configured: ' . $error->getMessage() . "\n");
    exit(1);
}
