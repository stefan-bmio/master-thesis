import Foundation

actor InfoFeedService: InfoFeedServicing {
    static let maximumResponseBytes = 512 * 1_024

    private let endpoint: URL
    private let client: any HTTPClienting

    init(endpoint: URL, client: any HTTPClienting) {
        self.endpoint = endpoint
        self.client = client
    }

    func fetchMessages() async throws -> [InfoMessage] {
        let response = try await client.execute(
            HTTPRequest(
                kind: .messages,
                url: endpoint,
                method: .get,
                body: nil,
                statusExpectation: .exact(200),
                responsePolicy: .json(maximumBytes: Self.maximumResponseBytes)
            )
        )
        _ = try JSONContract.object(from: response.body)
        do {
            return try InfoMessageBatchDecoder.decode(response.body)
        } catch {
            throw NetworkError.protocolViolation
        }
    }
}
