<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class DataProtectionEndpointTest extends TestCase
{
    private const TOKEN = '550e8400-e29b-41d4-a716-446655440000';

    public function testRejectsUnsupportedMethodBeforeDatabaseAccess(): void
    {
        $response = $this->runEndpoint('GET', '{}');

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['success' => false, 'error' => 'Method not allowed. Use POST or PUT.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @dataProvider invalidTokenPayloadProvider */
    public function testRejectsMissingOrInvalidTokenBeforeDatabaseAccess(
        string $method,
        string $payload
    ): void
    {
        $response = $this->runEndpoint($method, $payload);

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['success' => false, 'error' => 'Unauthorized.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @return iterable<string, array{string, string}> */
    public static function invalidTokenPayloadProvider(): iterable
    {
        yield 'POST without token' => ['POST', '{}'];
        yield 'POST with malformed token' => ['POST', '{"app_token":"invalid"}'];
        yield 'PUT without token' => ['PUT', '{"dataprot":true}'];
    }

    /** @dataProvider invalidPostPayloadProvider */
    public function testRejectsInvalidPostPayloadBeforeDatabaseAccess(string $payload): void
    {
        $response = $this->runEndpoint('POST', $payload);

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame(
            ['success' => false, 'error' => 'Bad request.'],
            json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR)
        );
    }

    /** @return iterable<string, array{string}> */
    public static function invalidPostPayloadProvider(): iterable
    {
        yield 'empty' => [''];
        yield 'malformed JSON' => ['{'];
        yield 'array instead of object' => ['[]'];
        yield 'unexpected field' => [
            '{"app_token":"' . self::TOKEN . '","dataprot":true}',
        ];
    }

    /** @dataProvider invalidPutPayloadProvider */
    public function testRejectsInvalidPutPayloadBeforeDatabaseAccess(string $payload): void
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
    public static function invalidPutPayloadProvider(): iterable
    {
        yield 'empty' => [''];
        yield 'malformed JSON' => ['{'];
        yield 'array instead of object' => ['[]'];
        yield 'false consent' => [
            '{"app_token":"' . self::TOKEN . '","dataprot":false}',
        ];
        yield 'missing consent' => ['{"app_token":"' . self::TOKEN . '"}'];
        yield 'unexpected field' => [
            '{"app_token":"' . self::TOKEN . '","dataprot":true,"email":"participant@example.org"}',
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
                'CUELENS_ENDPOINT' => dirname(__DIR__) . '/dataprot.php',
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
