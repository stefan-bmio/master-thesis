<?php
declare(strict_types=1);

require_once __DIR__ . '/token-identity.php';
require_once __DIR__ . '/participant-identifier.php';
require_once __DIR__ . '/completion-mode.php';

const ACTIVATION_VALIDITY_MINUTES = 5;

final class ActivationRejectedException extends RuntimeException
{
}

function normalize_activation_email(string $email): string
{
    return strtolower(trim($email));
}

function activation_identifier(ParticipantIdentifier|string $identifier): ParticipantIdentifier
{
    return $identifier instanceof ParticipantIdentifier
        ? $identifier
        : ParticipantIdentifier::parse($identifier);
}

/**
 * Resolves the new identifier property and the legacy email alias without
 * permitting two different participant identifiers in one request.
 *
 * @param array<string, mixed> $payload
 */
function activation_identifier_from_payload(array $payload): ParticipantIdentifier
{
    $hasIdentifier = array_key_exists('identifier', $payload);
    $hasLegacyEmail = array_key_exists('email', $payload);
    if (!$hasIdentifier && !$hasLegacyEmail) {
        throw new InvalidArgumentException('Missing participant identifier.');
    }

    $parseProperty = static function (mixed $value): ParticipantIdentifier {
        if (!is_string($value)) {
            throw new InvalidArgumentException('Invalid participant identifier.');
        }
        return ParticipantIdentifier::parse($value);
    };

    $identifier = $hasIdentifier ? $parseProperty($payload['identifier']) : null;
    $legacyIdentifier = $hasLegacyEmail ? $parseProperty($payload['email']) : null;
    if (
        $identifier !== null &&
        $legacyIdentifier !== null &&
        (
            $identifier->channel() !== $legacyIdentifier->channel() ||
            $identifier->activationValue() !== $legacyIdentifier->activationValue()
        )
    ) {
        throw new InvalidArgumentException('Conflicting participant identifiers.');
    }

    if ($identifier !== null) {
        return $identifier;
    }
    if ($legacyIdentifier !== null) {
        return $legacyIdentifier;
    }

    throw new InvalidArgumentException('Missing participant identifier.');
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

function activation_token_hash_for_identifier(
    string $secret,
    ParticipantIdentifier $identifier,
    string $appToken
): string {
    if ($identifier->channel() === ParticipantIdentifier::DIRECT) {
        return activation_token_hash($secret, $identifier->activationValue(), $appToken);
    }
    if ($secret === '') {
        throw new RuntimeException('Missing activation secret.');
    }

    return hash_hmac(
        'sha256',
        "activation:prolific:v1\0" .
            $identifier->activationValue() .
            "\0" .
            strtolower($appToken),
        $secret
    );
}

function completion_mode_for_registration_channel(string $registrationChannel): string
{
    return match ($registrationChannel) {
        ParticipantIdentifier::DIRECT => COMPLETION_MODE_COMPENSATION_CODE,
        ParticipantIdentifier::PROLIFIC => COMPLETION_MODE_PROLIFIC_MANUAL,
        default => throw new RuntimeException('Unsupported registration channel.'),
    };
}

function activation_registration_identifier_column(ParticipantIdentifier $identifier): string
{
    return match ($identifier->channel()) {
        ParticipantIdentifier::DIRECT => 'email',
        ParticipantIdentifier::PROLIFIC => 'prolific_id',
        default => throw new RuntimeException('Unsupported registration channel.'),
    };
}

/**
 * @param null|callable(): string $tokenGenerator
 */
function request_activation_token(
    PDO $pdo,
    ParticipantIdentifier|string $identifier,
    string $secret,
    ?callable $tokenGenerator = null
): string {
    $participantIdentifier = activation_identifier($identifier);
    $normalizedIdentifier = $participantIdentifier->activationValue();
    $identifierColumn = activation_registration_identifier_column($participantIdentifier);
    $appToken = ($tokenGenerator ?? 'generate_activation_uuid_v4')();
    if (!is_uuid_v4($appToken)) {
        throw new RuntimeException('Token generator returned an invalid UUID-v4.');
    }
    $appToken = strtolower($appToken);
    $appTokenHash = activation_token_hash_for_identifier(
        $secret,
        $participantIdentifier,
        $appToken
    );

    $pdo->beginTransaction();
    try {
        $registration = $pdo->prepare(
            'SELECT registration_id, registration_channel
               FROM register
              WHERE registration_channel = :registration_channel
                AND ' . $identifierColumn . ' = :identifier
                AND registration_confirmed_at IS NOT NULL
                AND studyinfo = 1
                AND app_token_issued_at IS NULL
              FOR UPDATE'
        );
        $registration->execute([
            ':registration_channel' => $participantIdentifier->channel(),
            ':identifier' => $normalizedIdentifier,
        ]);
        $registrationRow = $registration->fetch(PDO::FETCH_ASSOC);
        if (!is_array($registrationRow) || !isset($registrationRow['registration_id'])) {
            throw new ActivationRejectedException('Activation request rejected.');
        }

        $update = $pdo->prepare(
            'UPDATE register
                SET app_token_hash = :app_token_hash,
                    activation_valid_through = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ' .
                    ACTIVATION_VALIDITY_MINUTES . ' MINUTE)
              WHERE registration_id = :registration_id
                AND app_token_issued_at IS NULL'
        );
        $update->execute([
            ':app_token_hash' => $appTokenHash,
            ':registration_id' => $registrationRow['registration_id'],
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
    ParticipantIdentifier|string $identifier,
    string $appToken,
    string $activationSecret,
    string $pseudonymSecret
): void {
    $participantIdentifier = activation_identifier($identifier);
    $normalizedIdentifier = $participantIdentifier->activationValue();
    $identifierColumn = activation_registration_identifier_column($participantIdentifier);
    $normalizedToken = strtolower($appToken);
    if (!is_uuid_v4($normalizedToken)) {
        throw new ActivationRejectedException('Activation confirmation rejected.');
    }
    $candidateHash = activation_token_hash_for_identifier(
        $activationSecret,
        $participantIdentifier,
        $normalizedToken
    );
    $validTokenHash = valid_app_token_hash($pseudonymSecret, $normalizedToken);
    $registrationTokenHash = registration_token_hash($pseudonymSecret, $normalizedToken);

    $registration = $registrationPdo->prepare(
        'SELECT registration_id,
                registration_channel,
                app_token_hash,
                activation_valid_through > CURRENT_TIMESTAMP AS activation_is_valid
           FROM register
          WHERE registration_channel = :registration_channel
            AND ' . $identifierColumn . ' = :identifier
            AND registration_confirmed_at IS NOT NULL
            AND studyinfo = 1
            AND app_token_issued_at IS NULL'
    );
    $registration->execute([
        ':registration_channel' => $participantIdentifier->channel(),
        ':identifier' => $normalizedIdentifier,
    ]);
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
                app_token_issued_at = CURRENT_TIMESTAMP,
                registration_token_hash = :registration_token_hash
          WHERE registration_id = :registration_id
            AND app_token_hash = :app_token_hash
            AND activation_valid_through > CURRENT_TIMESTAMP
            AND registration_confirmed_at IS NOT NULL
            AND studyinfo = 1
            AND app_token_issued_at IS NULL'
    );
    $update->execute([
        ':registration_token_hash' => $registrationTokenHash,
        ':registration_id' => $row['registration_id'],
        ':app_token_hash' => $candidateHash,
    ]);
    if ($update->rowCount() !== 1) {
        throw new RuntimeException('Activation confirmation was not stored.');
    }

    $allowlist = $cravingPdo->prepare(
        'INSERT INTO valid_app_token_hashes (hash, completion_mode)
         VALUES (:hash, :completion_mode)'
    );
    $allowlist->execute([
        ':hash' => $validTokenHash,
        ':completion_mode' => completion_mode_for_registration_channel(
            (string) $row['registration_channel']
        ),
    ]);
}
