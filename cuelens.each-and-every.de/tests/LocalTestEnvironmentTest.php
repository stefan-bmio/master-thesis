<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/local-test-environment.php';

final class LocalTestEnvironmentTest extends TestCase
{
    public function testBuildsSeparateDatabaseEnvironmentFromProtectedConfigs(): void
    {
        $environment = local_test_environment(
            ['host' => '127.0.0.1', 'user' => 'signup-user', 'pass' => 'signup-pass'],
            ['host' => '127.0.0.2', 'user' => 'craving-user', 'pass' => 'craving-pass']
        );

        self::assertSame('127.0.0.1', $environment['CUELENS_TEST_DB_HOST']);
        self::assertSame('cuelens_signup_test', $environment['CUELENS_TEST_DB_NAME']);
        self::assertSame('signup-user', $environment['CUELENS_TEST_DB_USER']);
        self::assertSame('signup-pass', $environment['CUELENS_TEST_DB_PASS']);
        self::assertSame('127.0.0.2', $environment['CUELENS_TEST_CRAVING_DB_HOST']);
        self::assertSame('cuelens_craving_test', $environment['CUELENS_TEST_CRAVING_DB_NAME']);
        self::assertSame('craving-user', $environment['CUELENS_TEST_CRAVING_DB_USER']);
        self::assertSame('craving-pass', $environment['CUELENS_TEST_CRAVING_DB_PASS']);
    }

    public function testRejectsIncompleteProtectedConfiguration(): void
    {
        $this->expectException(RuntimeException::class);

        local_test_environment(
            ['host' => '127.0.0.1', 'user' => 'signup-user'],
            ['host' => '127.0.0.2', 'user' => 'craving-user', 'pass' => 'craving-pass']
        );
    }
}
