import Foundation

actor FeedbackService: FeedbackServicing {
    static let maximumResponseBytes = 8 * 1_024

    private let endpoint: URL
    private let client: any HTTPClienting

    init(endpoint: URL, client: any HTTPClienting) {
        self.endpoint = endpoint
        self.client = client
    }

    func submit(source: String?, comment: String?, appVersion: String) async throws {
        let draft: FeedbackDraft
        do {
            draft = try FeedbackDraft(source: source ?? "", comment: comment ?? "")
        } catch {
            throw NetworkError.protocolViolation
        }
        try JSONContract.validateAppVersion(appVersion)
        let body = try JSONContract.encode(
            FeedbackRequestBody(
                source: draft.source,
                comment: draft.comment,
                appVersion: appVersion
            )
        )
        _ = try await client.execute(
            HTTPRequest(
                kind: .feedback,
                url: endpoint,
                method: .post,
                body: body,
                statusExpectation: .successful,
                responsePolicy: .discard(maximumBytes: Self.maximumResponseBytes)
            )
        )
    }
}

private struct FeedbackRequestBody: Encodable {
    let source: String?
    let comment: String?
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case source
        case comment
        case appVersion = "app_version"
    }
}
