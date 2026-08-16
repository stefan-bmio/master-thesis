protocol ActivationServicing: Sendable {
    func requestToken(identifier: ParticipantIdentifier) async throws -> UUIDv4
    func confirmToken(identifier: ParticipantIdentifier, token: UUIDv4) async throws
}

protocol FeatureConfigServicing: Sendable {
    func isNextStudyRunEnabled() async -> Bool
}

protocol FeedbackServicing: Sendable {
    func submit(source: String?, comment: String?, appVersion: String) async throws
}

protocol StudySubmissionServicing: Sendable {
    func submitSelfReport(
        token: UUIDv4,
        craving: Int,
        appVersion: String,
        expectedSituation: SituationNumber
    ) async throws -> SelfReportResponse
    func confirmCompensation(code: UUIDv4) async throws
}

protocol InfoFeedServicing: Sendable {
    func fetchMessages() async throws -> [InfoMessage]
}
