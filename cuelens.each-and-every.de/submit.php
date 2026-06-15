<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Method not allowed. Use POST.'
    ]);
    exit;
}

if (!isset($_POST['craving'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Missing parameter: craving'
    ]);
    exit;
}

$craving = filter_var($_POST['craving'], FILTER_VALIDATE_INT);

if ($craving === false) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Parameter craving must be an integer.'
    ]);
    exit;
}

// Optional, aber für eine Craving-Skala von 0 bis 100 fachlich sinnvoll:
if ($craving < 0 || $craving > 100) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Parameter craving must be between 0 and 100.'
    ]);
    exit;
}

$config = require __DIR__ . '/config/cuelens-craving.php';
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

    $stmt = $pdo->prepare(
        'INSERT INTO self_reports (craving) VALUES (:craving)'
    );

    $stmt->bindValue(':craving', $craving, PDO::PARAM_INT);
    $stmt->execute();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'id' => $pdo->lastInsertId()
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Database error.'
    ]);
}