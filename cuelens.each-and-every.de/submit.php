<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';

const TOTAL_SUBMISSION_COUNT = 20;

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

function server_error(?Throwable $cause = null, ?PDO $pdo = null, ?array $dbConfig = null): never
{
    $message = 'Server error.';
    if ($cause !== null) {
        if ($pdo !== null) {
            log_error($pdo, $message, $cause, 'submission_endpoint');
        } elseif ($dbConfig !== null) {
            log_error_from_config($dbConfig, $message, $cause, 'submission_endpoint');
        }
    }

    json_response(500, [
        'success' => false,
        'error' => $message,
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

function condition_code_for_index(int $situationIndex): string
{
    return $situationIndex <= 10 ? 'CUE_MATCHING' : 'CUE_LABELING';
}

function pdo_from_config(array $config): PDO
{
    foreach (['host', 'dbname', 'user', 'pass'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || $config[$key] === '') {
            throw new RuntimeException('Missing or invalid database config: ' . $key);
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

function handle_self_report(PDO $pdo, array $payload): never
{
    $appToken = require_string($payload, 'app_token');
    $craving = parse_craving($payload['craving'] ?? null);

    if (isset($payload['app_version'])) {
        if (!is_string($payload['app_version'])) {
            bad_request('Malformed field: app_version');
        }
    }

    validate_uuid($appToken, 'app_token');
    $participantId = hash('sha256', strtolower($appToken));

    $pdo->beginTransaction();
    try {
        $existing = $pdo->prepare(
            'SELECT participant_id
               FROM self_reports
              WHERE participant_id = :participant_id
              FOR UPDATE'
        );
        $existing->execute([':participant_id' => $participantId]);
        $submittedCount = count($existing->fetchAll());

        if ($submittedCount >= TOTAL_SUBMISSION_COUNT) {
            $pdo->rollBack();
            bad_request('Study is already complete.');
        }

        $situationIndex = $submittedCount + 1;
        $conditionCode = condition_code_for_index($situationIndex);

        $report = $pdo->prepare(
            'INSERT INTO self_reports (participant_id, condition_code, craving)
             VALUES (:participant_id, :condition_code, :craving)'
        );
        $report->bindValue(':participant_id', $participantId, PDO::PARAM_STR);
        $report->bindValue(':condition_code', $conditionCode, PDO::PARAM_STR);
        $report->bindValue(':craving', $craving, PDO::PARAM_INT);
        $report->execute();

        if ($situationIndex === TOTAL_SUBMISSION_COUNT) {
            $compensationCode = generate_uuid_v4();
            $code = $pdo->prepare(
                'INSERT INTO compensation_code (compensation_code)
                 VALUES (:compensation_code)'
            );
            $code->execute([':compensation_code' => $compensationCode]);

            $pdo->commit();
            json_response(200, [
                'success' => true,
                'status' => 'complete',
                'situation_index' => $situationIndex,
                'condition_code' => $conditionCode,
                'compensation_code' => $compensationCode,
            ]);
        }

        $pdo->commit();
        json_response(200, [
            'success' => true,
            'situation_index' => $situationIndex,
            'condition_code' => $conditionCode,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        server_error($e, $pdo);
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
        server_error($e, $pdo);
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
    $dbConfig = require __DIR__ . '/config/cuelens-craving.php';
    if (is_array($dbConfig)) {
        log_error_from_config($dbConfig, 'Malformed JSON body.', $e, 'submission_endpoint');
    }
    bad_request('Malformed JSON body.');
}

if (!is_array($payload)) {
    bad_request('JSON body must be an object.');
}

$config = require __DIR__ . '/config/cuelens-craving.php';

try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error($e, null, is_array($config) ? $config : []);
}

if (isset($payload['app_token'], $payload['craving'])) {
    handle_self_report($pdo, $payload);
}

if (isset($payload['compensation_code'])) {
    handle_compensation_confirmation($pdo, $payload);
}

bad_request('Unsupported submit payload.');
