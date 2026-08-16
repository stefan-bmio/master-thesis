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

    let endpoints: NetworkEndpoints
    let appVersion: String

    static func live(bundle: Bundle = .main) throws -> AppConfiguration {
        try parse(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func parse(infoDictionary: [String: Any]) throws -> AppConfiguration {
        let appVersion = try validatedAppVersion(
            infoDictionary["CFBundleShortVersionString"] as? String
        )
        let allowsLocalHTTP = (infoDictionary[allowsLocalHTTPKey] as? String) == "YES"
        return AppConfiguration(
            endpoints: NetworkEndpoints(
                activation: try validatedURL(infoDictionary[activationURLKey], allowsLocalHTTP: allowsLocalHTTP),
                messages: try validatedURL(infoDictionary[messagesURLKey], allowsLocalHTTP: allowsLocalHTTP),
                feedback: try validatedURL(infoDictionary[feedbackURLKey], allowsLocalHTTP: allowsLocalHTTP),
                features: try validatedURL(infoDictionary[featuresURLKey], allowsLocalHTTP: allowsLocalHTTP),
                submission: try validatedURL(infoDictionary[submissionURLKey], allowsLocalHTTP: allowsLocalHTTP)
            ),
            appVersion: appVersion
        )
    }

    private static func validatedURL(_ rawValue: Any?, allowsLocalHTTP: Bool) throws -> URL {
        guard let value = rawValue as? String,
              let components = URLComponents(string: value),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              !components.path.isEmpty,
              let url = components.url,
              isAllowedTransport(components, allowsLocalHTTP: allowsLocalHTTP) else {
            throw NetworkError.invalidConfiguration
        }
        return url
    }

    private static func isAllowedTransport(
        _ components: URLComponents,
        allowsLocalHTTP: Bool
    ) -> Bool {
        let scheme = components.scheme?.lowercased()
        if scheme == "https" { return true }
        guard scheme == "http", allowsLocalHTTP, let host = components.host else { return false }
        return host == "localhost" || host.hasSuffix(".local") || isPrivateIPv4(host)
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        return octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
            || octets[0] == 127
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
