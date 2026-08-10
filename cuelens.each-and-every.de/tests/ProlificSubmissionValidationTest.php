<?php
declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/prolific-submission-validation.php';

final class ProlificSubmissionValidationTest extends TestCase
{
    private const PARTICIPANT_ID = 'AbCdEf1234567890GhIjKlMn';
    private const STUDY_ID = '0123456789abcdef01234567';

    #[DataProvider('eligibleStatusProvider')]
    public function testAcceptsConfiguredEligibleStatusesAndApiSeparators(string $status): void
    {
        $transport = static fn (): ProlificHttpResponse => self::response([
            self::submission(self::PARTICIPANT_ID, $status),
        ]);

        self::assertTrue(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
    }

    /** @return iterable<string, array{string}> */
    public static function eligibleStatusProvider(): iterable
    {
        yield 'active' => ['ACTIVE'];
        yield 'awaiting review with underscore' => ['AWAITING_REVIEW'];
        yield 'awaiting review with API space' => ['AWAITING REVIEW'];
        yield 'approved' => ['APPROVED'];
        yield 'timed out with underscore' => ['TIMED_OUT'];
        yield 'timed out with API hyphen' => ['TIMED-OUT'];
        yield 'returned' => ['RETURNED'];
    }

    #[DataProvider('ineligibleStatusProvider')]
    public function testRejectsSubmissionStatusesOutsideTheWhitelist(string $status): void
    {
        $transport = static fn (): ProlificHttpResponse => self::response([
            self::submission(self::PARTICIPANT_ID, $status),
        ]);

        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
    }

    /** @return iterable<string, array{string}> */
    public static function ineligibleStatusProvider(): iterable
    {
        yield 'rejected' => ['REJECTED'];
        yield 'screened out' => ['SCREENED_OUT'];
        yield 'reserved' => ['RESERVED'];
    }

    public function testReadsEveryPageAndKeepsLookingAfterAnIneligibleMatch(): void
    {
        $requestedPages = [];
        $firstPage = [self::submission(self::PARTICIPANT_ID, 'REJECTED')];
        for ($index = 1; $index < PROLIFIC_SUBMISSIONS_PAGE_SIZE; $index++) {
            $firstPage[] = self::submission(str_pad((string) $index, 24, 'x'), 'APPROVED');
        }

        $transport = static function (string $url, array $headers) use (&$requestedPages, $firstPage): ProlificHttpResponse {
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);
            $requestedPages[] = (int) ($query['page'] ?? 0);
            if (($query['page'] ?? null) === '1') {
                return self::response($firstPage);
            }
            return self::response([self::submission(self::PARTICIPANT_ID, 'ACTIVE')]);
        };

        self::assertTrue(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
        self::assertSame([1, 2], $requestedPages);
    }

    public function testReturnsFalseOnlyAfterACompleteSuccessfulSearch(): void
    {
        $transport = static fn (): ProlificHttpResponse => self::response([
            self::submission('000000000000000000000000', 'APPROVED'),
        ]);

        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
    }

    public function testMatchesParticipantIdsCaseSensitively(): void
    {
        $transport = static fn (): ProlificHttpResponse => self::response([
            self::submission(strtolower(self::PARTICIPANT_ID), 'APPROVED'),
        ]);

        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
    }

    public function testSendsTheTokenOnlyInTheAuthorizationHeader(): void
    {
        $seenUrl = '';
        $seenHeaders = [];
        $transport = static function (string $url, array $headers) use (&$seenUrl, &$seenHeaders): ProlificHttpResponse {
            $seenUrl = $url;
            $seenHeaders = $headers;
            return self::response([]);
        };

        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));

        self::assertStringStartsWith(PROLIFIC_SUBMISSIONS_ENDPOINT . '?', $seenUrl);
        self::assertStringNotContainsString('test-api-token', $seenUrl);
        self::assertContains('Authorization: Token test-api-token', $seenHeaders);
        parse_str((string) parse_url($seenUrl, PHP_URL_QUERY), $query);
        self::assertSame(self::STUDY_ID, $query['study'] ?? null);
        self::assertSame((string) PROLIFIC_SUBMISSIONS_PAGE_SIZE, $query['page_size'] ?? null);
        self::assertSame('1', $query['page'] ?? null);
    }

    #[DataProvider('httpFailureProvider')]
    public function testTreatsEveryNonSuccessHttpStatusAsTechnicalFailure(int $statusCode): void
    {
        $transport = static fn (): ProlificHttpResponse => new ProlificHttpResponse($statusCode, '{}');

        $this->expectException(ProlificApiException::class);
        prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        );
    }

    /** @return iterable<string, array{int}> */
    public static function httpFailureProvider(): iterable
    {
        yield 'bad request' => [400];
        yield 'unauthorized' => [401];
        yield 'forbidden' => [403];
        yield 'not found' => [404];
        yield 'rate limited' => [429];
        yield 'server error' => [500];
    }

    #[DataProvider('invalidResponseProvider')]
    public function testTreatsMalformedResponsesAsTechnicalFailure(string $body): void
    {
        $transport = static fn (): ProlificHttpResponse => new ProlificHttpResponse(200, $body);

        $this->expectException(ProlificApiException::class);
        prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        );
    }

    /** @return iterable<string, array{string}> */
    public static function invalidResponseProvider(): iterable
    {
        yield 'invalid JSON' => ['not-json'];
        yield 'missing results' => ['{}'];
        yield 'results is not a list' => ['{"results":{"item":{}}}'];
        yield 'submission missing status' => ['{"results":[{"participant_id":"abc"}]}'];
        yield 'submission has wrong field type' => ['{"results":[{"participant_id":1,"status":"ACTIVE"}]}'];
    }

    public function testTreatsTransportFailuresAsTechnicalFailuresWithoutRetainingTheirMessage(): void
    {
        $transport = static function (): never {
            throw new RuntimeException('sensitive upstream detail');
        };

        try {
            prolific_participant_has_eligible_submission(
                $this->config(),
                self::PARTICIPANT_ID,
                $transport
            );
            self::fail('Transport failure must be reported.');
        } catch (ProlificApiException $error) {
            self::assertStringNotContainsString('sensitive upstream detail', (string) $error);
            self::assertNull($error->getPrevious());
        }
    }

    public function testRejectsMissingOrHeaderInjectingConfigurationBeforeTransport(): void
    {
        $transportCalled = false;
        $transport = static function () use (&$transportCalled): ProlificHttpResponse {
            $transportCalled = true;
            return self::response([]);
        };

        foreach ([
            [],
            ['prolific_token' => "token\r\nInjected: value", 'prolific_study_id' => self::STUDY_ID],
            ['prolific_token' => 'token', 'prolific_study_id' => 'not-a-study-id'],
        ] as $config) {
            try {
                prolific_participant_has_eligible_submission(
                    $config,
                    self::PARTICIPANT_ID,
                    $transport
                );
                self::fail('Invalid configuration must fail closed.');
            } catch (ProlificApiException) {
                // Expected.
            }
        }

        self::assertFalse($transportCalled);
    }

    public function testStopsIfPaginationDoesNotAdvance(): void
    {
        $fullPage = [];
        for ($index = 0; $index < PROLIFIC_SUBMISSIONS_PAGE_SIZE; $index++) {
            $fullPage[] = self::submission(str_pad((string) $index, 24, 'x'), 'APPROVED');
        }
        $transport = static fn (): ProlificHttpResponse => self::response($fullPage);

        $this->expectException(ProlificApiException::class);
        prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        );
    }

    /** @return array{prolific_token: string, prolific_study_id: string} */
    private function config(): array
    {
        return [
            'prolific_token' => 'test-api-token',
            'prolific_study_id' => self::STUDY_ID,
        ];
    }

    /** @return array{participant_id: string, status: string} */
    private static function submission(string $participantId, string $status): array
    {
        return [
            'participant_id' => $participantId,
            'status' => $status,
        ];
    }

    /** @param list<array{participant_id: string, status: string}> $results */
    private static function response(array $results): ProlificHttpResponse
    {
        return new ProlificHttpResponse(
            200,
            json_encode(['results' => $results], JSON_THROW_ON_ERROR)
        );
    }
}
