<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/lib/error-log.php';

function json_response(int $statusCode, array $payload): never
{
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

/**
 * @return list<int>
 */
function parse_excluded_ids(mixed $value): array
{
    if ($value === null || $value === '') {
        return [];
    }

    if (!is_string($value)) {
        bad_request('Malformed query parameter: exclude_ids');
    }

    $ids = [];
    foreach (explode(',', $value) as $rawId) {
        $candidate = trim($rawId);
        if (!preg_match('/^[1-9][0-9]*$/', $candidate)) {
            bad_request('Malformed query parameter: exclude_ids');
        }

        $id = filter_var(
            $candidate,
            FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 1, 'max_range' => PHP_INT_MAX]]
        );
        if ($id === false) {
            bad_request('Malformed query parameter: exclude_ids');
        }

        $ids[$id] = $id;
    }

    return array_values($ids);
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
 * @param list<int> $excludedIds
 * @return list<array{id: int, created_at: string, text_de: string, text_en: string}>
 */
function fetch_messages(PDO $pdo, array $excludedIds): array
{
    $timeZone = $pdo->prepare("SET time_zone = '+00:00'");
    $timeZone->execute();

    $where = '';
    if ($excludedIds !== []) {
        $placeholders = [];
        foreach (array_keys($excludedIds) as $index) {
            $placeholders[] = ':excluded_id_' . $index;
        }
        $where = ' WHERE id NOT IN (' . implode(', ', $placeholders) . ')';
    }

    $stmt = $pdo->prepare(
        "SELECT id,
                DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS created_at,
                text_de,
                text_en
           FROM messages" . $where . '
          ORDER BY created_at ASC, id ASC'
    );

    foreach ($excludedIds as $index => $id) {
        $stmt->bindValue(':excluded_id_' . $index, $id, PDO::PARAM_INT);
    }
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

$excludedIds = parse_excluded_ids($_GET['exclude_ids'] ?? null);
$config = require __DIR__ . '/config/cuelens-craving.php';

try {
    $pdo = pdo_from_config(is_array($config) ? $config : []);
} catch (Throwable $e) {
    server_error($e, null, is_array($config) ? $config : []);
}

try {
    json_response(200, [
        'messages' => fetch_messages($pdo, $excludedIds),
    ]);
} catch (Throwable $e) {
    server_error($e, $pdo);
}
