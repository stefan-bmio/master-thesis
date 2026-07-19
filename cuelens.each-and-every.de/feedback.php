<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/feedback-store.php';

const MAX_SOURCE_LENGTH = 500;
const MAX_COMMENT_LENGTH = 5000;
const MAX_APP_VERSION_LENGTH = 64;

function json_response(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function no_content(): never
{
    http_response_code(204);
    exit;
}

function bad_request(string $message): never
{
    json_response(400, ['success' => false, 'error' => $message]);
}

function server_error(?Throwable $cause = null, ?PDO $pdo = null, ?array $dbConfig = null): never
{
    if ($cause !== null) {
        if ($pdo !== null) {
            log_error($pdo, 'Feedback endpoint failed.', $cause, 'feedback_endpoint');
        } elseif ($dbConfig !== null) {
            log_error_from_config(
                $dbConfig,
                'Feedback endpoint failed.',
                $cause,
                'feedback_endpoint'
            );
        }
    }
    json_response(500, ['success' => false, 'error' => 'Server error.']);
}

function optional_text(array $payload, string $field, int $maxLength): ?string
{
    if (!array_key_exists($field, $payload) || $payload[$field] === null) {
        return null;
    }
    if (!is_string($payload[$field])) {
        bad_request('Malformed field: ' . $field);
    }
    $value = trim($payload[$field]);
    if (mb_strlen($value, 'UTF-8') > $maxLength) {
        bad_request('Field is too long: ' . $field);
    }
    return $value === '' ? null : $value;
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    json_response(405, ['success' => false, 'error' => 'Method not allowed. Use POST.']);
}

$inputStream = PHP_SAPI === 'cli' ? 'php://stdin' : 'php://input';
$rawBody = file_get_contents($inputStream);
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

$source = optional_text($payload, 'source', MAX_SOURCE_LENGTH);
$comment = optional_text($payload, 'comment', MAX_COMMENT_LENGTH);
$appVersion = optional_text($payload, 'app_version', MAX_APP_VERSION_LENGTH);
if ($source === null && $comment === null) {
    bad_request('At least one feedback field is required.');
}

$config = require __DIR__ . '/config/cuelens-signup.php';
try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error($e, null, is_array($config) ? $config : []);
}

try {
    $result = store_feedback_with_soft_limit($pdo, $source, $comment, $appVersion);
    if ($result === FEEDBACK_STORED) {
        send_operational_notification(
            OPERATIONAL_EVENT_FEEDBACK_RECEIVED,
            'feedback_endpoint'
        );
    } else {
        error_log(
            'CueLens feedback soft limit reached; request discarded; request_id=' .
            operational_request_id()
        );
        send_operational_notification(
            OPERATIONAL_EVENT_FEEDBACK_LIMIT_REACHED,
            'feedback_endpoint'
        );
    }
    no_content();
} catch (Throwable $e) {
    server_error($e, $pdo);
}
