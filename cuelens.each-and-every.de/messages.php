<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';

const MESSAGES_DB_CONFIG_FILE = __DIR__ . '/config/cuelens-craving.php';

function json_response(int $statusCode, array $payload): never
{
    if ($statusCode >= 400 && $statusCode <= 499) {
        report_http_client_error(
            $statusCode,
            'messages_endpoint',
            MESSAGES_DB_CONFIG_FILE
        );
    }
    http_response_code($statusCode);
    echo json_encode(
        $payload,
        JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
    );
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
            log_error($pdo, $message, $cause, 'messages_endpoint');
        } elseif ($dbConfig !== null) {
            log_error_from_config($dbConfig, $message, $cause, 'messages_endpoint');
        }
    }

    json_response(500, [
        'success' => false,
        'error' => $message,
    ]);
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

/**
 * @return list<array{id: int, created_at: string, text_de: string, text_en: string}>
 */
function fetch_messages(PDO $pdo): array
{
    $timeZone = $pdo->prepare("SET time_zone = '+00:00'");
    $timeZone->execute();

    $stmt = $pdo->prepare(
        "SELECT id,
                DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS created_at,
                text_de,
                text_en
           FROM messages
          ORDER BY created_at ASC, id ASC"
    );

    $stmt->execute();

    $messages = [];
    foreach ($stmt->fetchAll() as $row) {
        $messages[] = [
            'id' => (int) $row['id'],
            'created_at' => (string) $row['created_at'],
            'text_de' => (string) $row['text_de'],
            'text_en' => (string) $row['text_en'],
        ];
    }

    return $messages;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET');
    json_response(405, [
        'success' => false,
        'error' => 'Method not allowed. Use GET.',
    ]);
}

$config = require MESSAGES_DB_CONFIG_FILE;

try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error($e, null, is_array($config) ? $config : []);
}

try {
    json_response(200, [
        'messages' => fetch_messages($pdo),
    ]);
} catch (Throwable $e) {
    server_error($e, $pdo);
}
