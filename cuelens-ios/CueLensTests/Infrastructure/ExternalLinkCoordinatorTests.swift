import Foundation
import XCTest
@testable import CueLens

final class ExternalLinkCoordinatorTests: XCTestCase {
    func testConfigurationAllowsOnlyConfiguredPrivacyAndBareMailtoURLs() throws {
        let configuration = try ExternalLinkConfiguration.parse(infoDictionary: validDictionary())

        XCTAssertEqual(configuration.privacyURL(for: .german).path, "/ds")
        XCTAssertEqual(configuration.privacyURL(for: .english).path, "/privacy.pdf")
        XCTAssertEqual(configuration.rightsContact.absoluteString, "mailto:cuelens@each-and-every.de")
        XCTAssertNil(URLComponents(url: configuration.rightsContact, resolvingAgainstBaseURL: false)?.query)
        XCTAssertTrue(configuration.allows(configuration.privacyGerman))
        XCTAssertFalse(configuration.allows(try XCTUnwrap(URL(string: "https://example.invalid/other"))))
    }

    func testConfigurationRejectsUnsafePrivacyURLs() {
        let invalidURLs = [
            "http://example.invalid/ds",
            "https://user@example.invalid/ds",
            "https://example.invalid:8443/ds",
            "https://example.invalid/ds?q=token",
            "https://example.invalid/ds#fragment",
            "https://example.invalid"
        ]
        for value in invalidURLs {
            var dictionary = validDictionary()
            dictionary[ExternalLinkConfiguration.privacyGermanKey] = value
            XCTAssertThrowsError(try ExternalLinkConfiguration.parse(infoDictionary: dictionary))
        }
    }

    @MainActor
    func testCoordinatorOpensLanguageSpecificAllowlistedLinks() async throws {
        let configuration = try ExternalLinkConfiguration.parse(infoDictionary: validDictionary())
        let opener = LinkOpenerRecorder()
        let coordinator = ExternalLinkCoordinator(configuration: configuration, opener: opener)

        let openedGerman = await coordinator.openPrivacy(language: .german)
        let openedEnglish = await coordinator.openPrivacy(language: .english)
        let openedContact = await coordinator.openRightsContact()
        XCTAssertTrue(openedGerman)
        XCTAssertTrue(openedEnglish)
        XCTAssertTrue(openedContact)
        XCTAssertEqual(opener.openedURLs, [
            configuration.privacyGerman,
            configuration.privacyEnglish,
            configuration.rightsContact
        ])
    }

    private func validDictionary() -> [String: Any] {
        [
            ExternalLinkConfiguration.privacyGermanKey: "https://example.invalid/ds",
            ExternalLinkConfiguration.privacyEnglishKey: "https://example.invalid/privacy.pdf"
        ]
    }
}

@MainActor
private final class LinkOpenerRecorder: ExternalLinkOpening, @unchecked Sendable {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return true
    }
}
