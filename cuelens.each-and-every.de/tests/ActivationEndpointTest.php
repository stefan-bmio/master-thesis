<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class ActivationEndpointTest extends TestCase
{
    private const PROLIFIC_ID = 'AbCdEfGhIjKlMnOpQrStUv12';
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';

    public function testRejectsNonPutRequestWithoutDatabaseAccess(): void
    {
        $response = $this->runEndpoint('POST', '{}');

        self::assertSame(0, $response['exit_code']);
        self::assertSame(405, $response['http_status']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['success' => false, 'error' => 'Method not allowed. Use PUT.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @dataProvider invalidPayloadProvider */
    public function testRejectsInvalidPayloadWithNeutralResponse(string $payload): void
    {
        $response = $this->runEndpoint('PUT', $payload);

        self::assertSame(0, $response['exit_code']);
        self::assertSame(400, $response['http_status']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['success' => false, 'error' => 'Bad request.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @return iterable<string, array{string}> */
    public static function invalidPayloadProvider(): iterable
    {
        yield 'malformed JSON' => ['{'];
        yield 'invalid email' => ['{"email":"invalid"}'];
        yield 'malformed Prolific ID' => ['{"identifier":"AbCdEfGhIjKlMnOpQrStUv1!"}'];
        yield 'conflicting aliases' => [
            '{"identifier":"participant@example.org","email":"other@example.org"}',
        ];
        yield 'case-conflicting Prolific aliases' => [
            '{"identifier":"AbCdEfGhIjKlMnOpQrStUv12","email":"abcdefghijklmnopqrstuv12"}',
        ];
        yield 'invalid token' => [
            '{"email":"participant@example.org","app_token":"not-a-token"}',
        ];
    }

    /** @dataProvider requestPayloadProvider */
    public function testAcceptsGenericAndLegacyIdentifierProperties(string $payload): void
    {
        $response = $this->runEndpoint('PUT', $payload, true);

        self::assertSame(0, $response['exit_code']);
        self::assertSame(200, $response['http_status']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['app_token' => self::TOKEN],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @return iterable<string, array{string}> */
    public static function requestPayloadProvider(): iterable
    {
        yield 'generic direct email' => ['{"identifier":" Participant@Example.ORG "}'];
        yield 'generic Prolific ID' => ['{"identifier":" ' . self::PROLIFIC_ID . ' "}'];
        yield 'legacy email property' => ['{"email":"participant@example.org"}'];
        yield 'matching aliases after email normalization' => [
            '{"identifier":"Participant@Example.ORG","email":"participant@example.org"}',
        ];
    }

    public function testConfirmationPreservesNoContentStatus(): void
    {
        $response = $this->runEndpoint(
            'PUT',
            '{"identifier":"' . self::PROLIFIC_ID . '","app_token":"' . self::TOKEN . '"}',
            true
        );

        self::assertSame(0, $response['exit_code']);
        self::assertSame(204, $response['http_status']);
        self::assertSame('', $response['stderr']);
        self::assertSame('', $response['stdout']);
    }

    public function testErrorResponseNeverContainsSubmittedIdentifier(): void
    {
        $submitted = 'AbCdEfGhIjKlMnOpQrStUv1!';
        $response = $this->runEndpoint(
            'PUT',
            json_encode(['identifier' => $submitted], JSON_THROW_ON_ERROR)
        );

        self::assertStringNotContainsString($submitted, $response['stdout']);
        self::assertSame(
            ['success' => false, 'error' => 'Bad request.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @return array{stdout: string, stderr: string, exit_code: int, http_status: int} */
    private function runEndpoint(string $method, string $body, bool $useActivationHandler = false): array
    {
        $script = <<<'PHP'
$_SERVER['REQUEST_METHOD'] = (string) getenv('CUELENS_REQUEST_METHOD');
$GLOBALS['cuelens_http_client_error_reporter'] = static function (): void {};
register_shutdown_function(static function (): void {
    fwrite(STDERR, "\nCUELENS_HTTP_STATUS=" . http_response_code());
});
if (getenv('CUELENS_USE_ACTIVATION_HANDLER') === '1') {
    $GLOBALS['cuelens_activation_endpoint_handler'] = static function (
        ParticipantIdentifier $identifier,
        ?string $appToken
    ): ?string {
        return $appToken === null
            ? '550e8400-e29b-41d4-a716-446655440000'
            : null;
    };
}
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
                'CUELENS_ENDPOINT' => dirname(__DIR__) . '/activate.php',
                'CUELENS_REQUEST_METHOD' => $method,
                'CUELENS_USE_ACTIVATION_HANDLER' => $useActivationHandler ? '1' : '0',
            ])
        );
        self::assertIsResource($process);
        fwrite($pipes[0], $body);
        fclose($pipes[0]);
        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);
        self::assertMatchesRegularExpression('/\nCUELENS_HTTP_STATUS=\d+$/', $stderr);
        preg_match('/\nCUELENS_HTTP_STATUS=(\d+)$/', $stderr, $statusMatch);
        $stderr = preg_replace('/\nCUELENS_HTTP_STATUS=\d+$/', '', $stderr);
        self::assertIsString($stderr);

        return [
            'stdout' => $stdout,
            'stderr' => $stderr,
            'exit_code' => proc_close($process),
            'http_status' => (int) $statusMatch[1],
        ];
    }
}
