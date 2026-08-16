import XCTest

final class CueLensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesOnSupportedDevice() {
        let app = makeApp(feed: "empty")
        app.launch()
        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["app.foundationStatus.ready"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["app.foundationStatus.failure"].exists)
    }

    @MainActor
    func testFeedNavigationAndImmediateLanguageSwitch() {
        let app = makeApp(feed: "multiple", language: "de")
        app.launch()
        XCTAssertTrue(app.staticTexts["Synthetische Information eins"].waitForExistence(timeout: 10))

        app.buttons["language.switch"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic information one"].waitForExistence(timeout: 2))
        app.switches["info.hidePermanently"].tap()
        app.buttons["info.confirm"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic information two"].waitForExistence(timeout: 2))

        app.buttons["info.back"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic information one"].waitForExistence(timeout: 2))
        app.buttons["info.back"].tap()
        XCTAssertTrue(app.staticTexts["app.foundationStatus.ready"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFeedFailureStillShowsHomeAndNeutralNotice() {
        let app = makeApp(feed: "error")
        app.launch()
        XCTAssertTrue(app.staticTexts["app.foundationStatus.ready"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["app.notice.message"].exists)
    }

    @MainActor
    func testLanguageSelectionSurvivesRestart() {
        let suite = "de.eachandevery.cuelens.uitest.\(UUID().uuidString)"
        let app = makeApp(feed: "empty", language: "de", suite: suite)
        app.launch()
        XCTAssertEqual(app.buttons["language.switch"].label, "Sprache auf Englisch umstellen")
        app.buttons["language.switch"].tap()
        XCTAssertEqual(app.buttons["language.switch"].label, "Switch language to German")
        app.terminate()

        let relaunched = makeApp(feed: "empty", language: "de", suite: suite)
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["app.foundationStatus.ready"].waitForExistence(timeout: 10))
        XCTAssertEqual(relaunched.buttons["language.switch"].label, "Switch language to German")
    }

    @MainActor
    private func makeApp(
        feed: String,
        language: String = "de",
        suite: String = "de.eachandevery.cuelens.uitest.\(UUID().uuidString)"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "--ui-test-feed", feed,
            "--ui-test-suite", suite
        ]
        return app
    }
}
