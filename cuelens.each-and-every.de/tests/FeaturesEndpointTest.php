<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class FeaturesEndpointTest extends TestCase
{
    public function testRejectsNonGetRequestWithoutDatabaseAccess(): void
    {
        $script = <<<'PHP'
$_SERVER['REQUEST_METHOD'] = 'POST';
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
                'CUELENS_ENDPOINT' => dirname(__DIR__) . '/features.php',
            ])
        );
        self::assertIsResource($process);
        fclose($pipes[0]);
        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        self::assertSame(0, proc_close($process));
        self::assertSame('', $stderr);
        self::assertSame(
            ['success' => false, 'error' => 'Method not allowed. Use GET.'],
            json_decode($stdout, true, 512, JSON_THROW_ON_ERROR)
        );
    }
}
