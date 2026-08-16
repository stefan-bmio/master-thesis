import Foundation

actor FeatureConfigService: FeatureConfigServicing {
    static let maximumResponseBytes = 8 * 1_024

    private let endpoint: URL
    private let client: any HTTPClienting

    init(endpoint: URL, client: any HTTPClienting) {
        self.endpoint = endpoint
        self.client = client
    }

    func isNextStudyRunEnabled() async -> Bool {
        do {
            let response = try await client.execute(
                HTTPRequest(
                    kind: .features,
                    url: endpoint,
                    method: .get,
                    body: nil,
                    statusExpectation: .exact(200),
                    responsePolicy: .json(maximumBytes: Self.maximumResponseBytes)
                )
            )
            let object = try JSONContract.object(from: response.body)
            guard StrictJSON.hasExactlyKeys(object, ["features"]),
                  let features = object["features"] as? [String: Any],
                  StrictJSON.hasExactlyKeys(features, ["next_study_run_enabled"]),
                  let enabled = StrictJSON.boolean(features["next_study_run_enabled"]) else {
                return false
            }
            return enabled
        } catch {
            return false
        }
    }
}
