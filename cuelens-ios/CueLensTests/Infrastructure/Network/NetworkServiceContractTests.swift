import Foundation
import XCTest
@testable import CueLens

final class NetworkServiceContractTests: XCTestCase {
    private let tokenText = "123e4567-e89b-42d3-a456-426614174000"

    func testActivationRequestUsesExactContractAndDecodesUUIDv4Fixture() async throws {
        let responseData = try FixtureLoader.data(directory: "activation", name: "valid-token.json")
        let client = StubHTTPClient(
            response: HTTPResponse(statusCode: 200, body: responseData)
        )
        let endpoint = uniqueHTTPSURL(path: "/activate.php")
        let service = ActivationService(endpoint: endpoint, client: client)
        let identifier = try ParticipantIdentifier.parse("person@example.org")

        let token = try await service.requestToken(identifier: identifier)

        XCTAssertEqual(token.description, tokenText)
        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.statusExpectation, .exact(200))
        XCTAssertEqual(request.responsePolicy, .json(maximumBytes: 8 * 1_024))
        let payload = try jsonObject(request.body)
        XCTAssertEqual(Set(payload.keys), ["identifier"])
        XCTAssertEqual(payload["identifier"] as? String, "person@example.org")
    }

    func testActivationRejectsMalformedInvalidAndAdditionalResponseFields() async throws {
        let fixtures = ["invalid-token.json", "invalid-extra-field.json"]
        for fixture in fixtures {
            let data = try FixtureLoader.data(directory: "activation", name: fixture)
            let service = ActivationService(
                endpoint: uniqueHTTPSURL(),
                client: StubHTTPClient(response: HTTPResponse(statusCode: 200, body: data))
            )
            let identifier = try ParticipantIdentifier.parse("person@example.org")
            await assertNetworkError(.protocolViolation) {
                _ = try await service.requestToken(identifier: identifier)
            }
        }

        let malformedService = ActivationService(
            endpoint: uniqueHTTPSURL(),
            client: StubHTTPClient(
                response: HTTPResponse(statusCode: 200, body: Data("not-json".utf8))
            )
        )
        let identifier = try ParticipantIdentifier.parse("person@example.org")
        await assertNetworkError(.malformedJSON) {
            _ = try await malformedService.requestToken(identifier: identifier)
        }
    }

    func testActivationConfirmationUsesOnlyIdentifierAndToken() async throws {
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 204, body: Data()))
        let service = ActivationService(endpoint: uniqueHTTPSURL(), client: client)
        let identifier = try ParticipantIdentifier.parse("ABCDEFGHIJKLMNOPQRSTUVWX")
        let token = try UUIDv4(tokenText)

        try await service.confirmToken(identifier: identifier, token: token)

        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.kind, .activationConfirmation)
        XCTAssertEqual(request.statusExpectation, .exact(204))
        XCTAssertEqual(request.responsePolicy, .empty(maximumBytes: 8 * 1_024))
        let payload = try jsonObject(request.body)
        XCTAssertEqual(Set(payload.keys), ["identifier", "app_token"])
        XCTAssertEqual(payload["identifier"] as? String, "ABCDEFGHIJKLMNOPQRSTUVWX")
        XCTAssertEqual(payload["app_token"] as? String, tokenText)
    }

    func testInfoFeedUsesGETAndExistingStrictDomainDecoder() async throws {
        let data = try FixtureLoader.data(directory: "messages", name: "valid-messages.json")
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 200, body: data))
        let endpoint = uniqueHTTPSURL(path: "/messages.php")
        let service = InfoFeedService(endpoint: endpoint, client: client)

        let messages = try await service.fetchMessages()

        XCTAssertFalse(messages.isEmpty)
        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.method, .get)
        XCTAssertNil(request.body)
        XCTAssertEqual(request.responsePolicy, .json(maximumBytes: 512 * 1_024))
    }

    func testInfoFeedMapsSchemaFailureToProtocolViolationAndSyntaxToMalformedJSON() async throws {
        let invalid = try FixtureLoader.data(directory: "messages", name: "invalid-extra-field.json")
        let invalidService = InfoFeedService(
            endpoint: uniqueHTTPSURL(),
            client: StubHTTPClient(response: HTTPResponse(statusCode: 200, body: invalid))
        )
        await assertNetworkError(.protocolViolation) {
            _ = try await invalidService.fetchMessages()
        }

        let malformedService = InfoFeedService(
            endpoint: uniqueHTTPSURL(),
            client: StubHTTPClient(
                response: HTTPResponse(statusCode: 200, body: Data("{".utf8))
            )
        )
        await assertNetworkError(.malformedJSON) {
            _ = try await malformedService.fetchMessages()
        }
    }

    func testFeatureConfigOnlyExplicitBooleanTrueEnablesStudy() async throws {
        for (fixture, expected) in [
            ("enabled.json", true),
            ("disabled.json", false),
            ("invalid-type.json", false),
            ("invalid-extra-field.json", false)
        ] {
            let data = try FixtureLoader.data(directory: "features", name: fixture)
            let service = FeatureConfigService(
                endpoint: uniqueHTTPSURL(),
                client: StubHTTPClient(response: HTTPResponse(statusCode: 200, body: data))
            )
            let actual = await service.isNextStudyRunEnabled()
            XCTAssertEqual(actual, expected)
        }

        let failingService = FeatureConfigService(
            endpoint: uniqueHTTPSURL(),
            client: StubHTTPClient(error: .timedOut)
        )
        let enabledAfterFailure = await failingService.isNextStudyRunEnabled()
        XCTAssertFalse(enabledAfterFailure)
    }

    func testFeedbackOmitsAbsentFieldAndSendsNoIdentityOrPlatformData() async throws {
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 204, body: Data()))
        let endpoint = uniqueHTTPSURL(path: "/feedback.php")
        let service = FeedbackService(endpoint: endpoint, client: client)

        try await service.submit(
            source: nil,
            comment: "  Verständlich 👍  ",
            appVersion: "1.0.0"
        )

        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.statusExpectation, .successful)
        XCTAssertEqual(request.responsePolicy, .discard(maximumBytes: 8 * 1_024))
        let payload = try jsonObject(request.body)
        XCTAssertEqual(Set(payload.keys), ["comment", "app_version"])
        XCTAssertEqual(payload["comment"] as? String, "Verständlich 👍")
        XCTAssertEqual(payload["app_version"] as? String, "1.0.0")
        for forbidden in ["app_token", "platform", "os_version", "device_model"] {
            XCTAssertNil(payload[forbidden])
        }
    }

    func testFeedbackValidatesContentAndVersionBeforeTransport() async {
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 204, body: Data()))
        let service = FeedbackService(endpoint: uniqueHTTPSURL(), client: client)
        await assertNetworkError(.protocolViolation) {
            try await service.submit(source: nil, comment: nil, appVersion: "1.0.0")
        }
        await assertNetworkError(.protocolViolation) {
            try await service.submit(source: "source", comment: nil, appVersion: "bad version")
        }
        let requests = await client.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testSelfReportUsesMinimalPayloadAndStrictExistingDecoder() async throws {
        let data = try FixtureLoader.data(directory: "submission", name: "next-matching.json")
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 200, body: data))
        let endpoint = uniqueHTTPSURL(path: "/submit.php")
        let service = StudySubmissionService(endpoint: endpoint, client: client)
        let token = try UUIDv4(tokenText)

        let response = try await service.submitSelfReport(
            token: token,
            craving: 63,
            appVersion: "1.0.0",
            expectedSituation: SituationNumber(1)
        )

        XCTAssertEqual(response, .next(situation: try SituationNumber(1)))
        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.responsePolicy, .json(maximumBytes: 16 * 1_024))
        let payload = try jsonObject(request.body)
        XCTAssertEqual(Set(payload.keys), ["app_token", "craving", "app_version"])
        XCTAssertEqual(payload["app_token"] as? String, tokenText)
        XCTAssertEqual(payload["craving"] as? Int, 63)
        XCTAssertEqual(payload["app_version"] as? String, "1.0.0")
    }

    func testSelfReportRejectsInvalidInputAndUnexpectedSituation() async throws {
        let data = try FixtureLoader.data(directory: "submission", name: "next-matching.json")
        let invalidCravingClient = StubHTTPClient(
            response: HTTPResponse(statusCode: 200, body: data)
        )
        let invalidCravingService = StudySubmissionService(
            endpoint: uniqueHTTPSURL(),
            client: invalidCravingClient
        )
        let token = try UUIDv4(tokenText)
        await assertNetworkError(.protocolViolation) {
            _ = try await invalidCravingService.submitSelfReport(
                token: token,
                craving: 101,
                appVersion: "1.0.0",
                expectedSituation: SituationNumber(1)
            )
        }
        let invalidCravingRequests = await invalidCravingClient.requests
        XCTAssertTrue(invalidCravingRequests.isEmpty)

        let mismatchService = StudySubmissionService(
            endpoint: uniqueHTTPSURL(),
            client: StubHTTPClient(response: HTTPResponse(statusCode: 200, body: data))
        )
        await assertNetworkError(.protocolViolation) {
            _ = try await mismatchService.submitSelfReport(
                token: token,
                craving: 50,
                appVersion: "1.0.0",
                expectedSituation: SituationNumber(2)
            )
        }
    }

    func testCompensationConfirmationSendsOnlyCodeAndRequiresNoContent() async throws {
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 204, body: Data()))
        let service = StudySubmissionService(endpoint: uniqueHTTPSURL(), client: client)
        let code = try UUIDv4(tokenText)

        try await service.confirmCompensation(code: code)

        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.kind, .compensationConfirmation)
        XCTAssertEqual(request.statusExpectation, .exact(204))
        XCTAssertEqual(request.responsePolicy, .empty(maximumBytes: 8 * 1_024))
        let payload = try jsonObject(request.body)
        XCTAssertEqual(Set(payload.keys), ["compensation_code"])
        XCTAssertEqual(payload["compensation_code"] as? String, tokenText)
    }

    func testFeedbackFixtureMatchesEncodedContract() async throws {
        let expected = try FixtureLoader.data(directory: "feedback", name: "valid-request.json")
        let client = StubHTTPClient(response: HTTPResponse(statusCode: 204, body: Data()))
        let service = FeedbackService(endpoint: uniqueHTTPSURL(), client: client)

        try await service.submit(
            source: "Flyer in einer Praxis",
            comment: "Die Darstellung war verständlich.",
            appVersion: "1.0.0"
        )

        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(try jsonObject(request.body) as NSDictionary,
                       try jsonObject(expected) as NSDictionary)
    }
}
