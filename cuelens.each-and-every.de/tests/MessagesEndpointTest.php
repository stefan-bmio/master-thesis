<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class MessagesEndpointTest extends TestCase
{
    public function testRejectsNonGetRequestsWithoutConnectingToDatabase(): void
    {
        $response = $this->runEndpoint('POST');

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame([
            'success' => false,
            'error' => 'Method not allowed. Use GET.',
        ], json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR));
    }

    /**
     * @return array{stdout: string, stderr: string, exit_code: int}
     */
    private function runEndpoint(string $method, string $queryString = ''): array
    {
        $script = <<<'PHP'
parse_str((string) getenv('CUELENS_QUERY_STRING'), $_GET);
$_SERVER['REQUEST_METHOD'] = (string) getenv('CUELENS_REQUEST_METHOD');
$GLOBALS['cuelens_http_client_error_reporter'] = static function (): void {};
require getenv('CUELENS_ENDPOINT');
PHP;
        $command = escapeshellarg(PHP_BINARY) . ' -r ' . escapeshellarg($script);
        $environment = array_merge($_ENV, [
            'CUELENS_ENDPOINT' => dirname(__DIR__) . '/messages.php',
            'CUELENS_QUERY_STRING' => $queryString,
            'CUELENS_REQUEST_METHOD' => $method,
        ]);
        $pipes = [];
        $process = proc_open(
            $command,
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes,
            dirname(__DIR__),
            $environment
        );

        self::assertIsResource($process);
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
