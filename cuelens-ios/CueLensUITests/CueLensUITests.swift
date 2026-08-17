import XCTest

final class CueLensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesOnSupportedDevice() {
        let app = makeApp(feed: "empty")
        app.launch()
        declineConsentIfShown(in: app)
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
        declineConsentIfShown(in: app)
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
        declineConsentIfShown(in: app)
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
    func testNotificationConsentDefaultsToEnabledAndCanBeDeclinedWithoutSystemPrompt() {
        let app = makeApp(feed: "empty")
        app.launch()

        XCTAssertTrue(app.staticTexts["notification.consent.title"].waitForExistence(timeout: 10))
        let notificationToggle = app.switches["notification.consent.toggle"]
        XCTAssertEqual(notificationToggle.value as? String, "1")
        notificationToggle.tap()
        app.buttons["notification.consent.continue"].tap()
        XCTAssertTrue(app.staticTexts["app.foundationStatus.ready"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testMessageRemainsVisibleWithDarkSystemAppearance() {
        let app = makeApp(feed: "multiple", interfaceStyle: "Dark")
        app.launch()
        XCTAssertTrue(app.staticTexts["Synthetische Information eins"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testActivationValidatesInputAndAcceptsEmail() {
        let app = makeApp(feed: "empty", activation: "success")
        app.launch()
        openActivation(in: app)
        let field = app.textFields["activation.identifier"]
        field.tap()
        field.typeText("invalid")
        XCTAssertFalse(app.buttons["activation.submit"].isEnabled)
        field.clearAndTypeText("person@example.org")
        XCTAssertTrue(app.buttons["activation.submit"].isEnabled)
        app.buttons["activation.submit"].tap()
        XCTAssertTrue(app.staticTexts["activation.completed"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["activation.open"].exists)
    }

    @MainActor
    func testActivationAcceptsProlificIDAndSwitchesLanguage() {
        let app = makeApp(feed: "empty", activation: "success")
        app.launch()
        openActivation(in: app)
        app.buttons["language.switch"].tap()
        XCTAssertTrue(app.staticTexts["App activation"].waitForExistence(timeout: 2))
        let field = app.textFields["activation.identifier"]
        field.tap()
        field.typeText("AbCdEf1234567890GhIjKlMn")
        app.buttons["activation.submit"].tap()
        XCTAssertTrue(app.staticTexts["The app has been activated."].waitForExistence(timeout: 3))
    }

    @MainActor
    func testActivationShowsRunningStateAndBlocksNavigation() {
        let app = makeApp(feed: "empty", activation: "running")
        app.launch()
        openActivation(in: app)
        let field = app.textFields["activation.identifier"]
        field.tap()
        field.typeText("person@example.org")
        app.buttons["activation.submit"].tap()
        let progress = app.descendants(matching: .any)["activation.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["activation.submit"].isEnabled)
        XCTAssertFalse(app.buttons["activation.back"].isEnabled)
        XCTAssertTrue(app.staticTexts["activation.completed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testActivationDistinguishesGeneralFailureAndConfirmationTimeout() {
        let failed = makeApp(feed: "empty", activation: "failure")
        failed.launch()
        openActivation(in: failed)
        failed.textFields["activation.identifier"].tap()
        failed.textFields["activation.identifier"].typeText("person@example.org")
        failed.buttons["activation.submit"].tap()
        XCTAssertTrue(failed.staticTexts["activation.error"].waitForExistence(timeout: 2))
        XCTAssertEqual(failed.textFields["activation.identifier"].value as? String,
                       "E-Mail-Adresse oder Prolific-ID")
        failed.terminate()

        let timeout = makeApp(feed: "empty", activation: "timeout")
        timeout.launch()
        openActivation(in: timeout)
        timeout.textFields["activation.identifier"].tap()
        timeout.textFields["activation.identifier"].typeText("person@example.org")
        timeout.buttons["activation.submit"].tap()
        XCTAssertTrue(timeout.staticTexts["activation.support"].waitForExistence(timeout: 2))
        XCTAssertFalse(timeout.textFields["activation.identifier"].isEnabled)
        XCTAssertFalse(timeout.buttons["activation.submit"].isEnabled)
    }

    @MainActor
    func testActivationStorageFailureAndRecoveredUncertaintyAreFailClosed() {
        let failed = makeApp(feed: "empty", activation: "storage-failure")
        failed.launch()
        openActivation(in: failed)
        failed.textFields["activation.identifier"].tap()
        failed.textFields["activation.identifier"].typeText("person@example.org")
        failed.buttons["activation.submit"].tap()
        XCTAssertTrue(failed.staticTexts["app.foundationStatus.failure"].waitForExistence(timeout: 2))
        failed.terminate()

        let restored = makeApp(feed: "empty", activation: "recovered-support")
        restored.launch()
        XCTAssertTrue(restored.staticTexts["app.foundationStatus.failure"].waitForExistence(timeout: 10))
        XCTAssertFalse(restored.buttons["activation.open"].exists)
    }

    @MainActor
    func testAlreadyActivatedAppDoesNotOfferActivation() {
        let app = makeApp(feed: "empty", activation: "activated")
        app.launch()
        declineConsentIfShown(in: app)
        XCTAssertTrue(app.staticTexts["activation.completed"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["activation.open"].exists)
    }

    @MainActor
    private func makeApp(
        feed: String,
        language: String = "de",
        suite: String = "de.eachandevery.cuelens.uitest.\(UUID().uuidString)",
        interfaceStyle: String? = nil,
        activation: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "--ui-test-feed", feed,
            "--ui-test-suite", suite
        ]
        if let interfaceStyle {
            app.launchArguments += ["-AppleInterfaceStyle", interfaceStyle]
        }
        if let activation {
            app.launchArguments += ["--ui-test-activation", activation]
        }
        return app
    }


    @MainActor
    private func declineConsentIfShown(in app: XCUIApplication) {
        guard app.staticTexts["notification.consent.title"].waitForExistence(timeout: 2) else {
            return
        }
        app.switches["notification.consent.toggle"].tap()
        app.buttons["notification.consent.continue"].tap()
    }

    @MainActor
    private func openActivation(in app: XCUIApplication) {
        declineConsentIfShown(in: app)
        XCTAssertTrue(app.buttons["activation.open"].waitForExistence(timeout: 10))
        app.buttons["activation.open"].tap()
        XCTAssertTrue(app.staticTexts["activation.title"].waitForExistence(timeout: 2))
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
