import Foundation

enum FeedbackSubmissionOutcome: Equatable, Sendable {
    case submitted
    case failed
    case ignored
}

protocol FeedbackManaging: Sendable {
    func submit(_ draft: FeedbackDraft) async -> FeedbackSubmissionOutcome
}

actor FeedbackCoordinator: FeedbackManaging {
    private let service: any FeedbackServicing
    private let appVersion: String
    private var submissionRunning = false

    init(service: any FeedbackServicing, appVersion: String) {
        self.service = service
        self.appVersion = appVersion
    }

    func submit(_ draft: FeedbackDraft) async -> FeedbackSubmissionOutcome {
        guard !submissionRunning else { return .ignored }
        submissionRunning = true
        defer { submissionRunning = false }
        do {
            try await service.submit(
                source: draft.source,
                comment: draft.comment,
                appVersion: appVersion
            )
            return .submitted
        } catch {
            return .failed
        }
    }
}

struct DisabledFeedbackManager: FeedbackManaging {
    func submit(_ draft: FeedbackDraft) async -> FeedbackSubmissionOutcome { .failed }
}
