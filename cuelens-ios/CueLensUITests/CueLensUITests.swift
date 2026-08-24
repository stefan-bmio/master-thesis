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
        XCTAssertTrue(failed.staticTexts["home.tokenStorageFailure"].waitForExistence(timeout: 2))
        XCTAssertTrue(failed.buttons["demo.open"].exists)
        XCTAssertTrue(failed.buttons["feedback.open"].exists)
        failed.terminate()

        let restored = makeApp(feed: "empty", activation: "recovered-support")
        restored.launch()
        declineConsentIfShown(in: restored)
        XCTAssertTrue(restored.staticTexts["home.tokenStorageFailure"].waitForExistence(timeout: 10))
        XCTAssertFalse(restored.buttons["activation.open"].isEnabled)
        XCTAssertTrue(restored.buttons["demo.open"].exists)
        XCTAssertTrue(restored.buttons["feedback.open"].exists)
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
    func testHomeOffersDemoFeedbackPrivacyAndRightsContact() {
        let app = makeApp(feed: "empty")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["feedback.open"].exists)
        XCTAssertTrue(app.buttons["privacy.open"].exists)
        XCTAssertTrue(app.buttons["rights.contact"].exists)
    }

    @MainActor
    func testDemoCompletesAllStepsAndRestartsAfterExit() {
        let app = makeApp(feed: "empty")
        app.launch()
        declineConsentIfShown(in: app)
        app.buttons["demo.open"].tap()

        let matchingCue = app.images["demo.matching.cue"]
        XCTAssertTrue(matchingCue.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(matchingCue.frame.width, 100)
        XCTAssertGreaterThan(matchingCue.frame.height, 100)
        let firstChoice = app.buttons["demo.matching.choice.0"]
        XCTAssertGreaterThan(firstChoice.frame.width, 100)
        XCTAssertGreaterThan(firstChoice.frame.height, 100)
        XCTAssertFalse(firstChoice.isEnabled)
        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: firstChoice
        )
        waitForExpectations(timeout: 7)
        firstChoice.tap()

        let labelingCue = app.images["demo.labeling.cue"]
        XCTAssertTrue(labelingCue.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(labelingCue.frame.width, 100)
        XCTAssertGreaterThan(labelingCue.frame.height, 100)
        XCTAssertTrue(app.buttons["Aschegeruch"].exists)
        XCTAssertTrue(app.buttons["Regenschirmmoment"].exists)
        app.buttons["language.switch"].tap()
        XCTAssertTrue(app.buttons["Ash smell"].exists)
        app.buttons["demo.labeling.choice.0"].tap()

        XCTAssertTrue(app.staticTexts["demo.craving.value"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["demo.craving.value"].label, "50")
        app.buttons["demo.craving.continue"].tap()
        XCTAssertTrue(app.staticTexts["demo.completed.notice"].waitForExistence(timeout: 2))
        app.buttons["demo.completed.home"].tap()
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 2))

        app.buttons["demo.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["demo.matching.countdown"].waitForExistence(timeout: 2))
        app.buttons["demo.back"].tap()
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFeedbackValidatesSubmitsAndClearsForm() {
        let app = makeApp(feed: "empty", feedback: "success")
        app.launch()
        declineConsentIfShown(in: app)
        app.buttons["feedback.open"].tap()

        XCTAssertTrue(app.staticTexts["feedback.title"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["feedback.submit"].isEnabled)
        app.textFields["feedback.source"].tap()
        app.textFields["feedback.source"].typeText("Flyer")
        XCTAssertTrue(app.buttons["feedback.submit"].isEnabled)
        app.buttons["feedback.submit"].tap()
        XCTAssertTrue(app.staticTexts["feedback.submitted"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["feedback.source"].exists)
        app.buttons["feedback.home"].tap()
        XCTAssertTrue(app.buttons["feedback.open"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFeedbackFailureRetainsFormForRetry() {
        let app = makeApp(feed: "empty", feedback: "failure")
        app.launch()
        declineConsentIfShown(in: app)
        app.buttons["feedback.open"].tap()
        let field = app.textFields["feedback.source"]
        field.tap()
        field.typeText("Praxis")
        app.buttons["feedback.submit"].tap()

        XCTAssertTrue(app.staticTexts["feedback.failed"].waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "Praxis")
        XCTAssertTrue(app.buttons["feedback.submit"].isEnabled)
    }

    @MainActor
    func testCompletedStudyHidesDemoAndKeepsFeedback() {
        let app = makeApp(feed: "empty", activation: "completed")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(app.staticTexts["home.completion"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["demo.open"].exists)
        XCTAssertFalse(app.buttons["activation.open"].exists)
        XCTAssertTrue(app.buttons["feedback.open"].exists)
    }

    @MainActor
    func testProductiveMatchingCompletesExactlyFiveTrialsAndStartsCooldown() {
        let app = makeApp(feed: "empty", study: "matching")
        app.launch()
        declineConsentIfShown(in: app)

        let start = app.buttons["study.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        for trial in 1...5 {
            let choice = app.buttons["study.matching.choice.0"]
            XCTAssertTrue(choice.waitForExistence(timeout: 3))
            expectation(
                for: NSPredicate(format: "value == %@", "\(trial)"),
                evaluatedWith: choice
            )
            waitForExpectations(timeout: 2)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: choice)
            waitForExpectations(timeout: 2)
            choice.tap()
        }
        XCTAssertTrue(app.staticTexts["study.craving.value"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["study.craving.value"].label, "50")
        app.buttons["study.craving.submit"].tap()
        XCTAssertTrue(app.buttons["study.start"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["study.start"].isEnabled)
    }

    @MainActor
    func testProductiveLabelingKeepsTrialOrderAcrossLanguageChange() {
        let app = makeApp(feed: "empty", study: "labeling")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(app.buttons["study.start"].waitForExistence(timeout: 10))
        app.buttons["study.start"].tap()
        XCTAssertTrue(app.buttons["study.labeling.choice.0"].waitForExistence(timeout: 3))
        app.buttons["language.switch"].tap()
        for _ in 0..<5 {
            let choice = app.buttons["study.labeling.choice.0"]
            XCTAssertTrue(choice.waitForExistence(timeout: 3))
            choice.tap()
        }
        XCTAssertTrue(app.staticTexts["study.craving.value"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["study.craving.value"].label, "50")
    }

    @MainActor
    func testPendingTransferFailsClosedAndOffersManualRetry() {
        let app = makeApp(feed: "empty", study: "failure")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(app.staticTexts["study.transfer.pending"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["study.transfer.failed"].exists)
        let retry = app.buttons["study.transfer.retry"]
        XCTAssertTrue(retry.exists)
        XCTAssertTrue(retry.isEnabled)
        XCTAssertFalse(app.buttons["study.start"].exists)
        retry.tap()
        XCTAssertTrue(app.buttons["study.start"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["study.start"].isEnabled)
        XCTAssertFalse(app.staticTexts["study.transfer.pending"].exists)
    }

    @MainActor
    func testDirectCompletionShowsCodeAndCopiesOnlyAfterTap() {
        let app = makeApp(feed: "empty", study: "direct")
        app.launch()
        declineConsentIfShown(in: app)

        let code = app.staticTexts["completion.direct.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        XCTAssertEqual(code.label, "123e4567-e89b-42d3-a456-426614174000")
        XCTAssertFalse(app.staticTexts["completion.copied"].exists)
        app.buttons["completion.copy"].tap()
        XCTAssertTrue(app.staticTexts["completion.copied"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["demo.open"].exists)
        XCTAssertTrue(app.buttons["feedback.open"].exists)
    }

    @MainActor
    func testProlificCompletionShowsTwoDayNoticeWithoutCode() {
        let app = makeApp(feed: "empty", study: "prolific")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(app.staticTexts["completion.prolific"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["completion.direct.code"].exists)
        XCTAssertFalse(app.buttons["completion.copy"].exists)
        XCTAssertFalse(app.buttons["demo.open"].exists)
        XCTAssertTrue(app.buttons["feedback.open"].exists)
    }

    @MainActor
    func testFailedCodeConfirmationKeepsCodeHiddenAndOffersRetry() {
        let app = makeApp(feed: "empty", study: "confirmation-failure")
        app.launch()
        declineConsentIfShown(in: app)

        XCTAssertTrue(
            app.staticTexts["completion.confirmation.pending"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["study.transfer.failed"].exists)
        XCTAssertTrue(app.buttons["study.transfer.retry"].isEnabled)
        XCTAssertFalse(app.staticTexts["completion.direct.code"].exists)
        XCTAssertFalse(app.buttons["completion.copy"].exists)
        XCTAssertFalse(app.buttons["study.start"].exists)
        app.buttons["study.transfer.retry"].tap()
        XCTAssertTrue(app.staticTexts["completion.direct.code"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["completion.copy"].exists)
    }

    @MainActor
    private func makeApp(
        feed: String,
        language: String = "de",
        suite: String = "de.eachandevery.cuelens.uitest.\(UUID().uuidString)",
        interfaceStyle: String? = nil,
        activation: String? = nil,
        feedback: String? = nil,
        study: String? = nil
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
        if let feedback {
            app.launchArguments += ["--ui-test-feedback", feedback]
        }
        if let study {
            app.launchArguments += ["--ui-test-study", study]
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
