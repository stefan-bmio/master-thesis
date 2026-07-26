<?php
declare(strict_types=1);

require_once __DIR__ . '/token-identity.php';

final class DataProtectionAuthenticationException extends RuntimeException
{
}

function data_protection_app_token(array $payload): ?string
{
    $value = $payload['app_token'] ?? null;
    if (!is_string($value)) {
        return null;
    }
    $token = strtolower(trim($value));
    if (
        preg_match(
            '/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/D',
            $token
        ) !== 1
    ) {
        return null;
    }
    return $token;
}

function data_protection_status(PDO $pdo, string $secret, string $appToken): bool
{
    $stmt = $pdo->prepare(
        'SELECT dataprot
           FROM register
          WHERE registration_token_hash = :registration_token_hash'
    );
    $stmt->execute([
        ':registration_token_hash' => registration_token_hash($secret, $appToken),
    ]);
    $value = $stmt->fetchColumn();
    if ($value === false) {
        throw new DataProtectionAuthenticationException('Unknown app token.');
    }
    return (int) $value === 1;
}

function accept_data_protection(
    PDO $pdo,
    string $secret,
    string $appToken
): void {
    $hash = registration_token_hash($secret, $appToken);
    $update = $pdo->prepare(
        'UPDATE register
            SET dataprot = 1,
                dataprot_accepted_at = COALESCE(dataprot_accepted_at, UTC_TIMESTAMP())
          WHERE registration_token_hash = :registration_token_hash'
    );
    $update->execute([':registration_token_hash' => $hash]);

    $check = $pdo->prepare(
        'SELECT dataprot
           FROM register
          WHERE registration_token_hash = :registration_token_hash'
    );
    $check->execute([':registration_token_hash' => $hash]);
    if ((int) $check->fetchColumn() !== 1) {
        throw new DataProtectionAuthenticationException('Unknown app token.');
    }
}
