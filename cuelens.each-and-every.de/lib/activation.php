<?php
declare(strict_types=1);

require_once __DIR__ . '/token-identity.php';

const ACTIVATION_VALIDITY_MINUTES = 5;

final class ActivationRejectedException extends RuntimeException
{
}

function normalize_activation_email(string $email): string
{
    return strtolower(trim($email));
}

function is_uuid_v4(string $value): bool
{
    return preg_match(
        '/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/D',
        strtolower($value)
    ) === 1;
}

function generate_activation_uuid_v4(): string
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);

    return sprintf(
        '%s-%s-%s-%s-%s',
        substr($hex, 0, 8),
        substr($hex, 8, 4),
        substr($hex, 12, 4),
        substr($hex, 16, 4),
        substr($hex, 20, 12)
    );
}

function activation_token_hash(string $secret, string $email, string $appToken): string
{
    if ($secret === '') {
        throw new RuntimeException('Missing activation secret.');
    }

    return hash_hmac(
        'sha256',
        "activation:v1\0" . normalize_activation_email($email) . "\0" . strtolower($appToken),
        $secret
    );
}

/**
 * @param null|callable(): string $tokenGenerator
 */
function request_activation_token(
    PDO $pdo,
    string $email,
    string $secret,
    ?callable $tokenGenerator = null
): string {
    $normalizedEmail = normalize_activation_email($email);
    $appToken = ($tokenGenerator ?? 'generate_activation_uuid_v4')();
    if (!is_uuid_v4($appToken)) {
        throw new RuntimeException('Token generator returned an invalid UUID-v4.');
    }
    $appToken = strtolower($appToken);
    $appTokenHash = activation_token_hash($secret, $normalizedEmail, $appToken);

    $pdo->beginTransaction();
    try {
        $registration = $pdo->prepare(
            'SELECT email
               FROM register
              WHERE email = :email
                AND doi = 1
                AND studyinfo = 1
                AND dataprot = 1
                AND app_token_issued_at IS NULL
              FOR UPDATE'
        );
        $registration->execute([':email' => $normalizedEmail]);
        if ($registration->fetchColumn() === false) {
            throw new ActivationRejectedException('Activation request rejected.');
        }

        $update = $pdo->prepare(
            'UPDATE register
                SET app_token_hash = :app_token_hash,
                    activation_valid_through = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ' .
                    ACTIVATION_VALIDITY_MINUTES . ' MINUTE)
              WHERE email = :email
                AND app_token_issued_at IS NULL'
        );
        $update->execute([
            ':app_token_hash' => $appTokenHash,
            ':email' => $normalizedEmail,
        ]);
        if ($update->rowCount() !== 1) {
            throw new RuntimeException('Activation pending state was not updated.');
        }

        $pdo->commit();
        return $appToken;
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $error;
    }
}

function confirm_activation_token(
    PDO $registrationPdo,
    PDO $cravingPdo,
    string $email,
    string $appToken,
    string $activationSecret,
    string $pseudonymSecret
): void {
    $normalizedEmail = normalize_activation_email($email);
    $normalizedToken = strtolower($appToken);
    if (!is_uuid_v4($normalizedToken)) {
        throw new ActivationRejectedException('Activation confirmation rejected.');
    }
    $candidateHash = activation_token_hash(
        $activationSecret,
        $normalizedEmail,
        $normalizedToken
    );
    $validTokenHash = valid_app_token_hash($pseudonymSecret, $normalizedToken);

    $registration = $registrationPdo->prepare(
        'SELECT app_token_hash,
                activation_valid_through > CURRENT_TIMESTAMP AS activation_is_valid
           FROM register
          WHERE email = :email
            AND doi = 1
            AND studyinfo = 1
            AND dataprot = 1
            AND app_token_issued_at IS NULL'
    );
    $registration->execute([':email' => $normalizedEmail]);
    $row = $registration->fetch(PDO::FETCH_ASSOC);
    if (
        !is_array($row) ||
        !is_string($row['app_token_hash'] ?? null) ||
        !hash_equals($row['app_token_hash'], $candidateHash) ||
        (int) ($row['activation_is_valid'] ?? 0) !== 1
    ) {
        throw new ActivationRejectedException('Activation confirmation rejected.');
    }

    $update = $registrationPdo->prepare(
        'UPDATE register
            SET app_token_hash = NULL,
                activation_valid_through = NULL,
                app_token_issued_at = CURRENT_TIMESTAMP
          WHERE email = :email
            AND app_token_hash = :app_token_hash
            AND activation_valid_through > CURRENT_TIMESTAMP
            AND doi = 1
            AND studyinfo = 1
            AND dataprot = 1
            AND app_token_issued_at IS NULL'
    );
    $update->execute([
        ':email' => $normalizedEmail,
        ':app_token_hash' => $candidateHash,
    ]);
    if ($update->rowCount() !== 1) {
        throw new RuntimeException('Activation confirmation was not stored.');
    }

    $allowlist = $cravingPdo->prepare(
        'INSERT INTO valid_app_token_hashes (hash) VALUES (:hash)'
    );
    $allowlist->execute([':hash' => $validTokenHash]);
}
