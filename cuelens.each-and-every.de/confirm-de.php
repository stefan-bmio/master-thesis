<?php
$dbConfig = require __DIR__ . '/config/cuelens-signup.php';

$message = '';

$doiToken = $_GET['doiToken'] ?? '';

if (!is_string($doiToken) || !preg_match('/^[a-f0-9]{64}$/', $doiToken)) {
	$message = "Dieser Bestätigungslink ist nicht gültig.";
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
			$message = 'Dieser Bestätigungslink ist nicht gültig.';
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
			
			$message = 'Sie haben sich erfolgreich an der Studie angemeldet. Vielen Dank. In den nächsten Tagen benachrichtigen wir Sie über den Beginn.';
		}		
	} catch (PDOException $e) {
		http_response_code(500);
		echo json_encode([
			'success' => false,
			'error' => $e
		]);
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
<p class="success"><?= $message ?></p>
</body>
</html>