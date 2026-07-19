<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/activation.php';

function json_response(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    exit;
}

function no_content(): never
{
    http_response_code(204);
    exit;
}

function bad_request(): never
{
    json_response(400, ['success' => false, 'error' => 'Bad request.']);
}

function server_error(?Throwable $cause = null, ?PDO $pdo = null, ?array $dbConfig = null): never
{
    if ($cause !== null) {
        if ($pdo !== null) {
            log_error($pdo, 'Activation endpoint failed.', $cause, 'activation_endpoint');
        } elseif ($dbConfig !== null) {
            log_error_from_config(
                $dbConfig,
                'Activation endpoint failed.',
                $cause,
                'activation_endpoint'
            );
        }
    }
    json_response(500, ['success' => false, 'error' => 'Server error.']);
}

function require_request_string(array $payload, string $key): string
{
    if (!array_key_exists($key, $payload) || !is_string($payload[$key])) {
        bad_request();
    }
    $value = trim($payload[$key]);
    if ($value === '') {
        bad_request();
    }
    return $value;
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

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    header('Allow: PUT');
    json_response(405, ['success' => false, 'error' => 'Method not allowed. Use PUT.']);
}

$rawBody = file_get_contents(PHP_SAPI === 'cli' ? 'php://stdin' : 'php://input');
if ($rawBody === false || trim($rawBody) === '') {
    bad_request();
}
try {
    $payload = json_decode($rawBody, true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException) {
    bad_request();
}
if (!is_array($payload)) {
    bad_request();
}

$email = normalize_activation_email(require_request_string($payload, 'email'));
if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    bad_request();
}
$isConfirmation = array_key_exists('app_token', $payload);
$appToken = $isConfirmation ? require_request_string($payload, 'app_token') : null;
if ($appToken !== null && !is_uuid_v4($appToken)) {
    bad_request();
}

$dbConfig = require __DIR__ . '/config/cuelens-signup.php';
$hostConfig = require __DIR__ . '/config/host.php';
try {
    if (
        !is_array($hostConfig) ||
        !isset($hostConfig['secret']['activation']) ||
        !is_string($hostConfig['secret']['activation']) ||
        $hostConfig['secret']['activation'] === ''
    ) {
        throw new RuntimeException('Missing activation secret.');
    }
    $pdo = pdo_from_config(is_array($dbConfig) ? $dbConfig : []);
} catch (Throwable $error) {
    server_error($error, null, is_array($dbConfig) ? $dbConfig : []);
}

try {
    if ($appToken === null) {
        $issuedToken = request_activation_token(
            $pdo,
            $email,
            $hostConfig['secret']['activation']
        );
        json_response(200, ['app_token' => $issuedToken]);
    }

    confirm_activation_token($pdo, $email, $appToken, $hostConfig['secret']['activation']);
    send_operational_notification(
        OPERATIONAL_EVENT_ACTIVATION_COMPLETED,
        'activation_endpoint'
    );
    no_content();
} catch (ActivationRejectedException) {
    bad_request();
} catch (Throwable $error) {
    server_error($error, $pdo);
}
