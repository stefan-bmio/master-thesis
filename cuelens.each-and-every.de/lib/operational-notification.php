<?php
declare(strict_types=1);

use PHPMailer\PHPMailer\PHPMailer;

require_once __DIR__ . '/PHPMailer/Exception.php';
require_once __DIR__ . '/PHPMailer/PHPMailer.php';
require_once __DIR__ . '/PHPMailer/SMTP.php';

const OPERATIONAL_EVENT_FEEDBACK_RECEIVED = 'feedback_received';
const OPERATIONAL_EVENT_FEEDBACK_LIMIT_REACHED = 'feedback_limit_reached';
const OPERATIONAL_EVENT_REGISTRATION_CREATED = 'registration_created';
const OPERATIONAL_EVENT_PROLIFIC_REGISTRATION_CREATED = 'prolific_registration_created';
const OPERATIONAL_EVENT_ACTIVATION_COMPLETED = 'activation_completed';
const OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED = 'prolific_study_completed';
const OPERATIONAL_EVENT_CLIENT_ERROR = 'client_error';
const OPERATIONAL_EVENT_SERVER_ERROR = 'server_error';

/**
 * @return array{subject: string, body: string}
 */
function build_operational_notification(
    string $eventType,
    string $component,
    ?string $errorCategory = null,
    ?string $requestId = null,
    ?DateTimeImmutable $now = null
): array {
    $templates = [
        OPERATIONAL_EVENT_FEEDBACK_RECEIVED => [
            'subject' => '[CueLens] Neues Feedback',
            'notice' => 'Der Inhalt liegt in der geschuetzten Feedbacktabelle.',
        ],
        OPERATIONAL_EVENT_FEEDBACK_LIMIT_REACHED => [
            'subject' => '[CueLens] Feedbackgrenze erreicht',
            'notice' => 'Ein gueltiger Feedback-Request wurde wegen des weichen Grenzwerts verworfen.',
        ],
        OPERATIONAL_EVENT_REGISTRATION_CREATED => [
            'subject' => '[CueLens] Neue Registrierung',
            'notice' => 'Eine Registrierung wurde per Double-Opt-In bestaetigt.',
        ],
        OPERATIONAL_EVENT_PROLIFIC_REGISTRATION_CREATED => [
            'subject' => '[CueLens] Neue Prolific-Registrierung',
            'notice' => 'Eine Prolific-Registrierung wurde ohne direkte Identifikationsdaten erstellt.',
        ],
        OPERATIONAL_EVENT_ACTIVATION_COMPLETED => [
            'subject' => '[CueLens] App-Aktivierung abgeschlossen',
            'notice' => 'Eine App-Aktivierung wurde erfolgreich abgeschlossen.',
        ],
        OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED => [
            'subject' => '[CueLens] Prolific-Teilnahme abgeschlossen',
            'notice' => 'Die Zahlungsberechtigung liegt in der geschuetzten Registrierungsdatenbank vor.',
        ],
        OPERATIONAL_EVENT_CLIENT_ERROR => [
            'subject' => '[CueLens] Clientfehler',
            'notice' => 'Weitere technische Angaben liegen datensparsam im geschuetzten Serverprotokoll.',
        ],
        OPERATIONAL_EVENT_SERVER_ERROR => [
            'subject' => '[CueLens] Serverfehler',
            'notice' => 'Weitere technische Details liegen im geschuetzten Serverprotokoll.',
        ],
    ];
    if (!isset($templates[$eventType])) {
        throw new InvalidArgumentException('Unsupported operational event type.');
    }

    $safeComponent = preg_match('/^[a-z0-9_.-]{1,64}$/', $component) === 1
        ? $component
        : 'unknown';
    $safeCategory = $errorCategory !== null && preg_match('/^[a-z0-9_.-]{1,64}$/', $errorCategory) === 1
        ? $errorCategory
        : null;
    $id = $requestId ?? operational_request_id();
    if (preg_match('/^[a-f0-9-]{36}$/', $id) !== 1) {
        throw new InvalidArgumentException('Invalid request ID.');
    }
    $timestamp = ($now ?? new DateTimeImmutable('now', new DateTimeZone('UTC')))
        ->setTimezone(new DateTimeZone('UTC'))
        ->format('Y-m-d\TH:i:s\Z');

    $lines = [
        'Ereignis: ' . $eventType,
        'Zeitpunkt: ' . $timestamp,
        'Komponente: ' . $safeComponent,
        'Request-ID: ' . $id,
    ];
    if ($safeCategory !== null) {
        $lines[] = 'Fehlerkategorie: ' . $safeCategory;
    }
    $lines[] = 'Hinweis: ' . $templates[$eventType]['notice'];

    return [
        'subject' => $templates[$eventType]['subject'],
        'body' => implode("\n", $lines) . "\n",
    ];
}

/**
 * @param null|callable(array{subject: string, body: string}): bool $transport
 */
function send_operational_notification(
    string $eventType,
    string $component,
    ?string $errorCategory = null,
    ?callable $transport = null
): bool {
    try {
        $notification = build_operational_notification($eventType, $component, $errorCategory);
        if ($transport === null) {
            $GLOBALS['cuelens_operational_notifications'][] = $notification;
            return true;
        }
        $sent = $transport($notification);
        if (!$sent) {
            throw new RuntimeException('Operational notification transport returned false.');
        }
        return true;
    } catch (Throwable $error) {
        error_log('Operational notification failed: ' . operational_error_category($error));
        return false;
    }
}

function flush_operational_notifications(): void
{
    /** @var list<array{subject: string, body: string}> $notifications */
    $notifications = $GLOBALS['cuelens_operational_notifications'] ?? [];
    $GLOBALS['cuelens_operational_notifications'] = [];
    if ($notifications === []) {
        return;
    }

    if (function_exists('fastcgi_finish_request')) {
        fastcgi_finish_request();
    }
    foreach ($notifications as $notification) {
        try {
            if (!send_operational_notification_via_smtp($notification)) {
                throw new RuntimeException('Operational notification transport returned false.');
            }
        } catch (Throwable $error) {
            error_log('Operational notification failed: ' . operational_error_category($error));
        }
    }
}

/**
 * @param array{subject: string, body: string} $notification
 */
function send_operational_notification_via_smtp(array $notification): bool
{
    $config = require __DIR__ . '/../config/noreply-smtp.php';
    foreach (['host', 'smtpAuth', 'user', 'pass', 'smtpSecure', 'port', 'from', 'fromName', 'replyTo', 'replyToName', 'charset', 'alertTo'] as $key) {
        if (!array_key_exists($key, $config)) {
            throw new RuntimeException('Incomplete SMTP configuration.');
        }
    }

    $mail = new PHPMailer(true);
    $mail->isSMTP();
    $mail->Host = (string) $config['host'];
    $mail->SMTPAuth = (bool) $config['smtpAuth'];
    $mail->Username = (string) $config['user'];
    $mail->Password = (string) $config['pass'];
    $mail->SMTPSecure = $config['smtpSecure'];
    $mail->Port = (int) $config['port'];
    $mail->CharSet = (string) $config['charset'];
    $mail->Timeout = 10;
    $mail->setFrom((string) $config['from'], (string) $config['fromName']);
    $mail->addReplyTo((string) $config['replyTo'], (string) $config['replyToName']);
    $mail->addAddress((string) $config['alertTo']);
    $mail->Subject = $notification['subject'];
    $mail->Body = $notification['body'];

    return $mail->send();
}

function operational_request_id(): string
{
    static $requestId = null;
    if ($requestId === null) {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
        $hex = bin2hex($bytes);
        $requestId = sprintf(
            '%s-%s-%s-%s-%s',
            substr($hex, 0, 8),
            substr($hex, 8, 4),
            substr($hex, 12, 4),
            substr($hex, 16, 4),
            substr($hex, 20, 12)
        );
        if (!headers_sent()) {
            header('X-Request-ID: ' . $requestId);
        }
    }

    return $requestId;
}

function operational_error_category(Throwable $error): string
{
    return match (true) {
        $error instanceof PDOException => 'database',
        $error instanceof JsonException => 'json_processing',
        $error instanceof PHPMailer\PHPMailer\Exception => 'mail_delivery',
        default => 'unexpected',
    };
}

operational_request_id();
register_shutdown_function('flush_operational_notifications');
