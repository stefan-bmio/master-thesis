<?php
declare(strict_types=1);

require_once __DIR__ . '/participant-identifier.php';

final class RegistrationSubmission
{
    public function __construct(
        private readonly ParticipantIdentifier $identifier,
        private readonly ?string $name,
        private readonly ?string $iban,
        private readonly ?string $bic,
        private readonly int $age,
        private readonly int $cigarettes
    ) {
    }

    public function identifier(): ParticipantIdentifier
    {
        return $this->identifier;
    }

    public function name(): ?string
    {
        return $this->name;
    }

    public function iban(): ?string
    {
        return $this->iban;
    }

    public function bic(): ?string
    {
        return $this->bic;
    }

    public function age(): int
    {
        return $this->age;
    }

    public function cigarettes(): int
    {
        return $this->cigarettes;
    }
}

final class RegistrationValidationResult
{
    /** @param list<string> $errors */
    public function __construct(
        private readonly array $errors,
        private readonly ?RegistrationSubmission $submission
    ) {
    }

    public function isValid(): bool
    {
        return $this->errors === [] && $this->submission !== null;
    }

    /** @return list<string> */
    public function errors(): array
    {
        return $this->errors;
    }

    public function submission(): RegistrationSubmission
    {
        if (!$this->isValid()) {
            throw new LogicException('Invalid registration has no submission.');
        }
        return $this->submission;
    }
}

final class RegistrationCreation
{
    public function __construct(
        private readonly string $channel,
        private readonly ?string $doubleOptInToken
    ) {
    }

    public function channel(): string
    {
        return $this->channel;
    }

    public function doubleOptInToken(): ?string
    {
        return $this->doubleOptInToken;
    }
}

final class DuplicateRegistrationException extends RuntimeException
{
    public function __construct(private readonly string $channel, ?Throwable $previous = null)
    {
        parent::__construct('Registration already exists.', 0, $previous);
    }

    public function channel(): string
    {
        return $this->channel;
    }
}

/** @param array<string, mixed> $post */
function validate_registration_submission(array $post): RegistrationValidationResult
{
    $errors = [];
    $identifier = registration_identifier_from_post($post);
    if ($identifier === null) {
        $errors[] = 'identifier';
    }

    $isProlific = $identifier?->channel() === ParticipantIdentifier::PROLIFIC;
    $name = registration_trimmed_string($post['name'] ?? null);
    $iban = registration_trimmed_string($post['iban'] ?? null);
    $bic = registration_trimmed_string($post['bic'] ?? null);
    if ($isProlific) {
        $name = null;
        $iban = null;
        $bic = null;
    } else {
        if ($name === null) {
            $errors[] = 'name';
        }
        if ($iban === null) {
            $errors[] = 'iban';
        }
        if ($bic === null) {
            $errors[] = 'bic';
        }
    }

    $age = registration_integer($post['age'] ?? null);
    if ($age === null || $age < 30 || $age > 65) {
        $errors[] = 'age';
    }
    $cigarettes = registration_integer($post['cigarettes'] ?? null);
    if ($cigarettes === null || $cigarettes < 10) {
        $errors[] = 'cigarettes';
    }
    if (!isset($post['studyinfo'])) {
        $errors[] = 'studyinfo';
    }
    if (!isset($post['dataprot'])) {
        $errors[] = 'dataprot';
    }

    $errors = array_values(array_unique($errors));
    if ($errors !== [] || $identifier === null || $age === null || $cigarettes === null) {
        return new RegistrationValidationResult($errors, null);
    }

    return new RegistrationValidationResult(
        [],
        new RegistrationSubmission($identifier, $name, $iban, $bic, $age, $cigarettes)
    );
}

/** @param array<string, mixed> $post */
function registration_identifier_from_post(array $post): ?ParticipantIdentifier
{
    $primaryPresent = array_key_exists('participant_identifier', $post);
    $legacyPresent = array_key_exists('email', $post);
    if (($primaryPresent && !is_string($post['participant_identifier'])) ||
        ($legacyPresent && !is_string($post['email']))) {
        return null;
    }

    $primaryValue = $primaryPresent ? trim((string) $post['participant_identifier']) : '';
    $legacyValue = $legacyPresent ? trim((string) $post['email']) : '';
    $candidate = $primaryValue !== '' ? $primaryValue : $legacyValue;
    if ($candidate === '') {
        return null;
    }

    try {
        $identifier = ParticipantIdentifier::parse($candidate);
        if ($primaryValue !== '' && $legacyValue !== '') {
            $legacyIdentifier = ParticipantIdentifier::parse($legacyValue);
            if ($identifier->channel() !== $legacyIdentifier->channel() ||
                $identifier->activationValue() !== $legacyIdentifier->activationValue()) {
                return null;
            }
        }
        return $identifier;
    } catch (InvalidArgumentException) {
        return null;
    }
}

function registration_trimmed_string(mixed $value): ?string
{
    if (!is_string($value)) {
        return null;
    }
    $value = trim($value);
    return $value === '' ? null : $value;
}

function registration_integer(mixed $value): ?int
{
    $integer = filter_var($value, FILTER_VALIDATE_INT);
    return $integer === false ? null : $integer;
}

/** @param null|callable(): string $doubleOptInTokenGenerator */
function create_registration(
    PDO $pdo,
    RegistrationSubmission $submission,
    ?callable $doubleOptInTokenGenerator = null
): RegistrationCreation {
    $identifier = $submission->identifier();
    $isDirect = $identifier->channel() === ParticipantIdentifier::DIRECT;
    $doubleOptInToken = null;
    $doubleOptInTokenHash = null;
    if ($isDirect) {
        $doubleOptInToken = ($doubleOptInTokenGenerator ?? static fn (): string => bin2hex(random_bytes(32)))();
        if (preg_match('/^[a-f0-9]{64}$/D', $doubleOptInToken) !== 1) {
            throw new RuntimeException('Double-opt-in token generator returned an invalid token.');
        }
        $doubleOptInTokenHash = hash('sha256', $doubleOptInToken);
    }

    $pdo->beginTransaction();
    try {
        $statement = $pdo->prepare(
            'INSERT INTO register
                (registration_channel, email, prolific_id, name, iban, bic,
                 age, cigarettes, doi_token, doi, studyinfo, dataprot,
                 dataprot_accepted_at, registration_confirmed_at)
             VALUES
                (:registration_channel, :email, :prolific_id, :name, :iban, :bic,
                 :age, :cigarettes, :doi_token, 0, 1, 1,
                 UTC_TIMESTAMP(), :registration_confirmed_at)'
        );
        $statement->execute([
            ':registration_channel' => $identifier->channel(),
            ':email' => $identifier->email(),
            ':prolific_id' => $identifier->prolificId(),
            ':name' => $submission->name(),
            ':iban' => $submission->iban(),
            ':bic' => $submission->bic(),
            ':age' => $submission->age(),
            ':cigarettes' => $submission->cigarettes(),
            ':doi_token' => $doubleOptInTokenHash,
            ':registration_confirmed_at' => $isDirect ? null : gmdate('Y-m-d H:i:s'),
        ]);
        $pdo->commit();

        return new RegistrationCreation($identifier->channel(), $doubleOptInToken);
    } catch (PDOException $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        if ((int) ($error->errorInfo[1] ?? 0) === 1062) {
            throw new DuplicateRegistrationException($identifier->channel(), $error);
        }
        throw $error;
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $error;
    }
}

function confirm_direct_registration(PDO $pdo, string $doubleOptInTokenHash): bool
{
    if (preg_match('/^[a-f0-9]{64}$/D', $doubleOptInTokenHash) !== 1) {
        return false;
    }

    $pdo->beginTransaction();
    try {
        $pending = $pdo->prepare(
            "SELECT registration_id
               FROM register
              WHERE registration_channel = 'DIRECT'
                AND doi_token = :doi_token
                AND doi = 0
              LIMIT 1
              FOR UPDATE"
        );
        $pending->execute([':doi_token' => $doubleOptInTokenHash]);
        $registrationId = $pending->fetchColumn();
        if ($registrationId === false) {
            $pdo->rollBack();
            return false;
        }

        $update = $pdo->prepare(
            "UPDATE register
                SET doi = 1,
                    registration_confirmed_at = COALESCE(registration_confirmed_at, UTC_TIMESTAMP())
              WHERE registration_id = :registration_id
                AND registration_channel = 'DIRECT'
                AND doi_token = :doi_token
                AND doi = 0"
        );
        $update->execute([
            ':registration_id' => $registrationId,
            ':doi_token' => $doubleOptInTokenHash,
        ]);
        if ($update->rowCount() !== 1) {
            throw new RuntimeException('Registration confirmation was not stored.');
        }
        $pdo->commit();
        return true;
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $error;
    }
}

/** @param array<string, mixed> $config */
function registration_pdo_from_config(array $config): PDO
{
    foreach (['host', 'dbname', 'user', 'pass'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || $config[$key] === '') {
            throw new RuntimeException('Missing or invalid database config: ' . $key);
        }
    }
    return new PDO(
        "mysql:host={$config['host']};dbname={$config['dbname']};charset=utf8mb4",
        $config['user'],
        $config['pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
}
