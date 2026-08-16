import Foundation

struct FeedbackDraft: Equatable, Sendable {
    static let maximumSourceLength = 500
    static let maximumCommentLength = 5_000

    let source: String?
    let comment: String?

    init(source: String, comment: String) throws {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSource.isEmpty || !trimmedComment.isEmpty else {
            throw DomainValidationError.feedbackRequiresContent
        }
        guard trimmedSource.unicodeScalars.count <= Self.maximumSourceLength else {
            throw DomainValidationError.feedbackSourceTooLong
        }
        guard trimmedComment.unicodeScalars.count <= Self.maximumCommentLength else {
            throw DomainValidationError.feedbackCommentTooLong
        }

        self.source = trimmedSource.isEmpty ? nil : trimmedSource
        self.comment = trimmedComment.isEmpty ? nil : trimmedComment
    }
}
