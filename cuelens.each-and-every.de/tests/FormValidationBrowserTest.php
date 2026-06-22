<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class FormValidationBrowserTest extends TestCase
{
    private const BASE_URL = 'http://127.0.0.1:8080/cuelens';
    private const WEBDRIVER_HOST = '127.0.0.1';
    private const ELEMENT_KEY = 'element-6066-11e4-a52e-4f735466cecf';
    private const GECKODRIVER_BIN_CANDIDATES = [
        '/usr/bin/geckodriver',
        '/usr/local/bin/geckodriver',
        '/snap/bin/geckodriver',
        'geckodriver',
    ];

    private static ?string $sessionId = null;
    private static ?string $webDriverUrl = null;
    private static ?int $geckoDriverPort = null;
    private static ?string $geckoDriverLogFile = null;
    private static ?string $geckoProfileParent = null;
    private static ?string $geckoProfileRoot = null;
    private static bool $keepGeckoDriverLog = false;
    private static bool $shutdownCleanupRegistered = false;

    /** @var resource|null */
    private static $geckoDriverProcess = null;

    /** @var array<int, resource>|null */
    private static ?array $geckoDriverPipes = null;

    public static function setUpBeforeClass(): void
    {
        if (!extension_loaded('curl')) {
            self::markTestSkipped('The PHP curl extension is required for WebDriver requests.');
        }

        if (!self::isUrlReachable(self::BASE_URL . '/index-de.php')) {
            self::markTestSkipped('The default Apache test URL is not reachable: ' . self::BASE_URL);
        }

        try {
            self::startGeckoDriver();
            self::createSession();
            self::setWindowSize(390, 844);
        } catch (RuntimeException $exception) {
            self::$keepGeckoDriverLog = true;
            self::tearDownAfterClass();
            self::markTestSkipped(
                'geckodriver could not start Firefox: '
                . $exception->getMessage()
                . self::geckoDriverDiagnostics()
            );
        }
    }

    public static function tearDownAfterClass(): void
    {
        if (self::$sessionId !== null) {
            try {
                self::request('DELETE', '/session/' . rawurlencode(self::$sessionId));
            } catch (RuntimeException) {
                // The browser may already be gone; cleanup continues with geckodriver.
            }

            self::$sessionId = null;
        }

        self::stopGeckoDriver();
        self::stopFirefoxProcessesForProfileRoot();
        self::removeProfileRoot();
        self::removeGeckoDriverLogIfUnneeded();
    }

    public function testGermanEmailRequiredMessageIsShownInBrowser(): void
    {
        self::navigateTo(self::BASE_URL . '/index-de.php');

        self::type('#name', 'Test Person');
        self::type('#iban', 'DE89370400440532013000');
        self::type('#bic', 'COBADEFFXXX');
        self::type('#age', '30');
        self::type('#cigarettes', '10');
        self::click('#studyinfo');
        self::click('#dataprot');
        self::click('button[type="submit"]');

        $expectedMessage = 'Bitte geben Sie Ihre E-Mail-Adresse ein.';

        self::assertSame($expectedMessage, self::script('return document.getElementById("email").validationMessage;'));
        self::assertSame($expectedMessage, self::script('return document.getElementById("form-validation-message").textContent;'));
        self::assertFalse(self::script('return document.getElementById("form-validation-message").hidden;'));
        self::assertStringContainsString(
            'error',
            (string) self::script('return document.getElementById("form-validation-message").className;')
        );
    }

    private static function type(string $selector, string $value): void
    {
        $elementId = self::findElement($selector);

        self::request('POST', self::sessionPath('/element/' . rawurlencode($elementId) . '/clear'), new stdClass());
        self::request('POST', self::sessionPath('/element/' . rawurlencode($elementId) . '/value'), [
            'text' => $value,
            'value' => preg_split('//u', $value, -1, PREG_SPLIT_NO_EMPTY),
        ]);
    }

    private static function click(string $selector): void
    {
        $elementId = self::findElement($selector);

        self::request('POST', self::sessionPath('/element/' . rawurlencode($elementId) . '/click'), new stdClass());
    }

    private static function script(string $script): mixed
    {
        $response = self::request('POST', self::sessionPath('/execute/sync'), [
            'script' => $script,
            'args' => [],
        ]);

        return $response['value'] ?? null;
    }

    private static function isUrlReachable(string $url): bool
    {
        $context = stream_context_create([
            'http' => [
                'ignore_errors' => true,
                'timeout' => 2,
            ],
        ]);

        $response = @file_get_contents($url, false, $context);

        return $response !== false && str_contains($response, '<form method="post" action="">');
    }

    private static function isWebDriverReachable(): bool
    {
        if (self::$webDriverUrl === null) {
            return false;
        }

        $context = stream_context_create([
            'http' => [
                'ignore_errors' => true,
                'timeout' => 1,
            ],
        ]);

        return @file_get_contents(self::$webDriverUrl . '/status', false, $context) !== false;
    }

    private static function startGeckoDriver(): void
    {
        self::$geckoDriverPort = self::findFreePort();
        self::$webDriverUrl = 'http://' . self::WEBDRIVER_HOST . ':' . self::$geckoDriverPort;
        self::$geckoDriverLogFile = self::newTempPath('cuelens-geckodriver-', '.log');
        self::$geckoProfileParent = self::firefoxProfileParentDirectory();
        self::$geckoProfileRoot = self::newTempPath('cuelens-geckodriver-profile-', '', self::$geckoProfileParent);

        if (!mkdir(self::$geckoProfileRoot, 0700, true) && !is_dir(self::$geckoProfileRoot)) {
            throw new RuntimeException('Could not create Firefox profile root: ' . self::$geckoProfileRoot);
        }

        $descriptorSpec = [
            0 => ['pipe', 'r'],
            1 => ['file', self::$geckoDriverLogFile, 'a'],
            2 => ['file', self::$geckoDriverLogFile, 'a'],
        ];

        self::$geckoDriverProcess = proc_open(
            escapeshellarg(self::geckoDriverBinary())
            . ' --host ' . escapeshellarg(self::WEBDRIVER_HOST)
            . ' --port ' . self::$geckoDriverPort
            . ' --profile-root ' . escapeshellarg(self::$geckoProfileRoot)
            . ' --log debug',
            $descriptorSpec,
            self::$geckoDriverPipes
        );

        if (!is_resource(self::$geckoDriverProcess)) {
            self::$geckoDriverProcess = null;
            throw new RuntimeException('Could not start geckodriver process.');
        }

        if (!self::$shutdownCleanupRegistered) {
            self::$shutdownCleanupRegistered = true;
            register_shutdown_function(static function (): void {
                self::tearDownAfterClass();
            });
        }

        for ($attempt = 0; $attempt < 50; $attempt++) {
            if (self::isWebDriverReachable()) {
                return;
            }

            $status = proc_get_status(self::$geckoDriverProcess);
            if (!($status['running'] ?? false)) {
                throw new RuntimeException('geckodriver exited before it became reachable.');
            }

            usleep(100000);
        }

        throw new RuntimeException('geckodriver did not become reachable at ' . self::$webDriverUrl . '.');
    }

    private static function stopGeckoDriver(): void
    {
        if (self::$geckoDriverPipes !== null) {
            foreach (self::$geckoDriverPipes as $pipe) {
                if (is_resource($pipe)) {
                    fclose($pipe);
                }
            }

            self::$geckoDriverPipes = null;
        }

        if (is_resource(self::$geckoDriverProcess)) {
            $status = proc_get_status(self::$geckoDriverProcess);
            $pid = $status['pid'] ?? null;

            proc_terminate(self::$geckoDriverProcess);

            for ($attempt = 0; $attempt < 20; $attempt++) {
                $status = proc_get_status(self::$geckoDriverProcess);
                if (!($status['running'] ?? false)) {
                    break;
                }

                usleep(100000);
            }

            $status = proc_get_status(self::$geckoDriverProcess);
            if (($status['running'] ?? false) && is_int($pid) && function_exists('posix_kill')) {
                posix_kill($pid, 9);
            }

            proc_close(self::$geckoDriverProcess);
        }

        self::$geckoDriverProcess = null;
        self::$geckoDriverPort = null;
        self::$webDriverUrl = null;
    }

    private static function geckoDriverBinary(): string
    {
        foreach (self::GECKODRIVER_BIN_CANDIDATES as $candidate) {
            if (str_contains($candidate, '/') && is_executable($candidate)) {
                return $candidate;
            }
        }

        return 'geckodriver';
    }

    private static function findFreePort(): int
    {
        $socket = @stream_socket_server('tcp://' . self::WEBDRIVER_HOST . ':0', $errorCode, $errorMessage);
        if (!is_resource($socket)) {
            throw new RuntimeException('Could not find a free WebDriver port: ' . $errorMessage);
        }

        $name = stream_socket_get_name($socket, false);
        fclose($socket);

        if (!is_string($name) || !preg_match('/:(\d+)$/', $name, $matches)) {
            throw new RuntimeException('Could not determine the selected WebDriver port.');
        }

        return (int) $matches[1];
    }

    private static function firefoxProfileParentDirectory(): string
    {
        $home = null;
        if (function_exists('posix_getpwuid')) {
            $user = posix_getpwuid(posix_getuid());
            if (is_array($user) && isset($user['dir']) && is_string($user['dir'])) {
                $home = $user['dir'];
            }
        }

        $candidates = [];
        if ($home !== null) {
            $candidates[] = $home . '/snap/firefox/common';
        }

        $candidates[] = sys_get_temp_dir();

        foreach ($candidates as $candidate) {
            if (is_dir($candidate) && is_writable($candidate)) {
                return $candidate;
            }
        }

        throw new RuntimeException('Could not find a writable Firefox profile parent directory.');
    }

    private static function newTempPath(string $prefix, string $suffix, ?string $directory = null): string
    {
        $path = tempnam($directory ?? sys_get_temp_dir(), $prefix);
        if ($path === false) {
            throw new RuntimeException('Could not create a temporary path.');
        }

        if ($suffix !== '') {
            $pathWithSuffix = $path . $suffix;
            if (!rename($path, $pathWithSuffix)) {
                @unlink($path);
                throw new RuntimeException('Could not create a temporary path with suffix: ' . $suffix);
            }

            return $pathWithSuffix;
        }

        @unlink($path);
        return $path;
    }

    private static function createSession(): void
    {
        $response = self::request('POST', '/session', [
            'capabilities' => [
                'alwaysMatch' => [
                    'browserName' => 'firefox',
                    'moz:firefoxOptions' => [
                        'args' => ['-headless'],
                    ],
                ],
            ],
        ], 30000);

        $sessionId = $response['value']['sessionId'] ?? null;
        if (!is_string($sessionId) || $sessionId === '') {
            throw new RuntimeException('Session response did not contain a session id.');
        }

        self::$sessionId = $sessionId;
    }

    private static function setWindowSize(int $width, int $height): void
    {
        self::request('POST', self::sessionPath('/window/rect'), [
            'x' => 0,
            'y' => 0,
            'width' => $width,
            'height' => $height,
        ]);
    }

    private static function navigateTo(string $url): void
    {
        self::request('POST', self::sessionPath('/url'), ['url' => $url]);
    }

    private static function findElement(string $selector): string
    {
        $response = self::request('POST', self::sessionPath('/element'), [
            'using' => 'css selector',
            'value' => $selector,
        ]);

        $elementId = $response['value'][self::ELEMENT_KEY] ?? $response['value']['ELEMENT'] ?? null;
        if (!is_string($elementId) || $elementId === '') {
            throw new RuntimeException('Element not found for selector: ' . $selector);
        }

        return $elementId;
    }

    private static function sessionPath(string $path): string
    {
        if (self::$sessionId === null) {
            throw new RuntimeException('No active WebDriver session.');
        }

        return '/session/' . rawurlencode(self::$sessionId) . $path;
    }

    private static function webDriverUrl(): string
    {
        if (self::$webDriverUrl === null) {
            throw new RuntimeException('No active WebDriver server.');
        }

        return self::$webDriverUrl;
    }

    private static function geckoDriverDiagnostics(): string
    {
        if (self::$geckoDriverLogFile === null) {
            return '';
        }

        $parts = ['geckodriver log file: ' . self::$geckoDriverLogFile];
        $tail = self::tailFile(self::$geckoDriverLogFile, 80);

        if ($tail !== '') {
            $parts[] = "geckodriver log tail:\n" . $tail;
        }

        return "\n\n" . implode("\n\n", $parts);
    }

    private static function tailFile(string $path, int $lines): string
    {
        if (!is_file($path)) {
            return '';
        }

        $fileLines = @file($path, FILE_IGNORE_NEW_LINES);
        if ($fileLines === false) {
            return '';
        }

        return implode("\n", array_slice($fileLines, -$lines));
    }

    private static function stopFirefoxProcessesForProfileRoot(): void
    {
        if (self::$geckoProfileRoot === null || !function_exists('posix_kill')) {
            return;
        }

        $pids = [];
        foreach (glob('/proc/[0-9]*/cmdline') ?: [] as $cmdlineFile) {
            $cmdline = @file_get_contents($cmdlineFile);
            if ($cmdline === false) {
                continue;
            }

            $displayCmdline = str_replace("\0", ' ', $cmdline);
            if (!str_contains($displayCmdline, 'firefox') || !str_contains($displayCmdline, self::$geckoProfileRoot)) {
                continue;
            }

            $pid = (int) basename(dirname($cmdlineFile));
            if ($pid > 0) {
                $pids[] = $pid;
            }
        }

        foreach ($pids as $pid) {
            @posix_kill($pid, 15);
        }

        for ($attempt = 0; $attempt < 10; $attempt++) {
            $running = array_filter($pids, static fn (int $pid): bool => @posix_kill($pid, 0));
            if ($running === []) {
                return;
            }

            usleep(100000);
        }

        foreach ($pids as $pid) {
            if (@posix_kill($pid, 0)) {
                @posix_kill($pid, 9);
            }
        }
    }

    private static function removeProfileRoot(): void
    {
        if (self::$geckoProfileRoot === null) {
            return;
        }

        $profileRoot = self::$geckoProfileRoot;
        $profileParent = self::$geckoProfileParent;
        self::$geckoProfileRoot = null;
        self::$geckoProfileParent = null;

        if (
            $profileParent === null
            || basename($profileRoot) === ''
            || !str_starts_with(basename($profileRoot), 'cuelens-geckodriver-profile-')
            || realpath(dirname($profileRoot)) !== realpath($profileParent)
            || !is_dir($profileRoot)
        ) {
            return;
        }

        $items = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($profileRoot, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST
        );

        foreach ($items as $item) {
            if ($item->isDir()) {
                @rmdir($item->getPathname());
            } else {
                @unlink($item->getPathname());
            }
        }

        @rmdir($profileRoot);
    }

    private static function removeGeckoDriverLogIfUnneeded(): void
    {
        if (self::$geckoDriverLogFile === null) {
            return;
        }

        if (!self::$keepGeckoDriverLog) {
            @unlink(self::$geckoDriverLogFile);
            self::$geckoDriverLogFile = null;
        }
    }

    /**
     * @param array<string, mixed>|stdClass|null $payload
     * @return array<string, mixed>
     */
    private static function request(string $method, string $path, array|stdClass|null $payload = null, int $timeoutInMs = 10000): array
    {
        $curl = curl_init(self::webDriverUrl() . $path);
        if ($curl === false) {
            throw new RuntimeException('Could not initialize cURL.');
        }

        $options = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_CONNECTTIMEOUT_MS => 2000,
            CURLOPT_TIMEOUT_MS => $timeoutInMs,
        ];

        if ($payload !== null) {
            $options[CURLOPT_HTTPHEADER] = ['Content-Type: application/json'];
            $options[CURLOPT_POSTFIELDS] = json_encode($payload, JSON_THROW_ON_ERROR);
        }

        curl_setopt_array($curl, $options);
        $responseBody = curl_exec($curl);
        $httpStatus = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $error = curl_error($curl);
        curl_close($curl);

        if ($responseBody === false) {
            throw new RuntimeException($error);
        }

        $response = json_decode((string) $responseBody, true);
        if (!is_array($response)) {
            throw new RuntimeException('WebDriver returned an invalid JSON response.');
        }

        $webdriverError = $response['value']['error'] ?? null;
        if ($httpStatus >= 400 || $webdriverError !== null) {
            $message = $response['value']['message'] ?? 'WebDriver request failed with HTTP status ' . $httpStatus . '.';
            throw new RuntimeException((string) $message);
        }

        return $response;
    }
}
