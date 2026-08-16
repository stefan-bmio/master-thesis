import Foundation
import XCTest
@testable import CueLens

final class HTTPClientTests: XCTestCase {
    func testWritesDataMinimizingHeadersMethodAndBody() async throws {
        let url = uniqueHTTPSURL()
        let body = Data(#"{"value":"Grüße"}"#.utf8)
        URLProtocolStub.register(.init(body: Data(#"{"ok":true}"#.utf8)), for: url)
        let client = makeHTTPClient()

        _ = try await client.execute(
            HTTPRequest(
                kind: .activationRequest,
                url: url,
                method: .put,
                body: body,
                statusExpectation: .exact(200),
                responsePolicy: .json(maximumBytes: 1_024)
            )
        )

        let request = try XCTUnwrap(URLProtocolStub.recordedRequests(for: url).first)
        XCTAssertEqual(request.httpMethod, "PUT")
        let recordedBody = try XCTUnwrap(URLProtocolStub.recordedRequestBodies(for: url).first)
        XCTAssertEqual(recordedBody, body)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=UTF-8")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json, */*;q=0.8")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Charset"), "UTF-8, *;q=0.5")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "de, en;q=0.8, *;q=0.5")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "identity")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "CueLens/1.0.0")
        XCTAssertFalse(request.allHTTPHeaderFields?.values.contains(where: { $0.contains("iOS") }) == true)
    }

    func testGetOmitsContentTypeAndBody() async throws {
        let url = uniqueHTTPSURL()
        URLProtocolStub.register(.init(body: Data(#"{"features":{}}"#.utf8)), for: url)

        _ = try await makeHTTPClient().execute(
            HTTPRequest(
                kind: .features,
                url: url,
                method: .get,
                body: nil,
                statusExpectation: .exact(200),
                responsePolicy: .json(maximumBytes: 1_024)
            )
        )

        let request = try XCTUnwrap(URLProtocolStub.recordedRequests(for: url).first)
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testMapsUnexpectedHTTPStatusesWithoutReadingServerPayload() async {
        for statusCode in [400, 401, 404, 405, 429, 500] {
            let url = uniqueHTTPSURL(path: "/status-\(statusCode)")
            URLProtocolStub.register(
                .init(statusCode: statusCode, body: Data("sensitive-server-text".utf8)),
                for: url
            )
            await assertNetworkError(.httpStatus(statusCode)) {
                _ = try await self.jsonRequest(to: url)
            }
        }
    }

    func testRequiresJSONContentTypeOnlyForJSONResponses() async throws {
        for headers in [[:], ["Content-Type": "text/plain"]] {
            let url = uniqueHTTPSURL()
            URLProtocolStub.register(.init(headers: headers, body: Data("{}".utf8)), for: url)
            await assertNetworkError(.invalidContentType) {
                _ = try await self.jsonRequest(to: url)
            }
        }

        let emptyURL = uniqueHTTPSURL()
        URLProtocolStub.register(.init(statusCode: 204, headers: [:]), for: emptyURL)
        _ = try await makeHTTPClient().execute(emptyRequest(to: emptyURL))
    }

    func testEnforcesStreamingResponseLimitAtBoundary() async throws {
        let acceptedURL = uniqueHTTPSURL()
        URLProtocolStub.register(.init(body: Data("1234".utf8)), for: acceptedURL)
        let accepted = try await makeHTTPClient().execute(
            jsonRequestDefinition(to: acceptedURL, maximumBytes: 4)
        )
        XCTAssertEqual(accepted.body, Data("1234".utf8))

        let rejectedURL = uniqueHTTPSURL()
        URLProtocolStub.register(.init(body: Data("12345".utf8)), for: rejectedURL)
        await assertNetworkError(.bodyTooLarge) {
            _ = try await makeHTTPClient().execute(
                self.jsonRequestDefinition(to: rejectedURL, maximumBytes: 4)
            )
        }
    }

    func testRejectsBodyForNoContentContract() async {
        let url = uniqueHTTPSURL()
        URLProtocolStub.register(.init(statusCode: 204, body: Data("x".utf8)), for: url)
        await assertNetworkError(.protocolViolation) {
            _ = try await makeHTTPClient().execute(self.emptyRequest(to: url))
        }
    }

    func testMapsTransportErrors() async {
        let cases: [(URLError.Code, NetworkError)] = [
            (.notConnectedToInternet, .offline),
            (.networkConnectionLost, .offline),
            (.timedOut, .timedOut),
            (.cancelled, .cancelled),
            (.serverCertificateUntrusted, .invalidTLS),
            (.cannotConnectToHost, .transportFailure)
        ]
        for (code, expected) in cases {
            let url = uniqueHTTPSURL()
            URLProtocolStub.register(.init(error: URLError(code)), for: url)
            await assertNetworkError(expected) {
                _ = try await self.jsonRequest(to: url)
            }
        }
    }

    func testRejectsRedirectAndRecordsOnlyRedactedFailureShape() async throws {
        let url = uniqueHTTPSURL()
        let logger = RecordingNetworkLogger()
        URLProtocolStub.register(
            .init(
                statusCode: 302,
                headers: ["Location": "http://other.invalid/leak"],
                body: Data("token=forbidden".utf8)
            ),
            for: url
        )
        await assertNetworkError(.redirectRejected) {
            _ = try await makeHTTPClient(logger: logger).execute(self.jsonRequestDefinition(to: url))
        }

        let events = await logger.events
        XCTAssertEqual(
            events,
            [NetworkFailureEvent(request: .messages, statusCode: 302, error: .redirectRejected)]
        )
    }

    func testRejectsUnsafeRequestURLBeforeTransport() async {
        let values = [
            "http://example.invalid/messages",
            "https://user@example.invalid/messages",
            "https://example.invalid/messages?token=forbidden",
            "https://example.invalid/messages#fragment"
        ]
        for value in values {
            let url = URL(string: value) ?? URL(fileURLWithPath: "/invalid")
            await assertNetworkError(.invalidConfiguration) {
                _ = try await makeHTTPClient().execute(self.jsonRequestDefinition(to: url))
            }
        }
    }

    private func jsonRequest(to url: URL) async throws -> HTTPResponse {
        try await makeHTTPClient().execute(jsonRequestDefinition(to: url))
    }

    private func jsonRequestDefinition(
        to url: URL,
        maximumBytes: Int = 1_024
    ) -> HTTPRequest {
        HTTPRequest(
            kind: .messages,
            url: url,
            method: .get,
            body: nil,
            statusExpectation: .exact(200),
            responsePolicy: .json(maximumBytes: maximumBytes)
        )
    }

    private func emptyRequest(to url: URL) -> HTTPRequest {
        HTTPRequest(
            kind: .activationConfirmation,
            url: url,
            method: .put,
            body: Data("{}".utf8),
            statusExpectation: .exact(204),
            responsePolicy: .empty(maximumBytes: 1_024)
        )
    }
}
