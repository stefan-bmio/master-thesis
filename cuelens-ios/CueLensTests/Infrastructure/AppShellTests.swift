import Foundation
import XCTest
@testable import CueLens

final class AppShellTests: XCTestCase {
    @MainActor
    func testSystemLanguageDefaultsToEnglishOnlyForPrimaryEnglishLanguage() async throws {
        let english = makeModel(preferredLanguages: ["en-GB", "de-CH"])
        await english.initialize(lifecyclePhase: .active)
        XCTAssertEqual(english.language, .english)

        let german = makeModel(preferredLanguages: ["fr-CH", "en-US"])
        await german.initialize(lifecyclePhase: .active)
        XCTAssertEqual(german.language, .german)
    }

    @MainActor
    func testPersistedLanguageWinsAndToggleIsSavedWithoutRestart() async throws {
        let settings = SettingsStub(settings: AppSettings(
            selectedLanguage: .english,
            dismissedMessageIDs: [],
            knownMessageIDs: []
        ))
        let model = makeModel(settings: settings, preferredLanguages: ["de-CH"])
        await model.initialize(lifecyclePhase: .active)
        XCTAssertEqual(model.language, .english)

        await model.toggleLanguage()
        XCTAssertEqual(model.language, .german)
        let savedLanguage = try await settings.load().selectedLanguage
        XCTAssertEqual(savedLanguage, .german)
    }

    @MainActor
    func testFeedWaitsForActiveSceneAndPrivacyCurtainTracksLifecycle() async throws {
        let feed = FeedStub(messages: [message(id: 1, seconds: 1)])
        let model = makeModel(feed: feed)
        await model.initialize(lifecyclePhase: .inactive)
        let initialLoadCount = await feed.currentLoadCount()
        XCTAssertEqual(initialLoadCount, 0)
        XCTAssertTrue(model.showsPrivacyCurtain)

        await model.updateLifecycle(.active)
        let activeLoadCount = await feed.currentLoadCount()
        XCTAssertEqual(activeLoadCount, 1)
        XCTAssertEqual(model.route, .infoFeed)
        XCTAssertFalse(model.showsPrivacyCurtain)

        await model.updateLifecycle(.background)
        XCTAssertTrue(model.showsPrivacyCurtain)
    }

    @MainActor
    func testFeedFailureDoesNotBlockHome() async throws {
        let model = makeModel(feed: FeedStub(failsLoad: true))
        await model.initialize(lifecyclePhase: .active)
        XCTAssertEqual(model.route, .home)
        XCTAssertEqual(model.notice, .feedLoadFailed)
    }

    @MainActor
    func testUnreadableSettingsUseSystemLanguageWithoutBlockingHome() async throws {
        let model = CueLensAppModel(
            environment: AppEnvironment(
                persistence: PersistenceLoaderStub(),
                settings: FailingSettingsStub(),
                infoFeed: FeedStub()
            ),
            preferredLanguages: ["en-US"]
        )
        await model.initialize(lifecyclePhase: .active)
        XCTAssertEqual(model.language, .english)
        XCTAssertEqual(model.route, .home)
        XCTAssertEqual(model.notice, .settingSaveFailed)
    }

    @MainActor
    func testConfigurationFailureBecomesVisibleWhenSceneIsActive() async {
        let model = CueLensAppModel(configurationFailure: ())
        await model.initialize(lifecyclePhase: .active)
        XCTAssertEqual(model.route, .secureStorageFailure)
        XCTAssertFalse(model.showsPrivacyCurtain)
    }

    @MainActor
    func testAllFetchedIDsBecomeKnownWhenEveryMessageWasDismissed() async throws {
        let feed = FeedStub(messages: [], fetchedIDs: [4, 5])
        let model = makeModel(feed: feed)
        await model.initialize(lifecyclePhase: .active)
        XCTAssertEqual(model.route, .home)
        let knownIDs = await feed.currentKnownIDs()
        XCTAssertEqual(knownIDs, [4, 5])
    }

    @MainActor
    func testSuccessfulFeedShowsAppConsentBeforeAnySystemRequest() async throws {
        let settings = SettingsStub(settings: .empty)
        let notifications = AppNotificationStub(requestResult: true)
        let model = makeModel(settings: settings, notifications: notifications)

        await model.initialize(lifecyclePhase: .active)

        XCTAssertEqual(model.route, .notificationConsent)
        XCTAssertTrue(model.notificationOptionEnabled)
        let requestCount = await notifications.currentRequestCount()
        XCTAssertEqual(requestCount, 0)
    }

    @MainActor
    func testDisabledConsentSkipsSystemRequestPersistsFalseAndKeepsCoreAppUsable() async throws {
        let settings = SettingsStub(settings: .empty)
        let notifications = AppNotificationStub(requestResult: true)
        let background = AppBackgroundStub()
        let model = makeModel(
            settings: settings,
            notifications: notifications,
            backgroundRefresh: background
        )
        await model.initialize(lifecyclePhase: .active)

        model.setNotificationOptionEnabled(false)
        await model.completeNotificationConsent()

        XCTAssertEqual(model.route, .home)
        let restored = try await settings.load()
        let requestCount = await notifications.currentRequestCount()
        let disableCount = await notifications.currentDisableCount()
        XCTAssertTrue(restored.notificationPromptCompleted)
        XCTAssertFalse(restored.notificationsEnabled)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(disableCount, 1)
    }

    @MainActor
    func testGrantedConsentPersistsTrueAndReconcilesBackgroundRefresh() async throws {
        let settings = SettingsStub(settings: .empty)
        let notifications = AppNotificationStub(requestResult: true, systemAllowed: true)
        let background = AppBackgroundStub()
        let model = makeModel(
            settings: settings,
            notifications: notifications,
            backgroundRefresh: background
        )
        await model.initialize(lifecyclePhase: .active)

        await model.completeNotificationConsent()

        let restored = try await settings.load()
        let requestCount = await notifications.currentRequestCount()
        let backgroundValues = await background.currentValues()
        XCTAssertTrue(restored.notificationPromptCompleted)
        XCTAssertTrue(restored.notificationsEnabled)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(backgroundValues.last, true)
    }

    @MainActor
    func testDeniedSystemPermissionPersistsFalseAndShowsHome() async throws {
        let settings = SettingsStub(settings: .empty)
        let notifications = AppNotificationStub(requestResult: false)
        let model = makeModel(settings: settings, notifications: notifications)
        await model.initialize(lifecyclePhase: .active)

        await model.completeNotificationConsent()

        let restored = try await settings.load()
        XCTAssertEqual(model.route, .home)
        XCTAssertTrue(restored.notificationPromptCompleted)
        XCTAssertFalse(restored.notificationsEnabled)
    }

    @MainActor
    func testFeedNavigationDismissalAndKnownIDs() async throws {
        let feed = FeedStub(messages: [message(id: 1, seconds: 1), message(id: 2, seconds: 2)])
        let model = makeModel(feed: feed)
        await model.initialize(lifecyclePhase: .active)

        model.setHidePermanently(true)
        await model.confirmCurrentMessage()
        let dismissedIDs = await feed.currentDismissedIDs()
        XCTAssertEqual(dismissedIDs, [1])
        XCTAssertEqual(model.feed?.currentMessage.id, 2)
        XCTAssertEqual(model.feed?.hidePermanently, false)

        await model.navigateBackInFeed()
        XCTAssertEqual(model.feed?.currentMessage.id, 1)
        await model.navigateBackInFeed()
        XCTAssertEqual(model.route, .home)
        let knownIDs = await feed.currentKnownIDs()
        XCTAssertEqual(knownIDs, [1, 2])
    }

    func testRepositoryFiltersOnlyDismissedIDsAndDoesNotPersistText() async throws {
        let settings = SettingsStub(settings: AppSettings(
            selectedLanguage: nil,
            dismissedMessageIDs: [2],
            knownMessageIDs: []
        ))
        let service = MessageServiceStub(messages: [
            message(id: 2, seconds: 2),
            message(id: 3, seconds: 1),
            message(id: 1, seconds: 1)
        ])
        let repository = InfoFeedRepository(service: service, settings: settings)
        let batch = try await repository.loadMessages()
        XCTAssertEqual(batch.visibleMessages.map(\.id), [1, 3])
        XCTAssertEqual(batch.fetchedMessageIDs, [1, 2, 3])
        try await repository.dismissMessage(id: 1)
        let dismissedIDs = try await settings.load().dismissedMessageIDs
        XCTAssertEqual(dismissedIDs, [1, 2])
    }

    func testUserDefaultsStorePersistsLanguageAndPositiveIDsAcrossInstances() async throws {
        let suiteName = "de.eachandevery.cuelens.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = UserDefaultsAppSettingsStore(suiteName: suiteName)
        try await first.saveLanguage(.english)
        try await first.dismissMessage(id: 7)
        try await first.dismissMessage(id: -1)
        try await first.markMessagesKnown(ids: [7, 8, 0])
        try await first.completeNotificationPrompt(enabled: true)

        let restored = try await UserDefaultsAppSettingsStore(suiteName: suiteName).load()
        XCTAssertEqual(restored.selectedLanguage, .english)
        XCTAssertEqual(restored.dismissedMessageIDs, [7])
        XCTAssertEqual(restored.knownMessageIDs, [7, 8])
        XCTAssertTrue(restored.notificationPromptCompleted)
        XCTAssertTrue(restored.notificationsEnabled)
        XCTAssertNil(defaults.string(forKey: "message_text"))
    }

    func testNotificationPreferenceCannotBeEnabledBeforeConsentWasCompleted() async throws {
        let suiteName = "de.eachandevery.cuelens.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "notifications_enabled")

        let settings = try await UserDefaultsAppSettingsStore(suiteName: suiteName).load()

        XCTAssertFalse(settings.notificationPromptCompleted)
        XCTAssertFalse(settings.notificationsEnabled)
    }

    @MainActor
    func testInformationNotificationRouteReloadsFeedWhenAppBecomesActive() async {
        let routes = NotificationRouteInbox()
        let feed = FeedStub()
        let model = CueLensAppModel(
            environment: AppEnvironment(
                persistence: PersistenceLoaderStub(),
                settings: SettingsStub(settings: AppSettings(
                    selectedLanguage: nil,
                    dismissedMessageIDs: [],
                    knownMessageIDs: [],
                    notificationPromptCompleted: true,
                    notificationsEnabled: false
                )),
                infoFeed: feed,
                notificationRoutes: routes
            )
        )
        await model.initialize(lifecyclePhase: .active)
        await model.updateLifecycle(.background)
        await routes.record(.informationFeed)

        await model.updateLifecycle(.active)

        let loadCount = await feed.currentLoadCount()
        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(model.route, .home)
    }

    @MainActor
    func testActivationAcceptsEmailAndReturnsActivatedAppToHome() async throws {
        let activation = AppActivationStub(
            requestOutcome: .readyToConfirm,
            confirmationOutcome: .activated
        )
        let model = makeModel(activation: activation)
        await model.initialize(lifecyclePhase: .active)
        model.openActivation()
        model.updateActivationInput("  Person@Example.org  ")

        XCTAssertEqual(model.route, .activation)
        XCTAssertTrue(model.activationInputIsValid)
        await model.activate()

        XCTAssertEqual(model.route, .home)
        XCTAssertTrue(model.isActivated)
        XCTAssertEqual(model.activationState, .activated)
        XCTAssertEqual(model.activationInput, "")
        let identifiers = await activation.currentIdentifiers()
        XCTAssertEqual(identifiers, [.directEmail("Person@Example.org")])
    }

    @MainActor
    func testActivationPreservesTrimmedProlificIDAndRejectsInvalidInputLocally() async {
        let activation = AppActivationStub(
            requestOutcome: .readyToConfirm,
            confirmationOutcome: .activated
        )
        let model = makeModel(activation: activation)
        await model.initialize(lifecyclePhase: .active)
        model.openActivation()
        model.updateActivationInput("invalid")

        XCTAssertFalse(model.activationInputIsValid)
        await model.activate()
        var identifiers = await activation.currentIdentifiers()
        XCTAssertTrue(identifiers.isEmpty)

        model.updateActivationInput("  AbCdEf1234567890GhIjKlMn\n")
        XCTAssertTrue(model.activationInputIsValid)
        await model.activate()
        identifiers = await activation.currentIdentifiers()
        XCTAssertEqual(identifiers, [.prolificID("AbCdEf1234567890GhIjKlMn")])
    }

    @MainActor
    func testActivationFailuresClearIdentifierAndUsePhaseSpecificState() async {
        let requestFailure = AppActivationStub(
            requestOutcome: .failed,
            confirmationOutcome: .ignored
        )
        let requestModel = makeModel(activation: requestFailure)
        await requestModel.initialize(lifecyclePhase: .active)
        requestModel.openActivation()
        requestModel.updateActivationInput("person@example.org")
        await requestModel.activate()
        XCTAssertEqual(requestModel.activationState, .failed)
        XCTAssertEqual(requestModel.activationInput, "")

        let timeout = AppActivationStub(
            requestOutcome: .readyToConfirm,
            confirmationOutcome: .supportRequired
        )
        let timeoutModel = makeModel(activation: timeout)
        await timeoutModel.initialize(lifecyclePhase: .active)
        timeoutModel.openActivation()
        timeoutModel.updateActivationInput("person@example.org")
        await timeoutModel.activate()
        XCTAssertEqual(timeoutModel.route, .activation)
        XCTAssertEqual(timeoutModel.activationState, .supportRequired)
        XCTAssertEqual(timeoutModel.activationInput, "")
        XCTAssertFalse(timeoutModel.activationInputIsEnabled)
        XCTAssertFalse(timeoutModel.activationInputIsValid)
        timeoutModel.updateActivationInput("second@example.org")
        XCTAssertEqual(timeoutModel.activationInput, "")
        timeoutModel.cancelActivation()
        XCTAssertEqual(timeoutModel.route, .home)
        timeoutModel.openActivation()
        XCTAssertEqual(timeoutModel.route, .home)
        XCTAssertEqual(timeoutModel.activationState, .idle)
    }

    @MainActor
    func testActivationStorageFailureAndRecoveredUncertaintyFailClosed() async {
        let storageFailure = AppActivationStub(
            requestOutcome: .readyToConfirm,
            confirmationOutcome: .secureStorageFailure
        )
        let model = makeModel(activation: storageFailure)
        await model.initialize(lifecyclePhase: .active)
        model.openActivation()
        model.updateActivationInput("person@example.org")
        await model.activate()
        XCTAssertEqual(model.route, .home)
        XCTAssertTrue(model.hasTokenStorageFailure)
        XCTAssertFalse(model.isActivated)

        let restored = makeModel(
            persistence: PersistenceLoaderStub(activationRequiresSupport: true)
        )
        await restored.initialize(lifecyclePhase: .active)
        XCTAssertEqual(restored.route, .home)
        XCTAssertTrue(restored.hasTokenStorageFailure)
        restored.openActivation()
        XCTAssertEqual(restored.route, .home)
    }

    @MainActor
    func testAlreadyActivatedAppCannotOpenActivationAgain() async {
        let model = makeModel(persistence: PersistenceLoaderStub(isActivated: true))
        await model.initialize(lifecyclePhase: .active)

        XCTAssertTrue(model.isActivated)
        model.openActivation()
        XCTAssertEqual(model.route, .home)
    }

    @MainActor
    private func makeModel(
        persistence: PersistenceLoaderStub = PersistenceLoaderStub(),
        settings: SettingsStub = SettingsStub(settings: AppSettings(
            selectedLanguage: nil,
            dismissedMessageIDs: [],
            knownMessageIDs: [],
            notificationPromptCompleted: true,
            notificationsEnabled: false
        )),
        feed: FeedStub = FeedStub(),
        preferredLanguages: [String] = ["de-CH"],
        notifications: AppNotificationStub = AppNotificationStub(),
        backgroundRefresh: AppBackgroundStub = AppBackgroundStub(),
        activation: AppActivationStub = AppActivationStub()
    ) -> CueLensAppModel {
        CueLensAppModel(
            environment: AppEnvironment(
                persistence: persistence,
                settings: settings,
                infoFeed: feed,
                activation: activation,
                notifications: notifications,
                backgroundRefresh: backgroundRefresh
            ),
            preferredLanguages: preferredLanguages
        )
    }

    private func message(id: Int64, seconds: TimeInterval) -> InfoMessage {
        InfoMessage(
            id: id,
            createdAt: Date(timeIntervalSince1970: seconds),
            textGerman: "Synthetische Nachricht \(id)",
            textEnglish: "Synthetic message \(id)"
        )
    }
}

private struct PersistenceLoaderStub: LocalPersistenceLoading {
    let isActivated: Bool
    let activationRequiresSupport: Bool

    init(isActivated: Bool = false, activationRequiresSupport: Bool = false) {
        self.isActivated = isActivated
        self.activationRequiresSupport = activationRequiresSupport
    }

    func load() async throws -> LocalPersistenceSnapshot {
        LocalPersistenceSnapshot(
            installation: .existingInstallation,
            studyState: try StudyState.initial,
            isActivated: isActivated,
            activationRequiresSupport: activationRequiresSupport
        )
    }
}

private actor AppActivationStub: ActivationManaging {
    private let requestOutcome: ActivationTokenRequestOutcome
    private let confirmationOutcome: ActivationConfirmationOutcome
    private var identifiers: [ParticipantIdentifier] = []

    init(
        requestOutcome: ActivationTokenRequestOutcome = .failed,
        confirmationOutcome: ActivationConfirmationOutcome = .failed
    ) {
        self.requestOutcome = requestOutcome
        self.confirmationOutcome = confirmationOutcome
    }

    func requestToken(identifier: ParticipantIdentifier) async -> ActivationTokenRequestOutcome {
        identifiers.append(identifier)
        return requestOutcome
    }

    func confirmPendingToken() async -> ActivationConfirmationOutcome {
        confirmationOutcome
    }

    func currentIdentifiers() -> [ParticipantIdentifier] { identifiers }
}

private actor SettingsStub: AppSettingsStoring {
    private var settings: AppSettings
    init(settings: AppSettings = .empty) { self.settings = settings }
    func load() async throws -> AppSettings { settings }
    func saveLanguage(_ language: AppLanguage) async throws { settings.selectedLanguage = language }
    func dismissMessage(id: Int64) async throws { if id > 0 { settings.dismissedMessageIDs.insert(id) } }
    func markMessagesKnown(ids: Set<Int64>) async throws { settings.knownMessageIDs.formUnion(ids.filter { $0 > 0 }) }
    func completeNotificationPrompt(enabled: Bool) async throws {
        settings.notificationPromptCompleted = true
        settings.notificationsEnabled = enabled
    }
}

private actor FailingSettingsStub: AppSettingsStoring {
    func load() async throws -> AppSettings { throw TestError.expected }
    func saveLanguage(_ language: AppLanguage) async throws { throw TestError.expected }
    func dismissMessage(id: Int64) async throws { throw TestError.expected }
    func markMessagesKnown(ids: Set<Int64>) async throws { throw TestError.expected }
    func completeNotificationPrompt(enabled: Bool) async throws { throw TestError.expected }
}

private actor FeedStub: InfoFeedRepositoryServing {
    private let messages: [InfoMessage]
    private let fetchedIDs: Set<Int64>
    private let failsLoad: Bool
    private(set) var loadCount = 0
    private(set) var dismissedIDs: Set<Int64> = []
    private(set) var knownIDs: Set<Int64> = []

    init(
        messages: [InfoMessage] = [],
        fetchedIDs: Set<Int64>? = nil,
        failsLoad: Bool = false
    ) {
        self.messages = messages
        self.fetchedIDs = fetchedIDs ?? Set(messages.map(\.id))
        self.failsLoad = failsLoad
    }
    func loadMessages() async throws -> InfoFeedBatch {
        loadCount += 1
        if failsLoad { throw TestError.expected }
        return InfoFeedBatch(
            visibleMessages: messages,
            fetchedMessageIDs: fetchedIDs
        )
    }
    func dismissMessage(id: Int64) async throws { dismissedIDs.insert(id) }
    func markMessagesKnown(ids: Set<Int64>) async throws { knownIDs.formUnion(ids) }
    func currentLoadCount() -> Int { loadCount }
    func currentDismissedIDs() -> Set<Int64> { dismissedIDs }
    func currentKnownIDs() -> Set<Int64> { knownIDs }
}

private actor MessageServiceStub: InfoFeedServicing {
    let messages: [InfoMessage]
    init(messages: [InfoMessage]) { self.messages = messages }
    func fetchMessages() async throws -> [InfoMessage] { messages }
}

private enum TestError: Error { case expected }

private actor AppNotificationStub: NotificationManaging {
    private let requestResult: Bool
    private let systemAllowed: Bool
    private var requestCount = 0
    private var disableCount = 0

    init(requestResult: Bool = false, systemAllowed: Bool = false) {
        self.requestResult = requestResult
        self.systemAllowed = systemAllowed
    }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        return requestResult
    }
    func systemAuthorizationAllowed() async -> Bool { systemAllowed }
    func reconcileStudyReminder(_ context: StudyReminderContext) async {}
    func scheduleInformationNotification(language: AppLanguage) async {}
    func disableAll() async { disableCount += 1 }
    func currentRequestCount() -> Int { requestCount }
    func currentDisableCount() -> Int { disableCount }
}

private actor AppBackgroundStub: BackgroundRefreshManaging {
    private var values: [Bool] = []
    func reconcile(enabled: Bool) async { values.append(enabled) }
    func currentValues() -> [Bool] { values }
}
