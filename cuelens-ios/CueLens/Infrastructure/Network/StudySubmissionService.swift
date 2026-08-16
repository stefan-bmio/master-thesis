import Foundation

actor StudySubmissionService: StudySubmissionServicing {
    static let maximumSelfReportResponseBytes = 16 * 1_024
    static let maximumConfirmationResponseBytes = 8 * 1_024

    private let endpoint: URL
    private let client: any HTTPClienting

    init(endpoint: URL, client: any HTTPClienting) {
        self.endpoint = endpoint
        self.client = client
    }

    func submitSelfReport(
        token: UUIDv4,
        craving: Int,
        appVersion: String,
        expectedSituation: SituationNumber
    ) async throws -> SelfReportResponse {
        guard let cravingValue = try? CravingValue(craving) else {
            throw NetworkError.protocolViolation
        }
        try JSONContract.validateAppVersion(appVersion)
        let body = try JSONContract.encode(
            SelfReportRequestBody(
                appToken: token.description,
                craving: cravingValue.value,
                appVersion: appVersion
            )
        )
        let response = try await client.execute(
            HTTPRequest(
                kind: .selfReport,
                url: endpoint,
                method: .put,
                body: body,
                statusExpectation: .exact(200),
                responsePolicy: .json(maximumBytes: Self.maximumSelfReportResponseBytes)
            )
        )
        _ = try JSONContract.object(from: response.body)
        do {
            return try SelfReportResponseDecoder.decode(
                response.body,
                expectedSituation: expectedSituation
            )
        } catch {
            throw NetworkError.protocolViolation
        }
    }

    func confirmCompensation(code: UUIDv4) async throws {
        let body = try JSONContract.encode(
            CompensationConfirmationBody(compensationCode: code.description)
        )
        _ = try await client.execute(
            HTTPRequest(
                kind: .compensationConfirmation,
                url: endpoint,
                method: .put,
                body: body,
                statusExpectation: .exact(204),
                responsePolicy: .empty(maximumBytes: Self.maximumConfirmationResponseBytes)
            )
        )
    }
}

private struct SelfReportRequestBody: Encodable {
    let appToken: String
    let craving: Int
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case appToken = "app_token"
        case craving
        case appVersion = "app_version"
    }
}

private struct CompensationConfirmationBody: Encodable {
    let compensationCode: String

    enum CodingKeys: String, CodingKey {
        case compensationCode = "compensation_code"
    }
}
