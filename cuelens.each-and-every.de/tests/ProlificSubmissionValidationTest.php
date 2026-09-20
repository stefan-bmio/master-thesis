<?php
declare(strict_types=1);

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/prolific-submission-validation.php';

final class ProlificSubmissionValidationTest extends TestCase
{
    private const PARTICIPANT_ID = 'AbCdEf1234567890GhIjKlMn';
    private const STUDY_ID = '0123456789abcdef01234567';

    public function testReportsOnlyMatchingSubmissionStatusesAndResetsBetweenCalls(): void
    {
        $statuses = ['stale'];
        $transport = static fn (): ProlificHttpResponse => self::response([
            self::submission('000000000000000000000000', 'APPROVED'),
            self::submission(self::PARTICIPANT_ID, 'REJECTED'),
            self::submission(self::PARTICIPANT_ID, 'SCREENED OUT'),
            self::submission(self::PARTICIPANT_ID, 'REJECTED'),
        ]);
        self::assertFalse(prolific_participant_has_eligible_submission($this->config(), self::PARTICIPANT_ID, $transport, $statuses));
        self::assertSame(['REJECTED', 'SCREENED OUT'], $statuses);
        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(), self::PARTICIPANT_ID, static fn () => self::response([]), $statuses
        ));
        self::assertSame([], $statuses);
    }

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
        yield 'awaiting review as displayed' => ['Awaiting Review'];
        yield 'awaiting review with whitespace' => ['  awaiting review  '];
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

    public function testFindsAwaitingReviewAfterTwentyEntriesAndAnIneligibleMatch(): void
    {
        $requests = 0;
        $results = [self::submission(self::PARTICIPANT_ID, 'REJECTED')];
        for ($index = 1; $index < 40; $index++) {
            $results[] = self::submission(str_pad((string) $index, 24, 'x'), 'APPROVED');
        }
        $results[] = self::submission(self::PARTICIPANT_ID, 'Awaiting Review');

        $transport = static function () use (&$requests, $results): ProlificHttpResponse {
            $requests++;
            return self::response($results);
        };

        self::assertTrue(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
        self::assertSame(1, $requests);
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

        self::assertSame('https://api.prolific.com/api/v1/studies/' . self::STUDY_ID . '/submissions/', $seenUrl);
        self::assertStringNotContainsString('test-api-token', $seenUrl);
        self::assertContains('Authorization: Token test-api-token', $seenHeaders);
        self::assertNull(parse_url($seenUrl, PHP_URL_QUERY));
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

    #[DataProvider('submissionCountProvider')]
    public function testMissingParticipantNeedsNoRequestBeyondTheResults(int $count): void
    {
        $results = [];
        for ($index = 0; $index < $count; $index++) {
            $results[] = self::submission(str_pad((string) $index, 24, 'x'), 'APPROVED');
        }
        $requests = 0;
        $transport = static function () use (&$requests, $results): ProlificHttpResponse {
            $requests++;
            return self::response($results);
        };

        self::assertFalse(prolific_participant_has_eligible_submission(
            $this->config(),
            self::PARTICIPANT_ID,
            $transport
        ));
        self::assertSame(1, $requests);
    }

    public static function submissionCountProvider(): iterable
    {
        foreach ([0, 20, 40, 41] as $count) {
            yield (string) $count => [$count];
        }
    }

    public function testTransportRejectsOtherHostsPathsAndQueriesBeforeSendingCredentials(): void
    {
        foreach ([
            'https://api.prolific.com.evil.example/api/v1/studies/' . self::STUDY_ID . '/submissions/',
            'https://api.prolific.com/api/v1/submissions/?study=' . self::STUDY_ID,
            'https://api.prolific.com/api/v1/studies/' . self::STUDY_ID . '/submissions/?page=2',
        ] as $url) {
            try {
                prolific_https_get($url, ['Authorization: Token test-token']);
                self::fail('Unexpected URL accepted.');
            } catch (ProlificApiException $error) {
                self::assertSame('Invalid Prolific API request URL.', $error->getMessage());
            }
        }
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
