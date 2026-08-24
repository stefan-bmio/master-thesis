import Foundation

struct NetworkServices: Sendable {
    let activation: any ActivationServicing
    let messages: any InfoFeedServicing
    let features: any FeatureConfigServicing
    let feedback: any FeedbackServicing
    let submission: any StudySubmissionServicing

    static func live(configuration: AppConfiguration? = nil) throws -> NetworkServices {
        let configuration = try configuration ?? AppConfiguration.live()
        let client = URLSessionHTTPClient(
            appVersion: configuration.appVersion,
            transportPolicy: configuration.transportPolicy
        )
        return NetworkServices(
            activation: ActivationService(
                endpoint: configuration.endpoints.activation,
                client: client
            ),
            messages: InfoFeedService(
                endpoint: configuration.endpoints.messages,
                client: client
            ),
            features: FeatureConfigService(
                endpoint: configuration.endpoints.features,
                client: client
            ),
            feedback: FeedbackService(
                endpoint: configuration.endpoints.feedback,
                client: client
            ),
            submission: StudySubmissionService(
                endpoint: configuration.endpoints.submission,
                client: client
            )
        )
    }
}
