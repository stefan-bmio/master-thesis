import Foundation

enum NetworkTransportPolicy: Equatable, Sendable {
    case httpsOnly
    case httpsAndLocalHTTP

    func allows(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else {
            return false
        }
        let scheme = components.scheme?.lowercased()
        if scheme == "https" { return true }
        guard self == .httpsAndLocalHTTP, scheme == "http" else { return false }
        return host == "localhost" || host.hasSuffix(".local") || Self.isPrivateIPv4(host)
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        return octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
            || octets[0] == 127
    }
}

enum HTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

enum HTTPStatusExpectation: Equatable, Sendable {
    case exact(Int)
    case successful

    func accepts(_ statusCode: Int) -> Bool {
        switch self {
        case .exact(let expected):
            statusCode == expected
        case .successful:
            (200...299).contains(statusCode)
        }
    }
}

enum HTTPResponsePolicy: Equatable, Sendable {
    case json(maximumBytes: Int)
    case empty(maximumBytes: Int)
    case discard(maximumBytes: Int)

    var maximumBytes: Int {
        switch self {
        case .json(let maximumBytes), .empty(let maximumBytes),
             .discard(let maximumBytes):
            maximumBytes
        }
    }
}

struct HTTPRequest: Equatable, Sendable {
    let kind: NetworkRequestKind
    let url: URL
    let method: HTTPMethod
    let body: Data?
    let statusExpectation: HTTPStatusExpectation
    let responsePolicy: HTTPResponsePolicy
}

struct HTTPResponse: Equatable, Sendable {
    let statusCode: Int
    let body: Data
}

protocol HTTPClienting: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
