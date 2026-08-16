import Foundation

struct AppEnvironment: Sendable {
    let persistence: any LocalPersistenceLoading
    let settings: any AppSettingsStoring
    let infoFeed: any InfoFeedRepositoryServing

    static func live() throws -> AppEnvironment {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let suiteName = argumentValue(after: "--ui-test-suite", in: arguments)
        let settings = UserDefaultsAppSettingsStore(suiteName: suiteName)
        if let scenario = argumentValue(after: "--ui-test-feed", in: arguments) {
            return AppEnvironment(
                persistence: LiveLocalPersistenceBootstrap(),
                settings: settings,
                infoFeed: InfoFeedRepository(
                    service: UITestInfoFeedService(scenario: scenario),
                    settings: settings
                )
            )
        }
        #else
        let settings = UserDefaultsAppSettingsStore()
        #endif
        let services = try NetworkServices.live()
        return AppEnvironment(
            persistence: LiveLocalPersistenceBootstrap(),
            settings: settings,
            infoFeed: InfoFeedRepository(service: services.messages, settings: settings)
        )
    }

    #if DEBUG
    private static func argumentValue(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
    #endif
}

#if DEBUG
private actor UITestInfoFeedService: InfoFeedServicing {
    let scenario: String

    init(scenario: String) {
        self.scenario = scenario
    }

    func fetchMessages() async throws -> [InfoMessage] {
        if scenario == "error" { throw NetworkError.transportFailure }
        if scenario == "empty" { return [] }
        return [
            InfoMessage(
                id: 101,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                textGerman: "Synthetische Information eins",
                textEnglish: "Synthetic information one"
            ),
            InfoMessage(
                id: 102,
                createdAt: Date(timeIntervalSince1970: 1_700_000_001),
                textGerman: "Synthetische Information zwei",
                textEnglish: "Synthetic information two"
            )
        ]
    }
}
#endif

enum SystemLanguageResolver {
    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        guard let primary = preferredLanguages.first,
              Locale(identifier: primary).language.languageCode?.identifier == "en" else {
            return .german
        }
        return .english
    }
}
