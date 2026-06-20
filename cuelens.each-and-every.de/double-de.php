<?php
	session_start();
	
	$email = $_SESSION['email'] ?? '';
	unset($_SESSION['email']);
	if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
		$email = '';
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
<p>Um die Anmeldung abzuschließen, müssen Sie Ihre E-Mail-Adresse bestätigen. Es wurde eine E-Mail mit einem Bestätigungslink an <strong><?= htmlspecialchars($email, ENT_QUOTES, 'UTF-8') ?></strong>  gesendet. Bitte prüfen Sie auch Ihren Spam-Ordner.</p>
<p>Sollten Sie nach zehn Minuten noch keinen Bestätigungslink erhalten haben oder wenn andere technische Schwierigkeiten auftreten, können Sie sich jederzeit an die E-Mail-Adresse <a href="cuelens@each-and-every.de">cuelens@each-and-every.de</a> wenden.</p>
</body>
</html>
