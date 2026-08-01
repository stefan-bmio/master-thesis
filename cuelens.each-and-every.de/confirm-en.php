<?php
require __DIR__ . '/lib/error-log.php';

$dbConfig = require __DIR__ . '/config/cuelens-signup.php';

$message = '';

$doiToken = $_GET['doiToken'] ?? '';

if (!is_string($doiToken) || !preg_match('/^[a-f0-9]{64}$/', $doiToken)) {
	$message = "This confirmation link is not valid.";
} else {
	$doiTokenHash = hash('sha256', $doiToken);

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
		
		$pdo->beginTransaction();

		$stmt = $pdo->prepare("
			SELECT email
			FROM register
			WHERE doi_token = :doiTokenHash
			  AND doi = 0
			LIMIT 1
			FOR UPDATE
		");
		
		$stmt->execute([
			':doiTokenHash' => $doiTokenHash,
		]);
		$pending = $stmt->fetch();
		
		if (!$pending){
			$message = 'This confirmation link is not valid.';
		} else {
			$stmt = $pdo->prepare("
			UPDATE register 
			SET doi = 1
			WHERE email = :email
			");
			
			$stmt->execute([
				":email" => $pending['email']
			]);
			
			$pdo->commit();
			send_operational_notification(
				OPERATIONAL_EVENT_REGISTRATION_CREATED,
				'registration_confirmation'
			);
			
			$message = 'You have successfully registered for the study. Follow the instructions for the <a href="download">app installation</a>.';
		}
	} catch (PDOException $e) {
		if (isset($pdo) && $pdo->inTransaction()) {
			$pdo->rollBack();
		}
		http_response_code(500);
		$message = 'An error occured when confirming the registration.';
		log_error_from_config($dbConfig, $message, $e, 'registration_confirmation');
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
<p class="success"><?= $message ?></p>
</body>
</html>
