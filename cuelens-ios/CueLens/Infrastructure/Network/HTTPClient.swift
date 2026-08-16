import Foundation

private final class RedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

actor URLSessionHTTPClient: HTTPClienting {
    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 30

    private let session: URLSession
    private let redirectDelegate = RedirectRejectingDelegate()
    private let appVersion: String
    private let logger: any NetworkEventLogging

    init(
        appVersion: String,
        configuration: URLSessionConfiguration = URLSessionHTTPClient.ephemeralConfiguration(),
        logger: any NetworkEventLogging = SystemNetworkEventLogger()
    ) {
        self.appVersion = appVersion
        self.logger = logger
        session = URLSession(configuration: configuration)
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        var statusCode: Int?
        do {
            let urlRequest = try makeURLRequest(from: request)
            let (bytes, response) = try await session.bytes(
                for: urlRequest,
                delegate: redirectDelegate
            )
            guard let httpResponse = response as? HTTPURLResponse else {
                bytes.task.cancel()
                throw NetworkError.protocolViolation
            }
            statusCode = httpResponse.statusCode
            if (300...399).contains(httpResponse.statusCode) {
                bytes.task.cancel()
                throw NetworkError.redirectRejected
            }
            guard request.statusExpectation.accepts(httpResponse.statusCode) else {
                bytes.task.cancel()
                throw NetworkError.httpStatus(httpResponse.statusCode)
            }
            if case .json = request.responsePolicy,
               httpResponse.mimeType?.lowercased() != "application/json" {
                bytes.task.cancel()
                throw NetworkError.invalidContentType
            }
            if httpResponse.expectedContentLength > request.responsePolicy.maximumBytes {
                bytes.task.cancel()
                throw NetworkError.bodyTooLarge
            }

            let body = try await receive(bytes, policy: request.responsePolicy)
            return HTTPResponse(statusCode: httpResponse.statusCode, body: body)
        } catch {
            let networkError = NetworkError.map(error)
            await logger.logFailure(
                NetworkFailureEvent(
                    request: request.kind,
                    statusCode: statusCode,
                    error: networkError
                )
            )
            throw networkError
        }
    }

    static func ephemeralConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        return configuration
    }

    private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
        guard request.url.scheme?.lowercased() == "https",
              request.url.host?.isEmpty == false,
              request.url.user == nil,
              request.url.password == nil,
              request.url.query == nil,
              request.url.fragment == nil,
              appVersion.range(
                of: #"^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$"#,
                options: .regularExpression
              ) != nil else {
            throw NetworkError.invalidConfiguration
        }
        var urlRequest = URLRequest(
            url: request.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.requestTimeout
        )
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json, */*;q=0.8", forHTTPHeaderField: "Accept")
        urlRequest.setValue("UTF-8, *;q=0.5", forHTTPHeaderField: "Accept-Charset")
        urlRequest.setValue("de, en;q=0.8, *;q=0.5", forHTTPHeaderField: "Accept-Language")
        urlRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        urlRequest.setValue("CueLens/\(appVersion)", forHTTPHeaderField: "User-Agent")
        if request.body != nil {
            urlRequest.setValue(
                "application/json; charset=UTF-8",
                forHTTPHeaderField: "Content-Type"
            )
        }
        return urlRequest
    }

    private func receive(
        _ bytes: URLSession.AsyncBytes,
        policy: HTTPResponsePolicy
    ) async throws -> Data {
        var receivedCount = 0
        var data = Data()
        if case .json = policy {
            data.reserveCapacity(min(policy.maximumBytes, 16 * 1_024))
        }

        do {
            for try await byte in bytes {
                guard receivedCount < policy.maximumBytes else {
                    bytes.task.cancel()
                    throw NetworkError.bodyTooLarge
                }
                receivedCount += 1
                switch policy {
                case .empty:
                    bytes.task.cancel()
                    throw NetworkError.protocolViolation
                case .json:
                    data.append(byte)
                case .discard:
                    break
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.map(error)
        }
        return data
    }
}
