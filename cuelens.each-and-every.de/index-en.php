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
		$message = 'The request could not be processed. Please reload the form.';
	} else {
		if (
			empty($_SESSION['csrf_token']) ||
			!hash_equals($_SESSION['csrf_token'], $csrfToken)
		) {
			$message = 'The request could not be processed. Please reload the form.';
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
				$message = 'Please use the web form';
			} else {
				$csrfToken = $_POST['csrf_token'] ?? '';
				if (
					empty($_SESSION['csrf_token']) ||
					!hash_equals($_SESSION['csrf_token'], $csrfToken)
				) {
					$message = 'The request could not be processed. Please reload the form.';
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
							$confirmUrl = 'https://cuelens.each-and-every.de/confirm-en.php?' . http_build_query([
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
							$mail->addAddress($email, $name);

							$mail->Subject = 'Please confirm your registration for the CueLens study';
							$mail->Body =
								"Hello,\n\n"
								. "Thank you for your interest in the CueLens study.\n\n"
								. "Please confirm your email address by clicking the following link:\n\n"
								. $confirmUrl . "\n\n"
								. "If you did not register for the CueLens study, you can ignore this email.\n\n"
								. "Kind regards";

							$mail->send();

							$_SESSION['email'] = $email;
							$_SESSION['csrf_token'] = bin2hex(random_bytes(32));
							header('Location: double-en.php');
							exit;
						} catch (Exception $e) {
							error_log('PHPMailer: ' . $mail->ErrorInfo);
							$message = 'The confirmation email could not be sent.';
						} catch (Throwable $e) {
							error_log('Double-Opt-In: ' . $e->getMessage());
							$message = 'An error occured when preparing the confirmation email.';
						}

					} catch (PDOException $e) {
						if ($e->errorInfo[1] == 1062) {
							$message = 'This email address is already registered.';
						} else {
							$message = 'An error occured when saving.';
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
    <title>Registration</title>
	
	<link rel="stylesheet" href="index.css">
</head>
<body>

<h1>CueLens-Study Registration</h1>
<p>Thank you for your interest in participating. Please read the <a href="/studyinformation.pdf">study information</a>.</p>

<p>We need the following information from you::</p>

<form method="post" action="">
<table>
<tr>
    <td><label for="email">Email:</label></td>
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
    <td><label for="age">Age:</label></td>
    <td><input type="number" id="age" name="age" min="30" max="65" step="1" required></td>
</tr>
<tr>
    <td><label for="cigarettes">Cigarettes/day:</label></td>
    <td><input type="number" id="cigarettes" name="cigarettes" min="10" step="1" required></td>
</tr>
</table>
<table>
<tr>
    <td><input type="checkbox" id="studyinfo" name="studyinfo" required></td>
    <td><label for="studyinfo">I have read the <a href="/studyinformation.pdf">study information</a></label></td>
</tr>
<tr>
    <td><input type="checkbox" id="dataprot" name="dataprot" required></td>
    <td><label for="dataprot">I accept the <a href="/privacypolicy.pdf">privacy policy</a></label></td>
</tr>
<input
    type="hidden"
    name="csrf_token"
    value="<?= htmlspecialchars($_SESSION['csrf_token'], ENT_QUOTES, 'UTF-8') ?>"
>
</table>
<p><button type="submit">Submit</button></p>
</form>

<?php if (!empty($message)): ?>
    <p class="error"><?php echo htmlspecialchars($message, ENT_QUOTES, 'UTF-8'); ?></p>
<?php endif; ?>

</body>
<script src="index.js"></script>
</html>