import Foundation
import XCTest
@testable import CueLens

actor StubHTTPClient: HTTPClienting {
    private var results: [Result<HTTPResponse, NetworkError>]
    private(set) var requests: [HTTPRequest] = []

    init(results: [Result<HTTPResponse, NetworkError>]) {
        self.results = results
    }

    init(response: HTTPResponse) {
        results = [.success(response)]
    }

    init(error: NetworkError) {
        results = [.failure(error)]
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !results.isEmpty else { throw NetworkError.transportFailure }
        return try results.removeFirst().get()
    }
}

actor RecordingNetworkLogger: NetworkEventLogging {
    private(set) var events: [NetworkFailureEvent] = []

    func logFailure(_ event: NetworkFailureEvent) async {
        events.append(event)
    }
}

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        let error: URLError?

        init(
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "application/json; charset=utf-8"],
            body: Data = Data(),
            error: URLError? = nil
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.error = error
        }
    }

    nonisolated(unsafe) private static var responses: [URL: Response] = [:]
    nonisolated(unsafe) private static var requests: [URL: [URLRequest]] = [:]
    nonisolated(unsafe) private static var requestBodies: [URL: [Data?]] = [:]
    private static let lock = NSLock()

    static func register(_ response: Response, for url: URL) {
        lock.withLock {
            responses[url] = response
            requests[url] = []
            requestBodies[url] = []
        }
    }

    static func recordedRequests(for url: URL) -> [URLRequest] {
        lock.withLock { requests[url] ?? [] }
    }

    static func recordedRequestBodies(for url: URL) -> [Data?] {
        lock.withLock { requestBodies[url] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = Self.readBody(from: request)
        let response = Self.lock.withLock { () -> Response? in
            Self.requests[url, default: []].append(request)
            Self.requestBodies[url, default: []].append(body)
            return Self.responses[url]
        }
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if !response.body.isEmpty {
            client?.urlProtocol(self, didLoad: response.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

func makeHTTPClient(
    logger: any NetworkEventLogging = NoOpNetworkEventLogger()
) -> URLSessionHTTPClient {
    let configuration = URLSessionHTTPClient.ephemeralConfiguration()
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSessionHTTPClient(
        appVersion: "1.0.0",
        configuration: configuration,
        logger: logger
    )
}

func uniqueHTTPSURL(path: String = "/endpoint") -> URL {
    URL(string: "https://\(UUID().uuidString.lowercased()).invalid\(path)") ??
        URL(fileURLWithPath: "/invalid-test-url")
}

func assertNetworkError(
    _ expected: NetworkError,
    operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected network error.", file: file, line: line)
    } catch let error as NetworkError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error type: \(error)", file: file, line: line)
    }
}

func jsonObject(_ data: Data?, file: StaticString = #filePath, line: UInt = #line) throws
    -> [String: Any] {
    let body = try XCTUnwrap(data, file: file, line: line)
    return try XCTUnwrap(
        JSONSerialization.jsonObject(with: body) as? [String: Any],
        file: file,
        line: line
    )
}
