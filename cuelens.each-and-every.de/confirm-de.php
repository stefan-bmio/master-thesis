<?php
declare(strict_types=1);

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/registration.php';

$message = 'Dieser Bestätigungslink ist nicht gültig.';
$messageIsHtml = false;
$doiToken = $_GET['doiToken'] ?? '';

if (is_string($doiToken) && preg_match('/^[a-f0-9]{64}$/D', $doiToken) === 1) {
    $dbConfig = require __DIR__ . '/config/cuelens-signup.php';
    try {
        $pdo = registration_pdo_from_config(is_array($dbConfig) ? $dbConfig : []);
        if (confirm_direct_registration($pdo, hash('sha256', $doiToken))) {
            send_operational_notification(
                OPERATIONAL_EVENT_REGISTRATION_CREATED,
                'registration_confirmation'
            );
            $message = 'Sie haben sich erfolgreich an der Studie angemeldet. Folgen Sie der Anleitung für die <a href="download">App-Installation</a>.';
            $messageIsHtml = true;
        }
    } catch (Throwable $error) {
        http_response_code(500);
        $message = 'Beim Bestätigen der Anmeldung ist ein Fehler aufgetreten.';
        log_error_from_config(
            is_array($dbConfig) ? $dbConfig : [],
            $message,
            $error,
            'registration_confirmation'
        );
    }
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Anmeldung</title>
    <link rel="stylesheet" href="index.css">
</head>
<body>
<p class="success"><?php if ($messageIsHtml): ?><?= $message ?><?php else: ?><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?><?php endif; ?></p>
</body>
</html>
