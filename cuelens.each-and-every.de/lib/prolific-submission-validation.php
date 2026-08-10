<?php
declare(strict_types=1);

require_once __DIR__ . '/participant-identifier.php';

const PROLIFIC_SUBMISSIONS_ENDPOINT = 'https://api.prolific.com/api/v1/submissions/';
const PROLIFIC_SUBMISSIONS_PAGE_SIZE = 20;
const PROLIFIC_SUBMISSIONS_MAX_PAGES = 1000;
const PROLIFIC_RESPONSE_MAX_BYTES = 1048576;
const PROLIFIC_ELIGIBLE_SUBMISSION_STATUSES = [
    'ACTIVE',
    'AWAITING_REVIEW',
    'APPROVED',
    'TIMED_OUT',
    'RETURNED',
];

final class ProlificApiException extends RuntimeException
{
}

final class ProlificHttpResponse
{
    public function __construct(
        private readonly int $statusCode,
        private readonly string $body
    ) {
    }

    public function statusCode(): int
    {
        return $this->statusCode;
    }

    public function body(): string
    {
        return $this->body;
    }
}

/**
 * Checks whether the participant has at least one eligible submission in the
 * configured study. A false result means that all pages were read successfully
 * but no eligible submission was found. Technical failures always throw.
 *
 * @param array<string, mixed> $hostConfig
 * @param null|callable(string, list<string>): ProlificHttpResponse $httpGet
 */
function prolific_participant_has_eligible_submission(
    array $hostConfig,
    string $participantId,
    ?callable $httpGet = null
): bool {
    try {
        $identifier = ParticipantIdentifier::parse($participantId);
    } catch (InvalidArgumentException) {
        throw new InvalidArgumentException('Invalid Prolific participant ID.');
    }
    if ($identifier->channel() !== ParticipantIdentifier::PROLIFIC) {
        throw new InvalidArgumentException('Invalid Prolific participant ID.');
    }

    $token = prolific_required_config_string($hostConfig, 'prolific_token');
    $studyId = prolific_required_config_string($hostConfig, 'prolific_study_id');
    if (preg_match('/^[A-Za-z0-9]{24}$/D', $studyId) !== 1) {
        throw new ProlificApiException('Invalid Prolific API configuration.');
    }

    $transport = $httpGet ?? 'prolific_https_get';
    $headers = [
        'Accept: application/json',
        'Authorization: Token ' . $token,
    ];
    $seenFullPages = [];

    for ($page = 1; $page <= PROLIFIC_SUBMISSIONS_MAX_PAGES; $page++) {
        $url = PROLIFIC_SUBMISSIONS_ENDPOINT . '?' . http_build_query([
            'study' => $studyId,
            'page_size' => PROLIFIC_SUBMISSIONS_PAGE_SIZE,
            'page' => $page,
        ], '', '&', PHP_QUERY_RFC3986);

        try {
            $response = $transport($url, $headers);
        } catch (ProlificApiException $error) {
            throw $error;
        } catch (Throwable) {
            throw new ProlificApiException('Prolific API transport failed.');
        }
        if (!$response instanceof ProlificHttpResponse) {
            throw new ProlificApiException('Invalid Prolific API transport response.');
        }
        if ($response->statusCode() !== 200) {
            throw new ProlificApiException(
                'Prolific API request failed with HTTP status ' . $response->statusCode() . '.'
            );
        }

        try {
            $payload = json_decode($response->body(), true, 32, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new ProlificApiException('Invalid Prolific API JSON response.');
        }
        if (!is_array($payload) || !isset($payload['results']) ||
            !is_array($payload['results']) || !array_is_list($payload['results'])) {
            throw new ProlificApiException('Invalid Prolific API response structure.');
        }

        foreach ($payload['results'] as $submission) {
            if (!is_array($submission) ||
                !isset($submission['participant_id'], $submission['status']) ||
                !is_string($submission['participant_id']) ||
                !is_string($submission['status'])) {
                throw new ProlificApiException('Invalid Prolific submission response.');
            }

            $canonicalStatus = prolific_canonical_submission_status($submission['status']);
            if (hash_equals($identifier->prolificId() ?? '', $submission['participant_id']) &&
                in_array($canonicalStatus, PROLIFIC_ELIGIBLE_SUBMISSION_STATUSES, true)) {
                return true;
            }
        }

        $resultCount = count($payload['results']);
        if ($resultCount < PROLIFIC_SUBMISSIONS_PAGE_SIZE) {
            return false;
        }
        if ($resultCount > PROLIFIC_SUBMISSIONS_PAGE_SIZE) {
            throw new ProlificApiException('Invalid Prolific API page size.');
        }

        $pageSignature = hash('sha256', $response->body());
        if (isset($seenFullPages[$pageSignature])) {
            throw new ProlificApiException('Prolific API pagination did not advance.');
        }
        $seenFullPages[$pageSignature] = true;
    }

    throw new ProlificApiException('Prolific API pagination limit exceeded.');
}

/** @param array<string, mixed> $config */
function prolific_required_config_string(array $config, string $key): string
{
    $value = $config[$key] ?? null;
    if (!is_string($value)) {
        throw new ProlificApiException('Invalid Prolific API configuration.');
    }
    $value = trim($value);
    if ($value === '' || strlen($value) > 4096 || preg_match('/[\r\n]/', $value) === 1) {
        throw new ProlificApiException('Invalid Prolific API configuration.');
    }
    return $value;
}

function prolific_canonical_submission_status(string $status): string
{
    return str_replace(['-', ' '], '_', strtoupper(trim($status)));
}

/** @param list<string> $headers */
function prolific_https_get(string $url, array $headers): ProlificHttpResponse
{
    if (!str_starts_with($url, PROLIFIC_SUBMISSIONS_ENDPOINT . '?')) {
        throw new ProlificApiException('Invalid Prolific API request URL.');
    }
    if (!function_exists('curl_init')) {
        throw new ProlificApiException('Prolific API transport is unavailable.');
    }

    $curl = curl_init($url);
    if ($curl === false) {
        throw new ProlificApiException('Prolific API transport is unavailable.');
    }

    $body = '';
    $responseTooLarge = false;
    curl_setopt_array($curl, [
        CURLOPT_HTTPGET => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_USERAGENT => 'CueLens registration server',
        CURLOPT_WRITEFUNCTION => static function ($handle, string $chunk) use (&$body, &$responseTooLarge): int {
            if (strlen($body) + strlen($chunk) > PROLIFIC_RESPONSE_MAX_BYTES) {
                $responseTooLarge = true;
                return 0;
            }
            $body .= $chunk;
            return strlen($chunk);
        },
    ]);

    try {
        $success = curl_exec($curl);
        if ($success === false) {
            $category = $responseTooLarge ? 'response_too_large' : 'curl_' . curl_errno($curl);
            throw new ProlificApiException('Prolific API transport failed: ' . $category . '.');
        }
        $statusCode = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
    } finally {
        curl_close($curl);
    }

    return new ProlificHttpResponse($statusCode, $body);
}
