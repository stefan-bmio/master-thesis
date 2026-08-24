import Foundation
import XCTest
@testable import CueLens

final class PreStudyAppModelTests: XCTestCase {
    @MainActor
    func testDemoRunsLocallyThroughAllStepsAndIsDiscardedOnExit() async throws {
        let randomizer = SequenceDemoRandomizer(values: [false, true])
        let feedback = FeedbackManagerStub()
        let model = makeModel(
            feedback: feedback,
            randomizer: randomizer,
            clock: ImmediateDemoClock()
        )
        await model.initialize(lifecyclePhase: .active)

        await model.openDemo()
        for _ in 0..<20 where model.demo?.remainingSeconds != 0 {
            await Task.yield()
        }
        XCTAssertEqual(model.demo?.matchingChoices, [.matchA, .matchB])
        XCTAssertEqual(model.demo?.remainingSeconds, 0)

        await model.selectDemoMatching()
        XCTAssertEqual(model.demo?.labelingChoices, [.lessFitting, .fitting])
        let orderBeforeLanguageSwitch = model.demo?.labelingChoices
        await model.toggleLanguage()
        XCTAssertEqual(model.demo?.labelingChoices, orderBeforeLanguageSwitch)

        model.selectDemoLabel()
        XCTAssertEqual(model.demo?.step, .craving)
        XCTAssertEqual(model.demo?.craving, 50)
        model.updateDemoCraving(100)
        model.completeDemoCraving()
        XCTAssertEqual(model.demo?.step, .completed)
        model.leaveDemo()
        XCTAssertEqual(model.route, .home)
        XCTAssertNil(model.demo)
        let feedbackCalls = await feedback.currentDrafts()
        XCTAssertTrue(feedbackCalls.isEmpty)
    }

    @MainActor
    func testInactiveDemoDoesNotAdvanceUntilForeground() async throws {
        let model = makeModel(clock: ImmediateDemoClock())
        await model.initialize(lifecyclePhase: .active)
        await model.updateLifecycle(.inactive)
        await model.openDemo()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(model.demo?.remainingSeconds, 5)

        await model.updateLifecycle(.active)
        for _ in 0..<20 where model.demo?.remainingSeconds != 0 {
            await Task.yield()
        }
        XCTAssertEqual(model.demo?.remainingSeconds, 0)
    }

    @MainActor
    func testBackgroundTimeDoesNotAdvanceRunningCountdown() async throws {
        let model = makeModel(clock: ContinuousDemoSleepClock())
        await model.initialize(lifecyclePhase: .active)
        await model.openDemo()
        try await Task.sleep(for: .milliseconds(1_200))
        let foregroundValue = try XCTUnwrap(model.demo?.remainingSeconds)
        XCTAssertLessThan(foregroundValue, 5)

        await model.updateLifecycle(.background)
        try await Task.sleep(for: .milliseconds(1_500))
        XCTAssertEqual(model.demo?.remainingSeconds, foregroundValue)

        await model.updateLifecycle(.active)
        try await Task.sleep(for: .milliseconds(1_200))
        XCTAssertLessThan(try XCTUnwrap(model.demo?.remainingSeconds), foregroundValue)
        model.leaveDemo()
    }

    @MainActor
    func testFeedbackFailureKeepsFormAndSuccessClearsIt() async throws {
        let feedback = FeedbackManagerStub(outcomes: [.failed, .submitted])
        let model = makeModel(feedback: feedback)
        await model.initialize(lifecyclePhase: .active)
        model.openFeedback()
        model.updateFeedbackSource("  Flyer  ")
        model.updateFeedbackComment("  Verständlich.  ")

        XCTAssertTrue(model.feedbackInputIsValid)
        await model.submitFeedback()
        XCTAssertEqual(model.feedbackState, .failed)
        XCTAssertEqual(model.feedbackSource, "  Flyer  ")
        XCTAssertEqual(model.feedbackComment, "  Verständlich.  ")

        await model.submitFeedback()
        XCTAssertEqual(model.feedbackState, .submitted)
        XCTAssertEqual(model.feedbackSource, "")
        XCTAssertEqual(model.feedbackComment, "")
        let drafts = await feedback.currentDrafts()
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts.first?.source, "Flyer")
        XCTAssertEqual(drafts.first?.comment, "Verständlich.")
    }

    @MainActor
    func testLanguageChangeDuringFeedbackRequestDoesNotChangeDraft() async throws {
        let feedback = FeedbackManagerStub(delay: .milliseconds(150))
        let model = makeModel(feedback: feedback)
        await model.initialize(lifecyclePhase: .active)
        model.openFeedback()
        model.updateFeedbackSource("Flyer")
        model.updateFeedbackComment("Verständlich")

        let submission = Task { @MainActor in await model.submitFeedback() }
        for _ in 0..<20 where model.feedbackState != .submitting { await Task.yield() }
        XCTAssertEqual(model.feedbackState, .submitting)
        await model.toggleLanguage()
        await submission.value

        let drafts = await feedback.currentDrafts()
        XCTAssertEqual(drafts, [try FeedbackDraft(source: "Flyer", comment: "Verständlich")])
        XCTAssertEqual(model.language, .english)
    }

    @MainActor
    func testFeedbackValidationUsesUnicodeScalarLimits() async throws {
        let model = makeModel()
        await model.initialize(lifecyclePhase: .active)
        model.openFeedback()
        XCTAssertFalse(model.feedbackInputIsValid)
        model.updateFeedbackSource(String(repeating: "é", count: 500))
        XCTAssertTrue(model.feedbackInputIsValid)
        model.updateFeedbackSource(String(repeating: "é", count: 501))
        XCTAssertFalse(model.feedbackInputIsValid)
        model.updateFeedbackSource("")
        model.updateFeedbackComment(String(repeating: "a", count: 5_000))
        XCTAssertTrue(model.feedbackInputIsValid)
        model.updateFeedbackComment(String(repeating: "a", count: 5_001))
        XCTAssertFalse(model.feedbackInputIsValid)
    }

    @MainActor
    func testCompletionHidesDemoButKeepsFeedbackAvailable() async throws {
        let completedState = try StudyState(
            confirmedSituationCount: 20,
            matchingOrder: Array(0..<50),
            completion: .prolificCompleted
        )
        let model = makeModel(state: completedState, isActivated: true)
        await model.initialize(lifecyclePhase: .active)

        XCTAssertTrue(model.isStudyCompleted)
        XCTAssertFalse(model.canOpenDemo)
        await model.openDemo()
        XCTAssertEqual(model.route, .home)
        model.openFeedback()
        XCTAssertEqual(model.route, .feedback)
    }

    @MainActor
    func testActivationRecoveryFailureKeepsDemoAndFeedbackAvailable() async throws {
        let model = makeModel(activationRequiresSupport: true, tokenStorageFailed: true)
        await model.initialize(lifecyclePhase: .active)

        XCTAssertEqual(model.route, .home)
        XCTAssertTrue(model.hasTokenStorageFailure)
        model.openActivation()
        XCTAssertEqual(model.route, .home)
        await model.openDemo()
        XCTAssertEqual(model.route, .demo)
        model.leaveDemo()
        model.openFeedback()
        XCTAssertEqual(model.route, .feedback)
    }

    @MainActor
    func testPrivacyUsesCurrentLanguageAndContactHasNoPayload() async throws {
        let links = ExternalLinkManagerStub()
        let model = makeModel(links: links)
        await model.initialize(lifecyclePhase: .active)

        await model.openPrivacyInformation()
        await model.toggleLanguage()
        await model.openPrivacyInformation()
        await model.openRightsContact()

        let actions = await links.currentActions()
        XCTAssertEqual(actions, [.privacy(.german), .privacy(.english), .contact])
    }

    @MainActor
    private func makeModel(
        state: StudyState? = nil,
        isActivated: Bool = false,
        activationRequiresSupport: Bool = false,
        tokenStorageFailed: Bool = false,
        feedback: FeedbackManagerStub = FeedbackManagerStub(),
        links: ExternalLinkManagerStub = ExternalLinkManagerStub(),
        randomizer: SequenceDemoRandomizer = SequenceDemoRandomizer(values: [false, false]),
        clock: any DemoSleepClock = SlowDemoClock()
    ) -> CueLensAppModel {
        CueLensAppModel(
            environment: AppEnvironment(
                persistence: PreStudyPersistenceLoader(
                    state: state,
                    isActivated: isActivated,
                    activationRequiresSupport: activationRequiresSupport,
                    tokenStorageFailed: tokenStorageFailed
                ),
                settings: PreStudySettingsStub(),
                infoFeed: PreStudyFeedStub(),
                feedback: feedback,
                externalLinks: links,
                demoRandomizer: randomizer,
                demoClock: clock
            ),
            preferredLanguages: ["de-CH"]
        )
    }
}

private struct PreStudyPersistenceLoader: LocalPersistenceLoading {
    let state: StudyState?
    let isActivated: Bool
    let activationRequiresSupport: Bool
    let tokenStorageFailed: Bool

    func load() async throws -> LocalPersistenceSnapshot {
        LocalPersistenceSnapshot(
            installation: .existingInstallation,
            studyState: try state ?? StudyState.initial,
            isActivated: isActivated,
            activationRequiresSupport: activationRequiresSupport,
            tokenStorageFailed: tokenStorageFailed
        )
    }
}

private actor PreStudySettingsStub: AppSettingsStoring {
    private var language: AppLanguage?
    func load() async throws -> AppSettings {
        AppSettings(
            selectedLanguage: language,
            dismissedMessageIDs: [],
            knownMessageIDs: [],
            notificationPromptCompleted: true,
            notificationsEnabled: false
        )
    }
    func saveLanguage(_ language: AppLanguage) async throws { self.language = language }
    func dismissMessage(id: Int64) async throws {}
    func markMessagesKnown(ids: Set<Int64>) async throws {}
    func completeNotificationPrompt(enabled: Bool) async throws {}
}

private actor PreStudyFeedStub: InfoFeedRepositoryServing {
    func loadMessages() async throws -> InfoFeedBatch {
        InfoFeedBatch(visibleMessages: [], fetchedMessageIDs: [])
    }
    func dismissMessage(id: Int64) async throws {}
    func markMessagesKnown(ids: Set<Int64>) async throws {}
}

private actor FeedbackManagerStub: FeedbackManaging {
    private var outcomes: [FeedbackSubmissionOutcome]
    private var drafts: [FeedbackDraft] = []
    private let delay: Duration?

    init(
        outcomes: [FeedbackSubmissionOutcome] = [.submitted],
        delay: Duration? = nil
    ) {
        self.outcomes = outcomes
        self.delay = delay
    }

    func submit(_ draft: FeedbackDraft) async -> FeedbackSubmissionOutcome {
        drafts.append(draft)
        if let delay { try? await Task.sleep(for: delay) }
        return outcomes.isEmpty ? .submitted : outcomes.removeFirst()
    }

    func currentDrafts() -> [FeedbackDraft] { drafts }
}

private actor SequenceDemoRandomizer: DemoRandomizing {
    private var values: [Bool]
    init(values: [Bool]) { self.values = values }
    func nextBoolean() -> Bool { values.isEmpty ? false : values.removeFirst() }
}

private struct ImmediateDemoClock: DemoSleepClock {
    func sleepForVisibleSecond() async throws { await Task.yield() }
}

private struct SlowDemoClock: DemoSleepClock {
    func sleepForVisibleSecond() async throws { try await Task.sleep(for: .seconds(60)) }
}

private actor ExternalLinkManagerStub: ExternalLinkManaging {
    enum Action: Equatable, Sendable {
        case privacy(AppLanguage)
        case contact
    }

    private var actions: [Action] = []
    func openPrivacy(language: AppLanguage) async -> Bool {
        actions.append(.privacy(language))
        return true
    }
    func openRightsContact() async -> Bool {
        actions.append(.contact)
        return true
    }
    func currentActions() -> [Action] { actions }
}
