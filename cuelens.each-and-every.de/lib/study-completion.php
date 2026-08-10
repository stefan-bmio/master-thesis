<?php
declare(strict_types=1);

require_once __DIR__ . '/token-identity.php';
require_once __DIR__ . '/completion-mode.php';

const TOTAL_SUBMISSION_COUNT = 20;

final class StudySubmissionRejectedException extends RuntimeException
{
}

final class StudyCompletionPersistenceException extends RuntimeException
{
}

function generate_compensation_uuid_v4(): string
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

function is_compensation_uuid_v4(string $value): bool
{
    return preg_match(
        '/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/D',
        strtolower($value)
    ) === 1;
}

function condition_code_for_index(int $situationIndex): string
{
    return $situationIndex <= 10 ? 'CUE_MATCHING' : 'CUE_LABELING';
}

/** @return array<string, mixed> */
function completed_study_response(
    string $completionMode,
    ?string $compensationCode = null
): array {
    $response = [
        'success' => true,
        'status' => 'complete',
        'situation_index' => TOTAL_SUBMISSION_COUNT,
        'condition_code' => condition_code_for_index(TOTAL_SUBMISSION_COUNT),
    ];

    if ($completionMode === COMPLETION_MODE_COMPENSATION_CODE) {
        if ($compensationCode === null || !is_compensation_uuid_v4($compensationCode)) {
            throw new RuntimeException('Missing or invalid compensation code.');
        }
        $response['compensation_code'] = strtolower($compensationCode);
        return $response;
    }
    if ($completionMode === COMPLETION_MODE_PROLIFIC_MANUAL) {
        if ($compensationCode !== null) {
            throw new RuntimeException('Prolific completion must not contain a compensation code.');
        }
        $response['completion_mode'] = COMPLETION_MODE_PROLIFIC_MANUAL;
        return $response;
    }

    throw new RuntimeException('Unsupported completion mode.');
}

/** @return array<string, mixed> */
function ongoing_study_response(int $situationIndex): array
{
    return [
        'success' => true,
        'situation_index' => $situationIndex,
        'condition_code' => condition_code_for_index($situationIndex),
    ];
}

/**
 * Stores one report and applies the non-identifying completion policy from the
 * research allowlist. The administrative connection is requested lazily and
 * only for a final or retried Prolific completion.
 *
 * @param null|callable(): PDO $administrativePdoFactory
 * @param null|callable(): string $compensationCodeGenerator
 * @param null|callable(): mixed $prolificCompletionNotifier
 * @return array<string, mixed>
 */
function submit_study_report(
    PDO $researchPdo,
    string $appToken,
    int $craving,
    string $pseudonymSecret,
    ?callable $administrativePdoFactory = null,
    ?callable $compensationCodeGenerator = null,
    ?callable $prolificCompletionNotifier = null
): array {
    $validTokenHash = valid_app_token_hash($pseudonymSecret, $appToken);
    $participantId = participant_id_for_app_token($pseudonymSecret, $appToken);

    $researchPdo->beginTransaction();
    try {
        $allowlist = $researchPdo->prepare(
            'SELECT completion_mode
               FROM valid_app_token_hashes
              WHERE hash = :hash'
        );
        $allowlist->execute([':hash' => $validTokenHash]);
        $completionMode = $allowlist->fetchColumn();
        if (!is_string($completionMode)) {
            throw new StudySubmissionRejectedException('Bad request.');
        }
        if (!is_supported_completion_mode($completionMode)) {
            throw new RuntimeException('Unsupported completion mode.');
        }

        $existing = $researchPdo->prepare(
            'SELECT participant_id
               FROM self_reports
              WHERE participant_id = :participant_id
              FOR UPDATE'
        );
        $existing->execute([':participant_id' => $participantId]);
        $submittedCount = count($existing->fetchAll());

        if ($submittedCount >= TOTAL_SUBMISSION_COUNT) {
            $researchPdo->rollBack();
            if ($completionMode !== COMPLETION_MODE_PROLIFIC_MANUAL) {
                throw new StudySubmissionRejectedException('Study is already complete.');
            }

            finalize_prolific_study(
                $appToken,
                $pseudonymSecret,
                $administrativePdoFactory,
                $prolificCompletionNotifier
            );
            return completed_study_response(COMPLETION_MODE_PROLIFIC_MANUAL);
        }

        $situationIndex = $submittedCount + 1;
        $conditionCode = condition_code_for_index($situationIndex);
        $report = $researchPdo->prepare(
            'INSERT INTO self_reports (participant_id, condition_code, craving)
             VALUES (:participant_id, :condition_code, :craving)'
        );
        $report->bindValue(':participant_id', $participantId, PDO::PARAM_STR);
        $report->bindValue(':condition_code', $conditionCode, PDO::PARAM_STR);
        $report->bindValue(':craving', $craving, PDO::PARAM_INT);
        $report->execute();

        if ($situationIndex !== TOTAL_SUBMISSION_COUNT) {
            $researchPdo->commit();
            return ongoing_study_response($situationIndex);
        }

        if ($completionMode === COMPLETION_MODE_COMPENSATION_CODE) {
            $compensationCode = ($compensationCodeGenerator ?? 'generate_compensation_uuid_v4')();
            if (!is_compensation_uuid_v4($compensationCode)) {
                throw new RuntimeException('Compensation-code generator returned an invalid UUID-v4.');
            }
            $compensationCode = strtolower($compensationCode);
            $code = $researchPdo->prepare(
                'INSERT INTO compensation_code (compensation_code)
                 VALUES (:compensation_code)'
            );
            $code->execute([':compensation_code' => $compensationCode]);
            $researchPdo->commit();
            return completed_study_response($completionMode, $compensationCode);
        }

        $researchPdo->commit();
        finalize_prolific_study(
            $appToken,
            $pseudonymSecret,
            $administrativePdoFactory,
            $prolificCompletionNotifier
        );
        return completed_study_response(COMPLETION_MODE_PROLIFIC_MANUAL);
    } catch (Throwable $error) {
        if ($researchPdo->inTransaction()) {
            $researchPdo->rollBack();
        }
        throw $error;
    }
}

/**
 * @param null|callable(): PDO $administrativePdoFactory
 * @param null|callable(): mixed $prolificCompletionNotifier
 */
function finalize_prolific_study(
    string $appToken,
    string $pseudonymSecret,
    ?callable $administrativePdoFactory,
    ?callable $prolificCompletionNotifier = null
): void {
    if ($administrativePdoFactory === null) {
        throw new StudyCompletionPersistenceException(
            'Administrative study completion is unavailable.'
        );
    }

    try {
        $administrativePdo = $administrativePdoFactory();
        if (!$administrativePdo instanceof PDO) {
            throw new RuntimeException('Administrative database factory returned no PDO.');
        }
        $registrationTokenHash = registration_token_hash($pseudonymSecret, $appToken);

        $administrativePdo->beginTransaction();
        $registration = $administrativePdo->prepare(
            'SELECT registration_id
               FROM register
              WHERE registration_channel = \'PROLIFIC\'
                AND registration_token_hash = :registration_token_hash
                AND app_token_issued_at IS NOT NULL
              FOR UPDATE'
        );
        $registration->execute([':registration_token_hash' => $registrationTokenHash]);
        $registrationId = $registration->fetchColumn();
        if ($registrationId === false) {
            throw new RuntimeException('Activated Prolific registration was not found.');
        }

        $complete = $administrativePdo->prepare(
            'UPDATE register
                SET study_completed_at = COALESCE(study_completed_at, CURRENT_TIMESTAMP)
              WHERE registration_id = :registration_id
                AND registration_channel = \'PROLIFIC\''
        );
        $complete->execute([':registration_id' => $registrationId]);

        $claimNotification = $administrativePdo->prepare(
            'UPDATE register
                SET completion_notification_queued_at = CURRENT_TIMESTAMP
              WHERE registration_id = :registration_id
                AND registration_channel = \'PROLIFIC\'
                AND study_completed_at IS NOT NULL
                AND completion_notification_queued_at IS NULL'
        );
        $claimNotification->execute([':registration_id' => $registrationId]);
        $notificationClaimed = $claimNotification->rowCount() === 1;
        $administrativePdo->commit();

        if ($notificationClaimed && $prolificCompletionNotifier !== null) {
            $prolificCompletionNotifier();
        }
    } catch (Throwable $error) {
        if (
            isset($administrativePdo) &&
            $administrativePdo instanceof PDO &&
            $administrativePdo->inTransaction()
        ) {
            $administrativePdo->rollBack();
        }
        if ($error instanceof StudyCompletionPersistenceException) {
            throw $error;
        }
        throw new StudyCompletionPersistenceException(
            'Administrative study completion failed.',
            0,
            $error
        );
    }
}

function confirm_compensation_code(PDO $researchPdo, string $compensationCode): void
{
    $confirmation = $researchPdo->prepare(
        'UPDATE compensation_code
            SET confirmed_at = COALESCE(confirmed_at, CURRENT_TIMESTAMP)
          WHERE compensation_code = :compensation_code'
    );
    $confirmation->execute([':compensation_code' => strtolower($compensationCode)]);
}
