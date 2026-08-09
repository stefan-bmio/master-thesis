<?php
declare(strict_types=1);

require __DIR__ . '/lib/error-log.php';
require __DIR__ . '/lib/registration.php';

$message = 'This confirmation link is not valid.';
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
            $message = 'You have successfully registered for the study. Follow the instructions for <a href="download">installing the app</a>.';
            $messageIsHtml = true;
        }
    } catch (Throwable $error) {
        http_response_code(500);
        $message = 'An error occurred while confirming the registration.';
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
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Registration</title>
    <link rel="stylesheet" href="index.css">
</head>
<body>
<p class="success"><?php if ($messageIsHtml): ?><?= $message ?><?php else: ?><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?><?php endif; ?></p>
</body>
</html>
