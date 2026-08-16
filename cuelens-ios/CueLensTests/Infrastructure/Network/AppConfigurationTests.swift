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

    func testAllowsHTTPOnlyForExplicitLocalDevelopmentHosts() throws {
        for host in ["192.168.1.243", "10.0.0.2", "172.16.4.2", "127.0.0.1", "localhost", "cuelens.local"] {
            var dictionary = validDictionary()
            dictionary[AppConfiguration.allowsLocalHTTPKey] = "YES"
            dictionary[AppConfiguration.messagesURLKey] = "http://\(host)/cuelens/messages.php"
            XCTAssertEqual(
                try AppConfiguration.parse(infoDictionary: dictionary).endpoints.messages.host,
                host
            )
        }
    }

    func testRejectsLocalHTTPWithoutFlagAndPublicHTTPWithFlag() {
        for (url, flag) in [
            ("http://192.168.1.243/cuelens/messages.php", "NO"),
            ("http://example.com/messages.php", "YES"),
            ("http://172.15.0.1/messages.php", "YES")
        ] {
            var dictionary = validDictionary()
            dictionary[AppConfiguration.allowsLocalHTTPKey] = flag
            dictionary[AppConfiguration.messagesURLKey] = url
            XCTAssertThrowsError(try AppConfiguration.parse(infoDictionary: dictionary))
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
