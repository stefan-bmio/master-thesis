import Foundation
import UIKit

struct ExternalLinkConfiguration: Equatable, Sendable {
    static let privacyGermanKey = "CUELENS_PRIVACY_URL_DE"
    static let privacyEnglishKey = "CUELENS_PRIVACY_URL_EN"

    let privacyGerman: URL
    let privacyEnglish: URL
    let rightsContact: URL

    static func parse(infoDictionary: [String: Any]) throws -> ExternalLinkConfiguration {
        guard let contact = URL(string: "mailto:cuelens@each-and-every.de") else {
            throw NetworkError.invalidConfiguration
        }
        return ExternalLinkConfiguration(
            privacyGerman: try validatedPrivacyURL(infoDictionary[privacyGermanKey]),
            privacyEnglish: try validatedPrivacyURL(infoDictionary[privacyEnglishKey]),
            rightsContact: contact
        )
    }

    func privacyURL(for language: AppLanguage) -> URL {
        language == .german ? privacyGerman : privacyEnglish
    }

    func allows(_ url: URL) -> Bool {
        url == privacyGerman || url == privacyEnglish || url == rightsContact
    }

    private static func validatedPrivacyURL(_ rawValue: Any?) throws -> URL {
        guard let value = rawValue as? String,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              !components.path.isEmpty,
              let url = components.url else {
            throw NetworkError.invalidConfiguration
        }
        return url
    }
}

protocol ExternalLinkOpening: Sendable {
    @MainActor
    func open(_ url: URL) async -> Bool
}

struct SystemExternalLinkOpener: ExternalLinkOpening {
    @MainActor
    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}

protocol ExternalLinkManaging: Sendable {
    func openPrivacy(language: AppLanguage) async -> Bool
    func openRightsContact() async -> Bool
}

actor ExternalLinkCoordinator: ExternalLinkManaging {
    private let configuration: ExternalLinkConfiguration
    private let opener: any ExternalLinkOpening

    init(
        configuration: ExternalLinkConfiguration,
        opener: any ExternalLinkOpening = SystemExternalLinkOpener()
    ) {
        self.configuration = configuration
        self.opener = opener
    }

    func openPrivacy(language: AppLanguage) async -> Bool {
        await openAllowed(configuration.privacyURL(for: language))
    }

    func openRightsContact() async -> Bool {
        await openAllowed(configuration.rightsContact)
    }

    private func openAllowed(_ url: URL) async -> Bool {
        guard configuration.allows(url) else { return false }
        return await opener.open(url)
    }
}

struct DisabledExternalLinkManager: ExternalLinkManaging {
    func openPrivacy(language: AppLanguage) async -> Bool { false }
    func openRightsContact() async -> Bool { false }
}
