<?php
declare(strict_types=1);

/**
 * @param array<string, mixed> $signupConfig
 * @param array<string, mixed> $cravingConfig
 * @return array<string, string>
 */
function local_test_environment(array $signupConfig, array $cravingConfig): array
{
    foreach (['host', 'user', 'pass'] as $key) {
        if (!isset($signupConfig[$key]) || !is_string($signupConfig[$key]) || $signupConfig[$key] === '') {
            throw new RuntimeException('Incomplete signup database configuration.');
        }
        if (!isset($cravingConfig[$key]) || !is_string($cravingConfig[$key]) || $cravingConfig[$key] === '') {
            throw new RuntimeException('Incomplete craving database configuration.');
        }
    }

    return [
        'CUELENS_TEST_DB_HOST' => $signupConfig['host'],
        'CUELENS_TEST_DB_NAME' => 'cuelens_signup_test',
        'CUELENS_TEST_DB_USER' => $signupConfig['user'],
        'CUELENS_TEST_DB_PASS' => $signupConfig['pass'],
        'CUELENS_TEST_CRAVING_DB_HOST' => $cravingConfig['host'],
        'CUELENS_TEST_CRAVING_DB_NAME' => 'cuelens_craving_test',
        'CUELENS_TEST_CRAVING_DB_USER' => $cravingConfig['user'],
        'CUELENS_TEST_CRAVING_DB_PASS' => $cravingConfig['pass'],
    ];
}
