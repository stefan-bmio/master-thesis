import Foundation
import OSLog

enum NetworkRequestKind: String, Equatable, Sendable {
    case activationRequest
    case activationConfirmation
    case messages
    case features
    case feedback
    case selfReport
    case compensationConfirmation
}

struct NetworkFailureEvent: Equatable, Sendable {
    let request: NetworkRequestKind
    let statusCode: Int?
    let error: NetworkError
}

protocol NetworkEventLogging: Sendable {
    func logFailure(_ event: NetworkFailureEvent) async
}

struct SystemNetworkEventLogger: NetworkEventLogging {
    private let logger = Logger(subsystem: "de.eachandevery.cuelens", category: "Network")

    func logFailure(_ event: NetworkFailureEvent) async {
        logger.error(
            "Request failed: request=\(event.request.rawValue, privacy: .public), status=\(event.statusCode.map(String.init) ?? "none", privacy: .public), category=\(String(describing: event.error), privacy: .public)"
        )
    }
}

struct NoOpNetworkEventLogger: NetworkEventLogging {
    func logFailure(_ event: NetworkFailureEvent) async {}
}
