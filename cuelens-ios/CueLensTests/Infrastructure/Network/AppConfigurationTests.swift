import Foundation
import XCTest
@testable import CueLens

final class AppConfigurationTests: XCTestCase {
    func testParsesCompleteHTTPSConfiguration() throws {
        let configuration = try AppConfiguration.parse(infoDictionary: validDictionary())

        XCTAssertEqual(configuration.appVersion, "1.0.0")
        XCTAssertEqual(
            configuration.endpoints.activation.absoluteString,
            "https://example.invalid/activate.php"
        )
        XCTAssertEqual(configuration.endpoints.messages.path, "/messages.php")
        XCTAssertEqual(configuration.endpoints.feedback.path, "/feedback.php")
        XCTAssertEqual(configuration.endpoints.features.path, "/features.php")
        XCTAssertEqual(configuration.endpoints.submission.path, "/submit.php")
    }

    func testRejectsMissingMalformedAndUnsafeValues() {
        let invalidValues: [(String, Any?)] = [
            (AppConfiguration.activationURLKey, nil),
            (AppConfiguration.activationURLKey, "http://example.invalid/activate.php"),
            (AppConfiguration.activationURLKey, "https://user@example.invalid/activate.php"),
            (AppConfiguration.activationURLKey, "https://example.invalid/activate.php?q=1"),
            (AppConfiguration.activationURLKey, "https://example.invalid/activate.php#fragment"),
            (AppConfiguration.activationURLKey, "https://example.invalid"),
            ("CFBundleShortVersionString", "invalid version")
        ]

        for (key, value) in invalidValues {
            var dictionary = validDictionary()
            dictionary[key] = value
            XCTAssertThrowsError(try AppConfiguration.parse(infoDictionary: dictionary)) {
                XCTAssertEqual($0 as? NetworkError, .invalidConfiguration)
            }
        }
    }

    func testEphemeralConfigurationDisablesPersistentStateAndWaiting() {
        let configuration = URLSessionHTTPClient.ephemeralConfiguration()

        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertFalse(configuration.waitsForConnectivity)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 15)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 30)
    }

    private func validDictionary() -> [String: Any] {
        [
            "CFBundleShortVersionString": "1.0.0",
            AppConfiguration.activationURLKey: "https://example.invalid/activate.php",
            AppConfiguration.messagesURLKey: "https://example.invalid/messages.php",
            AppConfiguration.feedbackURLKey: "https://example.invalid/feedback.php",
            AppConfiguration.featuresURLKey: "https://example.invalid/features.php",
            AppConfiguration.submissionURLKey: "https://example.invalid/submit.php"
        ]
    }
}
