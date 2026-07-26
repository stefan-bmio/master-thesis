<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class ActivationEndpointTest extends TestCase
{
    public function testRejectsNonPutRequestWithoutDatabaseAccess(): void
    {
        $response = $this->runEndpoint('POST', '{}');

        self::assertSame(0, $response['exit_code']);
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
        yield 'invalid token' => [
            '{"email":"participant@example.org","app_token":"not-a-token"}',
        ];
    }

    /** @return array{stdout: string, stderr: string, exit_code: int} */
    private function runEndpoint(string $method, string $body): array
    {
        $script = <<<'PHP'
$_SERVER['REQUEST_METHOD'] = (string) getenv('CUELENS_REQUEST_METHOD');
$GLOBALS['cuelens_http_client_error_reporter'] = static function (): void {};
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
            ])
        );
        self::assertIsResource($process);
        fwrite($pipes[0], $body);
        fclose($pipes[0]);
        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        return [
            'stdout' => $stdout,
            'stderr' => $stderr,
            'exit_code' => proc_close($process),
        ];
    }
}
