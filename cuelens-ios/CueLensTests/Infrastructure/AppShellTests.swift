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

        let restored = try await UserDefaultsAppSettingsStore(suiteName: suiteName).load()
        XCTAssertEqual(restored.selectedLanguage, .english)
        XCTAssertEqual(restored.dismissedMessageIDs, [7])
        XCTAssertEqual(restored.knownMessageIDs, [7, 8])
        XCTAssertNil(defaults.string(forKey: "message_text"))
    }

    @MainActor
    private func makeModel(
        settings: SettingsStub = SettingsStub(),
        feed: FeedStub = FeedStub(),
        preferredLanguages: [String] = ["de-CH"]
    ) -> CueLensAppModel {
        CueLensAppModel(
            environment: AppEnvironment(
                persistence: PersistenceLoaderStub(),
                settings: settings,
                infoFeed: feed
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
    func load() async throws -> LocalPersistenceSnapshot {
        LocalPersistenceSnapshot(
            installation: .existingInstallation,
            studyState: try StudyState.initial
        )
    }
}

private actor SettingsStub: AppSettingsStoring {
    private var settings: AppSettings
    init(settings: AppSettings = .empty) { self.settings = settings }
    func load() async throws -> AppSettings { settings }
    func saveLanguage(_ language: AppLanguage) async throws { settings.selectedLanguage = language }
    func dismissMessage(id: Int64) async throws { if id > 0 { settings.dismissedMessageIDs.insert(id) } }
    func markMessagesKnown(ids: Set<Int64>) async throws { settings.knownMessageIDs.formUnion(ids.filter { $0 > 0 }) }
}

private actor FailingSettingsStub: AppSettingsStoring {
    func load() async throws -> AppSettings { throw TestError.expected }
    func saveLanguage(_ language: AppLanguage) async throws { throw TestError.expected }
    func dismissMessage(id: Int64) async throws { throw TestError.expected }
    func markMessagesKnown(ids: Set<Int64>) async throws { throw TestError.expected }
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
