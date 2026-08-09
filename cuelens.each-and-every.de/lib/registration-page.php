<?php
declare(strict_types=1);

use PHPMailer\PHPMailer\PHPMailer;

require_once __DIR__ . '/PHPMailer/Exception.php';
require_once __DIR__ . '/PHPMailer/PHPMailer.php';
require_once __DIR__ . '/PHPMailer/SMTP.php';
require_once __DIR__ . '/error-log.php';
require_once __DIR__ . '/registration.php';

if (!isset($registrationPage) || !is_array($registrationPage)) {
    throw new RuntimeException('Missing registration page configuration.');
}

$message = '';
session_start();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrfToken = $_POST['csrf_token'] ?? '';
    if (!is_string($csrfToken) || empty($_SESSION['csrf_token']) ||
        !hash_equals($_SESSION['csrf_token'], $csrfToken)) {
        $message = $registrationPage['csrf_error'];
    } else {
        $validation = validate_registration_submission($_POST);
        if (!$validation->isValid()) {
            $message = $registrationPage['validation_error'];
        } else {
            $submission = $validation->submission();
            $dbConfig = require __DIR__ . '/../config/cuelens-signup.php';
            try {
                $pdo = registration_pdo_from_config(is_array($dbConfig) ? $dbConfig : []);
                $creation = create_registration($pdo, $submission);

                if ($creation->channel() === ParticipantIdentifier::PROLIFIC) {
                    send_operational_notification(
                        OPERATIONAL_EVENT_PROLIFIC_REGISTRATION_CREATED,
                        'registration_form'
                    );
                    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
                    header('Location: ' . $registrationPage['prolific_success_path']);
                    exit;
                }

                $email = $submission->identifier()->email();
                $name = $submission->name();
                $doubleOptInToken = $creation->doubleOptInToken();
                if ($email === null || $name === null || $doubleOptInToken === null) {
                    throw new RuntimeException('Incomplete direct registration result.');
                }

                $smtpConfig = require __DIR__ . '/../config/noreply-smtp.php';
                $hostConfig = require __DIR__ . '/../config/host.php';
                $confirmUrl = $hostConfig['root'] . '/' . $registrationPage['confirm_path'] . '?' . http_build_query([
                    'doiToken' => $doubleOptInToken,
                ]);
                $mail = new PHPMailer(true);
                $mail->isSMTP();
                $mail->Host = $smtpConfig['host'];
                $mail->SMTPAuth = $smtpConfig['smtpAuth'];
                $mail->Username = $smtpConfig['user'];
                $mail->Password = $smtpConfig['pass'];
                $mail->SMTPSecure = $smtpConfig['smtpSecure'];
                $mail->Port = $smtpConfig['port'];
                $mail->CharSet = $smtpConfig['charset'];
                $mail->setFrom($smtpConfig['from'], $smtpConfig['fromName']);
                $mail->addReplyTo($smtpConfig['replyTo'], $smtpConfig['replyToName']);
                $mail->addAddress($email, $name);
                $mail->Subject = $registrationPage['mail_subject'];
                $mail->Body = ($registrationPage['mail_body'])($confirmUrl);
                $mail->send();

                $_SESSION['email'] = $email;
                $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
                header('Location: ' . $registrationPage['double_opt_in_path']);
                exit;
            } catch (DuplicateRegistrationException $error) {
                $message = $error->channel() === ParticipantIdentifier::PROLIFIC
                    ? $registrationPage['duplicate_prolific']
                    : $registrationPage['duplicate_direct'];
            } catch (Throwable $error) {
                $message = $error instanceof \PHPMailer\PHPMailer\Exception
                    ? $registrationPage['mail_error']
                    : $registrationPage['save_error'];
                if (isset($pdo) && $pdo instanceof PDO) {
                    log_error($pdo, $message, $error, 'registration_form');
                } elseif (isset($dbConfig) && is_array($dbConfig)) {
                    log_error_from_config($dbConfig, $message, $error, 'registration_form');
                }
            }
        }
    }
}
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
?>
<!DOCTYPE html>
<html lang="<?= htmlspecialchars($registrationPage['language'], ENT_QUOTES, 'UTF-8') ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= htmlspecialchars($registrationPage['page_title'], ENT_QUOTES, 'UTF-8') ?></title>
    <link rel="stylesheet" href="index.css">
</head>
<body>
<h1><?= htmlspecialchars($registrationPage['heading'], ENT_QUOTES, 'UTF-8') ?></h1>
<p><?= htmlspecialchars($registrationPage['introduction'], ENT_QUOTES, 'UTF-8') ?>
    <a href="<?= htmlspecialchars($registrationPage['study_information_url'], ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars($registrationPage['study_information_label'], ENT_QUOTES, 'UTF-8') ?></a>.
</p>
<p><?= htmlspecialchars($registrationPage['details_intro'], ENT_QUOTES, 'UTF-8') ?></p>
<form method="post" action="" data-registration-mode="invalid">
<table class="form-fields">
<tr>
    <td><label for="email"><?= htmlspecialchars($registrationPage['identifier_label'], ENT_QUOTES, 'UTF-8') ?>:</label></td>
    <td><input type="text" id="email" name="participant_identifier" required autocomplete="off" spellcheck="false" autocapitalize="none" aria-describedby="identifier-help registration-mode-help" data-validation-required="<?= htmlspecialchars($registrationPage['identifier_required'], ENT_QUOTES, 'UTF-8') ?>" data-validation-invalid="<?= htmlspecialchars($registrationPage['identifier_invalid'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
<tr>
    <td></td>
    <td><p id="identifier-help"><?= htmlspecialchars($registrationPage['identifier_help'], ENT_QUOTES, 'UTF-8') ?></p><p id="registration-mode-help" role="status" aria-live="polite" hidden><?= htmlspecialchars($registrationPage['prolific_mode_help'], ENT_QUOTES, 'UTF-8') ?></p></td>
</tr>
<tr>
    <td><label for="name"><?= htmlspecialchars($registrationPage['name_label'], ENT_QUOTES, 'UTF-8') ?>:</label></td>
    <td><input type="text" id="name" name="name" required data-validation-required="<?= htmlspecialchars($registrationPage['name_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
<tr>
    <td><label for="iban">IBAN:</label></td>
    <td><input type="text" id="iban" name="iban" maxlength="34" required data-validation-required="<?= htmlspecialchars($registrationPage['iban_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
<tr>
    <td><label for="bic">BIC:</label></td>
    <td><input type="text" id="bic" name="bic" maxlength="11" required data-validation-required="<?= htmlspecialchars($registrationPage['bic_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
<tr>
    <td><label for="age"><?= htmlspecialchars($registrationPage['age_label'], ENT_QUOTES, 'UTF-8') ?>:</label></td>
    <td><input type="number" id="age" name="age" min="30" max="65" step="1" required data-validation-required="<?= htmlspecialchars($registrationPage['age_required'], ENT_QUOTES, 'UTF-8') ?>" data-validation-range="<?= htmlspecialchars($registrationPage['age_range'], ENT_QUOTES, 'UTF-8') ?>" data-validation-step="<?= htmlspecialchars($registrationPage['integer_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
<tr>
    <td><label for="cigarettes"><?= htmlspecialchars($registrationPage['cigarettes_label'], ENT_QUOTES, 'UTF-8') ?>:</label></td>
    <td><input type="number" id="cigarettes" name="cigarettes" min="10" step="1" required data-validation-required="<?= htmlspecialchars($registrationPage['cigarettes_required'], ENT_QUOTES, 'UTF-8') ?>" data-validation-range="<?= htmlspecialchars($registrationPage['cigarettes_range'], ENT_QUOTES, 'UTF-8') ?>" data-validation-step="<?= htmlspecialchars($registrationPage['integer_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
</tr>
</table>
<table class="agreements">
<tr>
    <td><input type="checkbox" id="studyinfo" name="studyinfo" required data-validation-required="<?= htmlspecialchars($registrationPage['studyinfo_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
    <td><label for="studyinfo"><?= htmlspecialchars($registrationPage['studyinfo_prefix'], ENT_QUOTES, 'UTF-8') ?> <a href="<?= htmlspecialchars($registrationPage['study_information_url'], ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars($registrationPage['study_information_label'], ENT_QUOTES, 'UTF-8') ?></a> <?= htmlspecialchars($registrationPage['studyinfo_suffix'], ENT_QUOTES, 'UTF-8') ?></label></td>
</tr>
<tr>
    <td><input type="checkbox" id="dataprot" name="dataprot" required data-validation-required="<?= htmlspecialchars($registrationPage['dataprot_required'], ENT_QUOTES, 'UTF-8') ?>"></td>
    <td><label for="dataprot"><?= htmlspecialchars($registrationPage['dataprot_prefix'], ENT_QUOTES, 'UTF-8') ?> <a href="<?= htmlspecialchars($registrationPage['privacy_url'], ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars($registrationPage['privacy_label'], ENT_QUOTES, 'UTF-8') ?></a></label></td>
</tr>
</table>
<input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token'], ENT_QUOTES, 'UTF-8') ?>">
<p id="form-validation-message" class="error form-validation-message" role="alert" hidden></p>
<p><button type="submit"><?= htmlspecialchars($registrationPage['submit_label'], ENT_QUOTES, 'UTF-8') ?></button></p>
</form>
<?php if ($message !== ''): ?>
    <p class="error"><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?></p>
<?php endif; ?>
</body>
<script src="index.js"></script>
</html>
