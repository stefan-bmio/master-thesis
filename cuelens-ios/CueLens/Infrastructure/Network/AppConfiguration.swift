import Foundation

struct NetworkEndpoints: Equatable, Sendable {
    let activation: URL
    let messages: URL
    let feedback: URL
    let features: URL
    let submission: URL
}

struct AppConfiguration: Equatable, Sendable {
    static let activationURLKey = "CUELENS_ACTIVATION_URL"
    static let messagesURLKey = "CUELENS_MESSAGES_URL"
    static let feedbackURLKey = "CUELENS_FEEDBACK_URL"
    static let featuresURLKey = "CUELENS_FEATURES_URL"
    static let submissionURLKey = "CUELENS_SUBMIT_URL"

    let endpoints: NetworkEndpoints
    let appVersion: String

    static func live(bundle: Bundle = .main) throws -> AppConfiguration {
        try parse(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func parse(infoDictionary: [String: Any]) throws -> AppConfiguration {
        let appVersion = try validatedAppVersion(
            infoDictionary["CFBundleShortVersionString"] as? String
        )
        return AppConfiguration(
            endpoints: NetworkEndpoints(
                activation: try validatedURL(infoDictionary[activationURLKey]),
                messages: try validatedURL(infoDictionary[messagesURLKey]),
                feedback: try validatedURL(infoDictionary[feedbackURLKey]),
                features: try validatedURL(infoDictionary[featuresURLKey]),
                submission: try validatedURL(infoDictionary[submissionURLKey])
            ),
            appVersion: appVersion
        )
    }

    private static func validatedURL(_ rawValue: Any?) throws -> URL {
        guard let value = rawValue as? String,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              !components.path.isEmpty,
              let url = components.url else {
            throw NetworkError.invalidConfiguration
        }
        return url
    }

    private static func validatedAppVersion(_ rawValue: String?) throws -> String {
        guard let value = rawValue,
              value.range(
                of: #"^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$"#,
                options: .regularExpression
              ) != nil else {
            throw NetworkError.invalidConfiguration
        }
        return value
    }
}
