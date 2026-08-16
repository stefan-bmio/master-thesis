import Foundation

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
