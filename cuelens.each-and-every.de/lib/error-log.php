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
