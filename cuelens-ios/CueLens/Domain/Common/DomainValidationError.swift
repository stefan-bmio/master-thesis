import Foundation

enum DomainValidationError: Error, Equatable, Sendable {
    case invalidParticipantIdentifier
    case feedbackRequiresContent
    case feedbackSourceTooLong
    case feedbackCommentTooLong
    case invalidMessagePayload
    case invalidUUIDv4
    case invalidCraving
    case invalidSituation
    case invalidMatchingOrder
    case invalidStudyState
    case invalidSelfReportResponse
    case invalidStudyContent
}
