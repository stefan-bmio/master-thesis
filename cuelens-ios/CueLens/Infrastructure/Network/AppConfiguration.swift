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
    static let allowsLocalHTTPKey = "CUELENS_ALLOWS_LOCAL_HTTP"
    static let runCooldownSecondsKey = "CUELENS_RUN_COOLDOWN_SECONDS"

    let endpoints: NetworkEndpoints
    let appVersion: String
    let transportPolicy: NetworkTransportPolicy
    let externalLinks: ExternalLinkConfiguration
    let runCooldownSeconds: TimeInterval

    static func live(bundle: Bundle = .main) throws -> AppConfiguration {
        try parse(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func parse(infoDictionary: [String: Any]) throws -> AppConfiguration {
        let appVersion = try validatedAppVersion(
            infoDictionary["CFBundleShortVersionString"] as? String
        )
        let transportPolicy: NetworkTransportPolicy =
            (infoDictionary[allowsLocalHTTPKey] as? String) == "YES"
            ? .httpsAndLocalHTTP
            : .httpsOnly
        return AppConfiguration(
            endpoints: NetworkEndpoints(
                activation: try validatedURL(infoDictionary[activationURLKey], policy: transportPolicy),
                messages: try validatedURL(infoDictionary[messagesURLKey], policy: transportPolicy),
                feedback: try validatedURL(infoDictionary[feedbackURLKey], policy: transportPolicy),
                features: try validatedURL(infoDictionary[featuresURLKey], policy: transportPolicy),
                submission: try validatedURL(infoDictionary[submissionURLKey], policy: transportPolicy)
            ),
            appVersion: appVersion,
            transportPolicy: transportPolicy,
            externalLinks: try ExternalLinkConfiguration.parse(infoDictionary: infoDictionary),
            runCooldownSeconds: try validatedCooldown(
                infoDictionary[runCooldownSecondsKey]
            )
        )
    }

    private static func validatedURL(
        _ rawValue: Any?,
        policy: NetworkTransportPolicy
    ) throws -> URL {
        guard let value = rawValue as? String,
              let components = URLComponents(string: value),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              !components.path.isEmpty,
              let url = components.url,
              policy.allows(url) else {
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

    private static func validatedCooldown(_ rawValue: Any?) throws -> TimeInterval {
        let seconds: Double?
        switch rawValue {
        case let value as String:
            seconds = Double(value)
        case let value as NSNumber:
            seconds = value.doubleValue
        default:
            seconds = nil
        }
        guard let seconds, seconds.isFinite, seconds > 0,
              seconds.rounded() == seconds else {
            throw NetworkError.invalidConfiguration
        }
        return seconds
    }
}
