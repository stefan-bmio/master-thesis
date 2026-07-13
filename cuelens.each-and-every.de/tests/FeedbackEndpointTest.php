<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class FeedbackEndpointTest extends TestCase
{
    public function testRejectsNonPostRequestsWithoutConnectingToDatabase(): void
    {
        $response = $this->runEndpoint('GET', '');

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame([
            'success' => false,
            'error' => 'Method not allowed. Use POST.',
        ], json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR));
    }

    public function testRejectsEmptyFeedbackBeforeConnectingToDatabase(): void
    {
        $response = $this->runEndpoint('POST', '{"source":"  ","comment":""}');

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame([
            'success' => false,
            'error' => 'At least one feedback field is required.',
        ], json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR));
    }

    public function testRejectsMalformedFieldBeforeConnectingToDatabase(): void
    {
        $response = $this->runEndpoint('POST', '{"source":42,"comment":"Text"}');

        self::assertSame(0, $response['exit_code']);
        self::assertSame('', $response['stderr']);
        self::assertSame([
            'success' => false,
            'error' => 'Malformed field: source',
        ], json_decode($response['stdout'], true, 512, JSON_THROW_ON_ERROR));
    }

    /**
     * @return array{stdout: string, stderr: string, exit_code: int}
     */
    private function runEndpoint(string $method, string $body): array
    {
        $script = <<<'PHP'
$_SERVER['REQUEST_METHOD'] = (string) getenv('CUELENS_REQUEST_METHOD');
require getenv('CUELENS_ENDPOINT');
PHP;
        $command = escapeshellarg(PHP_BINARY) . ' -r ' . escapeshellarg($script);
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
            array_merge($_ENV, [
                'CUELENS_ENDPOINT' => dirname(__DIR__) . '/feedback.php',
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
