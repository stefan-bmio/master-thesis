<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/local-test-environment.php';

$configurationDirectory = getenv('CUELENS_DEPLOY_CONFIG_DIR') ?: '/var/www/html/cuelens/config';
try {
    $signupConfig = require $configurationDirectory . '/cuelens-signup.php';
    $cravingConfig = require $configurationDirectory . '/cuelens-craving.php';
    if (!is_array($signupConfig) || !is_array($cravingConfig)) {
        throw new RuntimeException('Invalid protected database configuration.');
    }
    foreach (local_test_environment($signupConfig, $cravingConfig) as $key => $value) {
        putenv($key . '=' . $value);
    }
} catch (Throwable $error) {
    fwrite(STDERR, 'Could not configure isolated test databases: ' . $error->getMessage() . PHP_EOL);
    exit(2);
}

$command = escapeshellarg(PHP_BINARY)
    . ' ./vendor/bin/phpunit --do-not-cache-result tests';
passthru($command, $status);
exit($status);
