<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class SubmissionEndpointTest extends TestCase
{
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';
    private const CODE = '123e4567-e89b-42d3-a456-426614174000';

    public function testReturnsExistingDirectCompletionResponse(): void
    {
        $payload = [
            'success' => true,
            'status' => 'complete',
            'situation_index' => 20,
            'condition_code' => 'CUE_LABELING',
            'compensation_code' => self::CODE,
        ];
        $response = $this->runEndpoint(
            ['app_token' => self::TOKEN, 'craving' => 50],
            $payload
        );

        self::assertSame(200, $response['http_status']);
        self::assertSame($payload, $response['payload']);
    }

    public function testReturnsNonIdentifyingProlificCompletionResponse(): void
    {
        $payload = [
            'success' => true,
            'status' => 'complete',
            'situation_index' => 20,
            'condition_code' => 'CUE_LABELING',
            'completion_mode' => 'PROLIFIC_MANUAL',
        ];
        $response = $this->runEndpoint(
            ['app_token' => self::TOKEN, 'craving' => 50],
            $payload
        );

        self::assertSame(200, $response['http_status']);
        self::assertSame($payload, $response['payload']);
        self::assertArrayNotHasKey('compensation_code', $response['payload']);
        self::assertStringNotContainsString('AbCdEfGhIjKlMnOpQrStUv12', $response['stdout']);
    }

    public function testCompensationConfirmationKeepsNoContentResponse(): void
    {
        $response = $this->runEndpoint(
            ['compensation_code' => self::CODE],
            null
        );

        self::assertSame(204, $response['http_status']);
        self::assertSame('', $response['stdout']);
    }

    public function testAdministrativeCompletionFailureReturnsRetryableServerError(): void
    {
        $response = $this->runEndpoint(
            ['app_token' => self::TOKEN, 'craving' => 50],
            null,
            true
        );

        self::assertSame(500, $response['http_status']);
        self::assertSame(
            ['success' => false, 'error' => 'Server error.'],
            $response['payload']
        );
        self::assertStringNotContainsString(self::TOKEN, $response['stdout']);
    }

    /**
     * @param array<string, mixed> $request
     * @param null|array<string, mixed> $handlerResponse
     * @return array{stdout: string, payload: array<string, mixed>, http_status: int}
     */
    private function runEndpoint(
        array $request,
        ?array $handlerResponse,
        bool $handlerThrows = false
    ): array
    {
        $script = <<<'PHP'
$_SERVER['REQUEST_METHOD'] = 'PUT';
$GLOBALS['cuelens_http_client_error_reporter'] = static function (): void {};
$GLOBALS['cuelens_submission_endpoint_handler'] = static function (array $payload): ?array {
    if (getenv('CUELENS_HANDLER_THROWS') === '1') {
        throw new RuntimeException('Simulated administrative completion failure.');
    }
    $response = getenv('CUELENS_HANDLER_RESPONSE');
    return $response === '__NO_CONTENT__'
        ? null
        : json_decode($response, true, 512, JSON_THROW_ON_ERROR);
};
register_shutdown_function(static function (): void {
    fwrite(STDERR, "\nCUELENS_HTTP_STATUS=" . http_response_code());
});
require getenv('CUELENS_ENDPOINT');
PHP;
        $process = proc_open(
            escapeshellarg(PHP_BINARY) . ' -r ' . escapeshellarg($script),
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes,
            dirname(__DIR__),
            array_merge($_ENV, [
                'CUELENS_ENDPOINT' => dirname(__DIR__) . '/submit.php',
                'CUELENS_HANDLER_RESPONSE' => $handlerResponse === null
                    ? '__NO_CONTENT__'
                    : json_encode($handlerResponse, JSON_THROW_ON_ERROR),
                'CUELENS_HANDLER_THROWS' => $handlerThrows ? '1' : '0',
            ])
        );
        self::assertIsResource($process);
        fwrite($pipes[0], json_encode($request, JSON_THROW_ON_ERROR));
        fclose($pipes[0]);
        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);
        self::assertSame(0, proc_close($process), $stderr);
        self::assertMatchesRegularExpression('/\nCUELENS_HTTP_STATUS=\d+$/', $stderr);
        preg_match('/\nCUELENS_HTTP_STATUS=(\d+)$/', $stderr, $statusMatch);

        return [
            'stdout' => $stdout,
            'payload' => $stdout === ''
                ? []
                : json_decode($stdout, true, 512, JSON_THROW_ON_ERROR),
            'http_status' => (int) $statusMatch[1],
        ];
    }
}
