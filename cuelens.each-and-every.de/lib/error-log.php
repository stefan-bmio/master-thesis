<?php
declare(strict_types=1);

require_once __DIR__ . '/operational-notification.php';

function log_error(
    PDO $pdo,
    string $errorMessage,
    Throwable $cause,
    string $component = 'backend'
): void
{
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO error_log (created_at, error_message, cause)
             VALUES (CURRENT_TIMESTAMP, :error_message, :cause)'
        );
        $stmt->execute([
            ':error_message' => $errorMessage,
            ':cause' => (string) $cause,
        ]);
    } catch (Throwable $loggingError) {
        error_log('Could not write error_log entry: ' . operational_error_category($loggingError));
    }
    send_operational_notification(
        OPERATIONAL_EVENT_SERVER_ERROR,
        $component,
        operational_error_category($cause)
    );
}

function log_error_from_config(
    array $dbConfig,
    string $errorMessage,
    Throwable $cause,
    string $component = 'backend'
): void
{
    try {
        $pdo = new PDO(
            "mysql:host={$dbConfig['host']};dbname={$dbConfig['dbname']};charset=utf8mb4",
            $dbConfig['user'],
            $dbConfig['pass'],
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        log_error($pdo, $errorMessage, $cause, $component);
    } catch (Throwable $loggingError) {
        error_log('Could not connect for error_log entry: ' . operational_error_category($loggingError));
        send_operational_notification(
            OPERATIONAL_EVENT_SERVER_ERROR,
            $component,
            operational_error_category($cause)
        );
    }
}

/**
 * Persists and reports a 4xx response without retaining request payloads,
 * credentials, tokens, e-mail addresses, IP addresses, or user-agent strings.
 *
 * The optional global reporter is a test seam. Production requests use the
 * database and operational-notification path below.
 */
function report_http_client_error(
    int $statusCode,
    string $component,
    string $dbConfigFile
): void {
    if ($statusCode < 400 || $statusCode > 499) {
        throw new InvalidArgumentException('HTTP client error status must be between 400 and 499.');
    }

    $testReporter = $GLOBALS['cuelens_http_client_error_reporter'] ?? null;
    if (is_callable($testReporter)) {
        $testReporter($statusCode, $component, $dbConfigFile);
        return;
    }

    $safeComponent = preg_match('/^[a-z0-9_.-]{1,64}$/', $component) === 1
        ? $component
        : 'unknown';
    $category = 'http_' . $statusCode;
    $requestId = operational_request_id();

    try {
        $dbConfig = require $dbConfigFile;
        if (!is_array($dbConfig)) {
            throw new RuntimeException('Invalid database configuration.');
        }
        foreach (['host', 'dbname', 'user', 'pass'] as $key) {
            if (!isset($dbConfig[$key]) || !is_string($dbConfig[$key]) || $dbConfig[$key] === '') {
                throw new RuntimeException('Missing or invalid database configuration.');
            }
        }

        $pdo = new PDO(
            "mysql:host={$dbConfig['host']};dbname={$dbConfig['dbname']};charset=utf8mb4",
            $dbConfig['user'],
            $dbConfig['pass'],
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        $stmt = $pdo->prepare(
            'INSERT INTO error_log (created_at, error_message, cause)
             VALUES (CURRENT_TIMESTAMP, :error_message, :cause)'
        );
        $stmt->execute([
            ':error_message' => 'HTTP client error in ' . $safeComponent . '.',
            ':cause' => 'status_code=' . $statusCode . '; request_id=' . $requestId,
        ]);
    } catch (Throwable $loggingError) {
        error_log(
            'Could not write HTTP client error entry: ' .
            operational_error_category($loggingError) .
            '; request_id=' .
            $requestId
        );
    }

    send_operational_notification(
        OPERATIONAL_EVENT_CLIENT_ERROR,
        $safeComponent,
        $category
    );
}
