<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';

function json_response(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES);
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
            log_error($pdo, $message, $cause);
        } elseif ($dbConfig !== null) {
            log_error_from_config($dbConfig, $message, $cause);
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

function validate_email_address(string $email): void
{
    if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        bad_request('Malformed field: email');
    }
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

function handle_activation_request(PDO $pdo, array $payload): never
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
        $update = $pdo->prepare(
            'UPDATE register
                SET app_token_issued_at = CURRENT_TIMESTAMP
              WHERE email = :email
                AND app_token_issued_at IS NULL'
        );
        $update->execute([':email' => $email]);

        $pdo->commit();
        json_response(200, [
            'success' => true,
            'app_token' => $appToken,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
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
    $dbConfig = require __DIR__ . '/config/cuelens-signup.php';
    if (is_array($dbConfig)) {
        log_error_from_config($dbConfig, 'Malformed JSON body.', $e);
    }
    bad_request('Malformed JSON body.');
}

if (!is_array($payload)) {
    bad_request('JSON body must be an object.');
}

$config = require __DIR__ . '/config/cuelens-signup.php';

try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error($e, null, is_array($config) ? $config : []);
}

if (isset($payload['email'])) {
    handle_activation_request($pdo, $payload);
}

bad_request('Unsupported activation payload.');
