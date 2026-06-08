<?php
$config = require __DIR__ . '/config/db.php';
$message = '';

try {
    $pdo = new PDO(
    "mysql:host={$config['host']};dbname={$config['dbname']};charset=utf8mb4",
    $config['user'],
    $config['pass'],
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
);
} catch (PDOException $e) {
    die('Datenbankverbindung fehlgeschlagen.');
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $name = trim($_POST['name'] ?? '');
    $iban = trim($_POST['iban'] ?? '');
    $bic = trim($_POST['bic'] ?? '');
    $age = filter_input(INPUT_POST, 'age', FILTER_VALIDATE_INT);
    $cigarettes = filter_input(INPUT_POST, 'cigarettes', FILTER_VALIDATE_INT);

    if (
        empty($email) ||
        empty($name) ||
        empty($iban) ||
        empty($bic) ||
        $age === false ||
        $cigarettes === false
    ) {
        $message = 'Bitte alle Felder korrekt ausfüllen.';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $message = 'Bitte eine gültige E-Mail-Adresse eingeben.';
    } else {
        try {
            $stmt = $pdo->prepare("
                INSERT INTO `register`
                (`email`, `name`, `iban`, `bic`, `age`, `cigarettes`)
                VALUES
                (:email, :name, :iban, :bic, :age, :cigarettes)
            ");

            $stmt->execute([
                ':email' => $email,
                ':name' => $name,
                ':iban' => $iban,
                ':bic' => $bic,
                ':age' => $age,
                ':cigarettes' => $cigarettes
            ]);

            $message = 'Registrierung erfolgreich gespeichert.';
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                $message = 'Diese E-Mail-Adresse ist bereits registriert.';
            } else {
                $message = 'Beim Speichern ist ein Fehler aufgetreten.';
            }
        }
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

<?php if (!empty($message)): ?>
    <p><?php echo htmlspecialchars($message, ENT_QUOTES, 'UTF-8'); ?></p>
<?php endif; ?>

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
    <td><input type="number" id="age" name="age" min="0" required></td>
</tr>
<tr>
    <td><label for="cigarettes">Zigaretten/Tag:</label></td>
    <td><input type="number" id="cigarettes" name="cigarettes" min="0" step="1" required></td>
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
</table>
<p><button type="submit">Absenden</button></p>
</form>

</body>
</html>