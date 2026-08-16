import Foundation

enum NetworkError: Error, Equatable, Sendable {
    case invalidConfiguration
    case offline
    case timedOut
    case cancelled
    case redirectRejected
    case invalidTLS
    case transportFailure
    case httpStatus(Int)
    case invalidContentType
    case bodyTooLarge
    case malformedJSON
    case protocolViolation
}

extension NetworkError {
    static func map(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        guard let urlError = error as? URLError else {
            return .transportFailure
        }
        switch urlError.code {
        case .badURL, .unsupportedURL:
            return .invalidConfiguration
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff:
            return .offline
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired:
            return .invalidTLS
        default:
            return .transportFailure
        }
    }
}
