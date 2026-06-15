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
    <title>Registration</title>
	
	<link rel="stylesheet" href="index.css">
</head>
<body>
<p>
    To complete your registration, you need to confirm your email address.
    An email with a confirmation link has been sent to <strong><?= htmlspecialchars($email, ENT_QUOTES, 'UTF-8') ?></strong>.
    Please also check your spam folder.
</p>

<p>
    If you have not received a confirmation link after ten minutes, or if you experience any other technical difficulties, you can contact us at any time at
    <a href="mailto:cuelens@each-and-every.de">cuelens@each-and-every.de</a>.
</p>
</body>
</html>