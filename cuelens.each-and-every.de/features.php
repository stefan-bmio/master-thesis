<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/feature-toggle.php';

function json_response(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    exit;
}

function server_error(?Throwable $cause = null, ?PDO $pdo = null, ?array $config = null): never
{
    if ($cause !== null) {
        if ($pdo !== null) {
            log_error($pdo, 'Feature endpoint failed.', $cause, 'feature_endpoint');
        } elseif ($config !== null) {
            log_error_from_config($config, 'Feature endpoint failed.', $cause, 'feature_endpoint');
        }
    }
    json_response(500, ['success' => false, 'error' => 'Server error.']);
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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET');
    json_response(405, ['success' => false, 'error' => 'Method not allowed. Use GET.']);
}

$config = [];
try {
    $loadedConfig = require __DIR__ . '/config/cuelens-craving.php';
    $config = is_array($loadedConfig) ? $loadedConfig : [];
    $pdo = pdo_from_config($config);
    $enabled = feature_enabled($pdo, FEATURE_NEXT_STUDY_RUN);
    json_response(200, ['features' => ['next_study_run_enabled' => $enabled]]);
} catch (Throwable $error) {
    server_error($error, $pdo ?? null, $config);
}
