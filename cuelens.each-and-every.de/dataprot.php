<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/data-protection-consent.php';

const DATAPROT_DB_CONFIG_FILE = __DIR__ . '/config/cuelens-signup.php';

function dataprot_json_response(int $statusCode, array $payload): never
{
    if ($statusCode >= 400 && $statusCode <= 499) {
        report_http_client_error(
            $statusCode,
            'dataprot_endpoint',
            DATAPROT_DB_CONFIG_FILE
        );
    }
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    exit;
}

function dataprot_bad_request(): never
{
    dataprot_json_response(400, ['success' => false, 'error' => 'Bad request.']);
}

function dataprot_unauthorized(): never
{
    dataprot_json_response(401, ['success' => false, 'error' => 'Unauthorized.']);
}

function dataprot_server_error(
    ?Throwable $cause = null,
    ?PDO $pdo = null,
    ?array $dbConfig = null
): never {
    if ($cause !== null) {
        if ($pdo !== null) {
            log_error($pdo, 'Data protection endpoint failed.', $cause, 'dataprot_endpoint');
        } elseif ($dbConfig !== null) {
            log_error_from_config(
                $dbConfig,
                'Data protection endpoint failed.',
                $cause,
                'dataprot_endpoint'
            );
        }
    }
    dataprot_json_response(500, ['success' => false, 'error' => 'Server error.']);
}

function dataprot_pdo_from_config(array $config): PDO
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

$method = $_SERVER['REQUEST_METHOD'] ?? '';
if ($method !== 'POST' && $method !== 'PUT') {
    header('Allow: POST, PUT');
    dataprot_json_response(
        405,
        ['success' => false, 'error' => 'Method not allowed. Use POST or PUT.']
    );
}

$inputStream = PHP_SAPI === 'cli' ? 'php://stdin' : 'php://input';
$rawBody = file_get_contents($inputStream);
if ($rawBody === false || trim($rawBody) === '') {
    dataprot_bad_request();
}
try {
    $decodedPayload = json_decode($rawBody, false, 512, JSON_THROW_ON_ERROR);
} catch (JsonException) {
    dataprot_bad_request();
}
if (!$decodedPayload instanceof stdClass) {
    dataprot_bad_request();
}
$payload = get_object_vars($decodedPayload);

$allowedFields = $method === 'POST'
    ? ['app_token']
    : ['app_token', 'dataprot'];
if (array_diff(array_keys($payload), $allowedFields) !== []) {
    dataprot_bad_request();
}

$appToken = data_protection_app_token($payload);
if ($appToken === null) {
    dataprot_unauthorized();
}

if ($method === 'PUT') {
    if (
        count($payload) !== 2 ||
        ($payload['dataprot'] ?? null) !== true
    ) {
        dataprot_bad_request();
    }
} elseif (count($payload) !== 1) {
    dataprot_bad_request();
}

$dbConfig = require DATAPROT_DB_CONFIG_FILE;
$hostConfig = require __DIR__ . '/config/host.php';
try {
    if (
        !is_array($hostConfig) ||
        !isset($hostConfig['secret']['pseudonym']) ||
        !is_string($hostConfig['secret']['pseudonym']) ||
        $hostConfig['secret']['pseudonym'] === ''
    ) {
        throw new RuntimeException('Missing pseudonym secret.');
    }
    $pdo = dataprot_pdo_from_config(is_array($dbConfig) ? $dbConfig : []);
} catch (Throwable $error) {
    dataprot_server_error($error, null, is_array($dbConfig) ? $dbConfig : []);
}

try {
    if ($method === 'POST') {
        dataprot_json_response(200, [
            'dataprot' => data_protection_status(
                $pdo,
                $hostConfig['secret']['pseudonym'],
                $appToken
            ),
        ]);
    }

    accept_data_protection($pdo, $hostConfig['secret']['pseudonym'], $appToken);
    dataprot_json_response(200, ['dataprot' => true]);
} catch (DataProtectionAuthenticationException) {
    dataprot_unauthorized();
} catch (Throwable $error) {
    dataprot_server_error($error, $pdo);
}
