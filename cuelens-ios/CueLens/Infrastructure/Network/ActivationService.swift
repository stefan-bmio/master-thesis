import Foundation

actor ActivationService: ActivationServicing {
    static let maximumResponseBytes = 8 * 1_024

    private let endpoint: URL
    private let client: any HTTPClienting

    init(endpoint: URL, client: any HTTPClienting) {
        self.endpoint = endpoint
        self.client = client
    }

    func requestToken(identifier: ParticipantIdentifier) async throws -> UUIDv4 {
        let body = try JSONContract.encode(
            ActivationRequestBody(identifier: identifier.value)
        )
        let response = try await client.execute(
            HTTPRequest(
                kind: .activationRequest,
                url: endpoint,
                method: .put,
                body: body,
                statusExpectation: .exact(200),
                responsePolicy: .json(maximumBytes: Self.maximumResponseBytes)
            )
        )
        let object = try JSONContract.object(from: response.body)
        guard StrictJSON.hasExactlyKeys(object, ["app_token"]),
              let value = StrictJSON.string(object["app_token"]),
              let token = try? UUIDv4(value) else {
            throw NetworkError.protocolViolation
        }
        return token
    }

    func confirmToken(identifier: ParticipantIdentifier, token: UUIDv4) async throws {
        let body = try JSONContract.encode(
            ActivationConfirmationBody(
                identifier: identifier.value,
                appToken: token.description
            )
        )
        _ = try await client.execute(
            HTTPRequest(
                kind: .activationConfirmation,
                url: endpoint,
                method: .put,
                body: body,
                statusExpectation: .exact(204),
                responsePolicy: .empty(maximumBytes: Self.maximumResponseBytes)
            )
        )
    }
}

private struct ActivationRequestBody: Encodable {
    let identifier: String
}

private struct ActivationConfirmationBody: Encodable {
    let identifier: String
    let appToken: String

    enum CodingKeys: String, CodingKey {
        case identifier
        case appToken = "app_token"
    }
}
