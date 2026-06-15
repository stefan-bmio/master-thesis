<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require __DIR__ . '/lib/PHPMailer/Exception.php';
require __DIR__ . '/lib/PHPMailer/PHPMailer.php';
require __DIR__ . '/lib/PHPMailer/SMTP.php';

$dbConfig = require __DIR__ . '/config/cuelens-signup.php';
$smtpConfig = require __DIR__ . '/config/noreply-smtp.php';

$message = '';

session_start();

$csrfToken = $_POST['csrf_token'] ?? '';

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
} catch (PDOException $e) {
	http_response_code(500);
	echo json_encode([
		'success' => false,
		'error' => 'Database error.'
	]);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	$csrfToken = $_POST['csrf_token'] ?? '';
	
	if (
		empty($_SESSION['csrf_token']) ||
		!hash_equals($_SESSION['csrf_token'], $csrfToken)
	) {
		$message = 'Die Anfrage konnte nicht verarbeitet werden. Bitte laden Sie das Formular neu.';
	} else {
		if (
			empty($_SESSION['csrf_token']) ||
			!hash_equals($_SESSION['csrf_token'], $csrfToken)
		) {
			$message = 'Die Anfrage konnte nicht verarbeitet werden. Bitte laden Sie das Formular neu.';
		} else {
			$email = trim($_POST['email'] ?? '');
			$email = filter_var($email, FILTER_VALIDATE_EMAIL);
			$name = trim($_POST['name'] ?? '');
			$iban = trim($_POST['iban'] ?? '');
			$bic = trim($_POST['bic'] ?? '');
			$age = filter_input(INPUT_POST, 'age', FILTER_VALIDATE_INT);
			$cigarettes = filter_input(INPUT_POST, 'cigarettes', FILTER_VALIDATE_INT);	
			$studyinfoAccepted = isset($_POST['studyinfo']);
			$dataprotAccepted = isset($_POST['dataprot']);

			if (
				empty($email) ||
				$email === false ||
				empty($name) ||
				empty($iban) ||
				empty($bic) ||
				$age === false ||
				$cigarettes === false ||
				$age < 30 || $age > 65 ||
				$cigarettes < 10 ||
				$studyinfoAccepted === false ||
				$dataprotAccepted === false
			) {
				$message = 'Bitte nutzen Sie das Webformular';
			} else {
				$csrfToken = $_POST['csrf_token'] ?? '';
				if (
					empty($_SESSION['csrf_token']) ||
					!hash_equals($_SESSION['csrf_token'], $csrfToken)
				) {
					$message = 'Die Anfrage konnte nicht verarbeitet werden. Bitte laden Sie das Formular neu.';
				} else {
					$doiToken = bin2hex(random_bytes(32));
					$doiTokenHash = hash('sha256', $doiToken);
					
					try {
						$stmt = $pdo->prepare("
							INSERT INTO `register`
							(`email`, `name`, `iban`, `bic`, `age`, `cigarettes`, `doi_token`, `studyinfo`, `dataprot`)
							VALUES
							(:email, :name, :iban, :bic, :age, :cigarettes, :doiToken, :studyinfo, :dataprot)
						");

						$stmt->execute([
							':email' => $email,
							':name' => $name,
							':iban' => $iban,
							':bic' => $bic,
							':age' => $age,
							':cigarettes' => $cigarettes,
							':doiToken' => $doiTokenHash,
							':studyinfo' => $studyinfoAccepted,
							':dataprot' => $dataprotAccepted,
						]);
						
						try {
							$confirmUrl = 'https://cuelens.each-and-every.de/confirm.php?' . http_build_query([
								'doiToken' => $doiToken,
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
							$mail->Subject = $smtpConfig['subject'];
							$mail->addAddress($email, $name);

							$mail->Body =
								"Guten Tag,\n\n"
								. "vielen Dank für Ihr Interesse an der CueLens-Studie.\n\n"
								. "Bitte bestätigen Sie Ihre E-Mail-Adresse über den folgenden Link:\n\n"
								. $confirmUrl . "\n\n"
								. "Falls Sie sich nicht zur CueLens-Studie angemeldet haben, können Sie diese E-Mail ignorieren.\n\n"
								. "Mit freundlichen Grüßen";

							$mail->send();

							$_SESSION['email'] = $email;
							$_SESSION['csrf_token'] = bin2hex(random_bytes(32));
							header('Location: double.php');
							exit;
						} catch (Exception $e) {
							error_log('PHPMailer: ' . $mail->ErrorInfo);
							$message = 'Die Bestätigungs-E-Mail konnte nicht versendet werden.';
						} catch (Throwable $e) {
							error_log('Double-Opt-In: ' . $e->getMessage());
							$message = 'Beim Vorbereiten der Bestätigungs-E-Mail ist ein Fehler aufgetreten.';
						}

					} catch (PDOException $e) {
						if ($e->errorInfo[1] == 1062) {
							$message = 'Diese E-Mail-Adresse ist bereits registriert.';
						} else {
							$message = 'Beim Speichern ist ein Fehler aufgetreten.';
						}
					}
				}
			}
		}
	}
} else {
	if (empty($_SESSION['csrf_token'])) {
		$_SESSION['csrf_token'] = bin2hex(random_bytes(32));
	}
}

?>

<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <title>Anmeldung</title>
	
	<link rel="stylesheet" href="index.css">
</head>
<body>

<h1>Anmeldung zur CueLens-Studie</h1>
<p>Vielen Dank für Ihr Interesse an der Teilnahme. Bitte lesen Sie die <a href="/info">Studieninformation</a>.</p>

<p>Wir benötigen diese Angaben über Sie:</p>

<form method="post" action="">
<table>
<tr>
    <td><label for="email">E-Mail:</label></td>
    <td><input type="email" id="email" name="email" required></td>
</tr>
<tr>
    <td><label for="name">Name:</label></td>
    <td><input type="text" id="name" name="name" required></td>
</tr>
<tr>
    <td><label for="iban">IBAN:</label></td>
    <td><input type="text" id="iban" name="iban" maxlength="34" required></td>
</tr>
<tr>
    <td><label for="bic">BIC:</label></td>
    <td><input type="text" id="bic" name="bic" maxlength="11" required></td>
</tr>
<tr>
    <td><label for="age">Alter:</label></td>
    <td><input type="number" id="age" name="age" min="30" max="65" step="1" required></td>
</tr>
<tr>
    <td><label for="cigarettes">Zigaretten/Tag:</label></td>
    <td><input type="number" id="cigarettes" name="cigarettes" min="10" step="1" required></td>
</tr>
</table>
<table>
<tr>
    <td><input type="checkbox" id="studyinfo" name="studyinfo" required></td>
    <td><label for="studyinfo">Ich habe die <a href="/info">Studieninformation</a> gelesen</label></td>
</tr>
<tr>
    <td><input type="checkbox" id="dataprot" name="dataprot" required></td>
    <td><label for="dataprot">Ich akzeptiere die <a href="/ds">Datenschutzerklärung</a></label></td>
</tr>
<input
    type="hidden"
    name="csrf_token"
    value="<?= htmlspecialchars($_SESSION['csrf_token'], ENT_QUOTES, 'UTF-8') ?>"
>
</table>
<p><button type="submit">Absenden</button></p>
</form>

<?php if (!empty($message)): ?>
    <p class="error"><?php echo htmlspecialchars($message, ENT_QUOTES, 'UTF-8'); ?></p>
<?php endif; ?>

</body>
<script src="index.js"></script>
</html>