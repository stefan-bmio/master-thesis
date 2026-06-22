<?php

declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\PreserveGlobalState;
use PHPUnit\Framework\Attributes\RunInSeparateProcess;
use PHPUnit\Framework\TestCase;

final class GetRequestTest extends TestCase
{
    /**
     * @return array<string, array{string}>
     */
    public static function formPageProvider(): array
    {
        return [
            'German registration form' => ['index-de.php'],
            'English registration form' => ['index-en.php'],
        ];
    }

    #[DataProvider('formPageProvider')]
    #[RunInSeparateProcess]
    #[PreserveGlobalState(false)]
    public function testRegistrationFormGetRequestDoesNotRequireDatabase(string $page): void
    {
        $_GET = [];
        $_POST = [];
        $_REQUEST = [];
        $_SERVER['REQUEST_METHOD'] = 'GET';

        ob_start();
        require __DIR__ . '/../' . $page;
        $output = ob_get_clean();

        $statusCode = http_response_code();
        if ($statusCode === false) {
            $statusCode = 200;
        }

        self::assertNotSame(500, $statusCode);
        self::assertStringNotContainsString('Database error', $output);
        self::assertStringContainsString('<form method="post" action="">', $output);
    }
}
