<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

const MAX_CHAIN_INDEX = 20;
const APP_VERSION_MAX_LENGTH = 32;

function json_response(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES);
    exit;
}

function no_content(): never
{
    http_response_code(204);
    exit;
}

function bad_request(string $message = 'Bad request.'): never
{
    json_response(400, [
        'success' => false,
        'error' => $message,
    ]);
}

function server_error(): never
{
    json_response(500, [
        'success' => false,
        'error' => 'Server error.',
    ]);
}

function require_string(array $payload, string $key): string
{
    if (!array_key_exists($key, $payload) || !is_string($payload[$key])) {
        bad_request('Missing or invalid field: ' . $key);
    }

    $value = trim($payload[$key]);
    if ($value === '') {
        bad_request('Missing or invalid field: ' . $key);
    }

    return $value;
}

function validate_uuid(string $value, string $fieldName): void
{
    if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $value)) {
        bad_request('Malformed field: ' . $fieldName);
    }
}

function validate_hash(string $value, string $fieldName): void
{
    if (!preg_match('/^[0-9a-f]{64}$/i', $value)) {
        bad_request('Malformed field: ' . $fieldName);
    }
}

function validate_email_address(string $email): void
{
    if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        bad_request('Malformed field: email');
    }
}

function parse_craving(mixed $value): int
{
    $craving = filter_var($value, FILTER_VALIDATE_INT);
    if ($craving === false || $craving < 0 || $craving > 100) {
        bad_request('Field craving must be an integer between 0 and 100.');
    }

    return $craving;
}

function generate_uuid_v4(): string
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);

    return sprintf(
        '%s-%s-%s-%s-%s',
        substr($hex, 0, 8),
        substr($hex, 8, 4),
        substr($hex, 12, 4),
        substr($hex, 16, 4),
        substr($hex, 20, 12)
    );
}

function hmac_chain(string $appToken, string $secret): array
{
    $chain = [];
    $previous = hash_hmac('sha256', $appToken, $secret);
    $chain[1] = $previous;

    for ($index = 2; $index <= MAX_CHAIN_INDEX; $index++) {
        $previous = hash_hmac('sha256', $previous . $appToken, $secret);
        $chain[$index] = $previous;
    }

    return $chain;
}

function matching_chain_index(array $chain, string $hash): ?int
{
    $match = null;
    foreach ($chain as $index => $expectedHash) {
        if (hash_equals($expectedHash, strtolower($hash))) {
            $match = $index;
        }
    }

    return $match;
}

function participant_id(string $appToken, string $secret): string
{
    return hash_hmac('sha256', $appToken, $secret);
}

function condition_code_for_index(int $chainIndex): string
{
    return $chainIndex <= 10 ? 'CUE_MATCHING' : 'CUE_LABELING';
}

function pdo_from_config(array $config): PDO
{
    foreach (['host', 'dbname', 'user', 'pass', 'hmac_secret'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || $config[$key] === '') {
            server_error();
        }
    }

    return new PDO(
        "mysql:host={$config['host']};dbname={$config['dbname']};charset=utf8mb4",
        $config['user'],
        $config['pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
}

function handle_activation_request(PDO $pdo, string $secret, array $payload): never
{
    $email = require_string($payload, 'email');
    validate_email_address($email);

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare(
            'SELECT email
               FROM register
              WHERE email = :email
                AND doi = 1
                AND studyinfo = 1
                AND dataprot = 1
                AND app_token_issued_at IS NULL
              FOR UPDATE'
        );
        $stmt->execute([':email' => $email]);

        if ($stmt->fetch() === false) {
            $pdo->rollBack();
            bad_request('Registration is not eligible for activation.');
        }

        $appToken = generate_uuid_v4();
        $hash = hmac_chain($appToken, $secret)[1];

        $pdo->commit();
        json_response(200, [
            'success' => true,
            'app_token' => $appToken,
            'hash' => $hash,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        server_error();
    }
}

function handle_activation_confirmation(PDO $pdo, string $secret, array $payload): never
{
    $email = require_string($payload, 'email');
    $appToken = require_string($payload, 'app_token');
    $confirmedHash = strtolower(require_string($payload, 'confirmed_hash'));
    validate_email_address($email);
    validate_uuid($appToken, 'app_token');
    validate_hash($confirmedHash, 'confirmed_hash');

    $expectedHash = hmac_chain($appToken, $secret)[1];
    if (!hash_equals($expectedHash, $confirmedHash)) {
        bad_request('Confirmed hash does not match app token.');
    }

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare(
            'SELECT email
               FROM register
              WHERE email = :email
                AND doi = 1
                AND studyinfo = 1
                AND dataprot = 1
                AND app_token_issued_at IS NULL
              FOR UPDATE'
        );
        $stmt->execute([':email' => $email]);

        if ($stmt->fetch() === false) {
            $pdo->rollBack();
            bad_request('Registration is not eligible for activation confirmation.');
        }

        $update = $pdo->prepare(
            'UPDATE register
                SET app_token_issued_at = CURRENT_TIMESTAMP
              WHERE email = :email
                AND app_token_issued_at IS NULL'
        );
        $update->execute([':email' => $email]);

        $insert = $pdo->prepare(
            'INSERT INTO valid_hashes (hash_value) VALUES (:hash_value)'
        );
        $insert->execute([':hash_value' => $confirmedHash]);

        $pdo->commit();
        no_content();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        server_error();
    }
}

function handle_self_report(PDO $pdo, string $secret, array $payload): never
{
    $appToken = require_string($payload, 'app_token');
    $currentHash = strtolower(require_string($payload, 'hash'));
    $craving = parse_craving($payload['craving'] ?? null);
    $appVersion = null;

    if (isset($payload['app_version'])) {
        if (!is_string($payload['app_version'])) {
            bad_request('Malformed field: app_version');
        }
        $appVersion = substr(trim($payload['app_version']), 0, APP_VERSION_MAX_LENGTH);
        $appVersion = $appVersion === '' ? null : $appVersion;
    }

    validate_uuid($appToken, 'app_token');
    validate_hash($currentHash, 'hash');

    $chain = hmac_chain($appToken, $secret);
    $chainIndex = matching_chain_index($chain, $currentHash);
    if ($chainIndex === null) {
        bad_request('Hash does not match app token.');
    }

    $participantId = participant_id($appToken, $secret);
    $conditionCode = condition_code_for_index($chainIndex);

    $pdo->beginTransaction();
    try {
        $valid = $pdo->prepare(
            'SELECT hash_value
               FROM valid_hashes
              WHERE hash_value = :hash_value
              FOR UPDATE'
        );
        $valid->execute([':hash_value' => $currentHash]);

        if ($valid->fetch() === false) {
            $retry = $pdo->prepare(
                'SELECT participant_id, next_hash, situation_index, condition_code
                   FROM submission
                  WHERE consumed_hash = :consumed_hash
                  FOR UPDATE'
            );
            $retry->execute([':consumed_hash' => $currentHash]);
            $existing = $retry->fetch();

            if ($existing !== false && hash_equals($existing['participant_id'], $participantId)) {
                $pdo->commit();
                json_response(200, [
                    'success' => true,
                    'next_hash' => $existing['next_hash'],
                    'situation_index' => (int) $existing['situation_index'],
                    'condition_code' => $existing['condition_code'],
                ]);
            }

            $pdo->rollBack();
            bad_request('Hash is not valid for submission.');
        }

        $delete = $pdo->prepare('DELETE FROM valid_hashes WHERE hash_value = :hash_value');
        $delete->execute([':hash_value' => $currentHash]);

        if ($chainIndex === MAX_CHAIN_INDEX) {
            $report = $pdo->prepare(
                'INSERT INTO self_reports (participant_id, condition_code, craving)
                 VALUES (:participant_id, :condition_code, :craving)'
            );
            $report->bindValue(':participant_id', $participantId, PDO::PARAM_STR);
            $report->bindValue(':condition_code', $conditionCode, PDO::PARAM_STR);
            $report->bindValue(':craving', $craving, PDO::PARAM_INT);
            $report->execute();

            $compensationCode = generate_uuid_v4();
            $code = $pdo->prepare(
                'INSERT INTO compensation_code (compensation_code, confirmed_at)
                 VALUES (:compensation_code, NULL)'
            );
            $code->execute([':compensation_code' => $compensationCode]);

            $pdo->commit();
            json_response(200, [
                'success' => true,
                'status' => 'complete',
                'situation_index' => $chainIndex,
                'condition_code' => $conditionCode,
                'compensation_code' => $compensationCode,
            ]);
        }

        $nextHash = $chain[$chainIndex + 1];
        $submission = $pdo->prepare(
            'INSERT INTO submission
                (participant_id, consumed_hash, next_hash, craving, situation_index, condition_code, app_version)
             VALUES
                (:participant_id, :consumed_hash, :next_hash, :craving, :situation_index, :condition_code, :app_version)'
        );
        $submission->bindValue(':participant_id', $participantId, PDO::PARAM_STR);
        $submission->bindValue(':consumed_hash', $currentHash, PDO::PARAM_STR);
        $submission->bindValue(':next_hash', $nextHash, PDO::PARAM_STR);
        $submission->bindValue(':craving', $craving, PDO::PARAM_INT);
        $submission->bindValue(':situation_index', $chainIndex, PDO::PARAM_INT);
        $submission->bindValue(':condition_code', $conditionCode, PDO::PARAM_STR);
        $submission->bindValue(':app_version', $appVersion, $appVersion === null ? PDO::PARAM_NULL : PDO::PARAM_STR);
        $submission->execute();

        $pdo->commit();
        json_response(200, [
            'success' => true,
            'next_hash' => $nextHash,
            'situation_index' => $chainIndex,
            'condition_code' => $conditionCode,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        server_error();
    }
}

function handle_submission_confirmation(PDO $pdo, string $secret, array $payload): never
{
    $appToken = require_string($payload, 'app_token');
    $confirmedHash = strtolower(require_string($payload, 'confirmed_hash'));
    validate_uuid($appToken, 'app_token');
    validate_hash($confirmedHash, 'confirmed_hash');

    $participantId = participant_id($appToken, $secret);

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare(
            'SELECT id, participant_id, next_hash, craving, condition_code
               FROM submission
              WHERE next_hash = :next_hash
              FOR UPDATE'
        );
        $stmt->execute([':next_hash' => $confirmedHash]);
        $submission = $stmt->fetch();

        if ($submission === false || !hash_equals($submission['participant_id'], $participantId)) {
            $pdo->commit();
            no_content();
        }

        $report = $pdo->prepare(
            'INSERT INTO self_reports (participant_id, condition_code, craving)
             VALUES (:participant_id, :condition_code, :craving)'
        );
        $report->bindValue(':participant_id', $submission['participant_id'], PDO::PARAM_STR);
        $report->bindValue(':condition_code', $submission['condition_code'], PDO::PARAM_STR);
        $report->bindValue(':craving', (int) $submission['craving'], PDO::PARAM_INT);
        $report->execute();

        $valid = $pdo->prepare(
            'INSERT INTO valid_hashes (hash_value) VALUES (:hash_value)'
        );
        $valid->execute([':hash_value' => $confirmedHash]);

        $delete = $pdo->prepare('DELETE FROM submission WHERE id = :id');
        $delete->bindValue(':id', (int) $submission['id'], PDO::PARAM_INT);
        $delete->execute();

        $pdo->commit();
        no_content();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        server_error();
    }
}

function handle_compensation_confirmation(PDO $pdo, array $payload): never
{
    $compensationCode = require_string($payload, 'compensation_code');
    validate_uuid($compensationCode, 'compensation_code');

    try {
        $stmt = $pdo->prepare(
            'UPDATE compensation_code
                SET confirmed_at = COALESCE(confirmed_at, CURRENT_TIMESTAMP)
              WHERE compensation_code = :compensation_code'
        );
        $stmt->execute([':compensation_code' => $compensationCode]);
        no_content();
    } catch (Throwable $e) {
        server_error();
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    json_response(405, [
        'success' => false,
        'error' => 'Method not allowed. Use PUT.',
    ]);
}

$rawBody = file_get_contents('php://input');
if ($rawBody === false || trim($rawBody) === '') {
    bad_request('Missing JSON body.');
}

try {
    $payload = json_decode($rawBody, true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException $e) {
    bad_request('Malformed JSON body.');
}

if (!is_array($payload)) {
    bad_request('JSON body must be an object.');
}

$config = require __DIR__ . '/config/cuelens-craving.php';
$secret = is_array($config) && isset($config['hmac_secret']) && is_string($config['hmac_secret'])
    ? $config['hmac_secret']
    : '';

try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error();
}

if (isset($payload['email'], $payload['app_token'], $payload['confirmed_hash'])) {
    handle_activation_confirmation($pdo, $secret, $payload);
}

if (isset($payload['email'])) {
    handle_activation_request($pdo, $secret, $payload);
}

if (isset($payload['app_token'], $payload['hash'], $payload['craving'])) {
    handle_self_report($pdo, $secret, $payload);
}

if (isset($payload['app_token'], $payload['confirmed_hash'])) {
    handle_submission_confirmation($pdo, $secret, $payload);
}

if (isset($payload['compensation_code'])) {
    handle_compensation_confirmation($pdo, $payload);
}

bad_request('Unsupported submit payload.');
