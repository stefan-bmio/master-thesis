import Foundation
import XCTest
@testable import CueLens

final class BackgroundRefreshCoordinatorTests: XCTestCase {
    func testSuccessfulCheckMarksAllIDsAndNotifiesOnceForNewVisibleMessages() async throws {
        let settings = BackgroundSettingsStub(settings: AppSettings(
            selectedLanguage: .english,
            dismissedMessageIDs: [3],
            knownMessageIDs: [1],
            notificationPromptCompleted: true,
            notificationsEnabled: true
        ))
        let service = BackgroundMessageServiceStub(messages: [
            message(1), message(2), message(3)
        ])
        let notifications = BackgroundNotificationStub(systemAllowed: true)
        let checker = InfoFeedBackgroundChecker(
            settings: settings,
            service: service,
            notifications: notifications
        )

        let succeeded = await checker.run()
        let restored = try await settings.load()
        let languages = await notifications.currentInformationLanguages()
        XCTAssertTrue(succeeded)
        XCTAssertEqual(restored.knownMessageIDs, [1, 2, 3])
        XCTAssertEqual(languages, [.english])
    }

    func testNoNewMessageDoesNotNotify() async {
        let settings = BackgroundSettingsStub(settings: AppSettings(
            selectedLanguage: .german,
            dismissedMessageIDs: [],
            knownMessageIDs: [1],
            notificationPromptCompleted: true,
            notificationsEnabled: true
        ))
        let notifications = BackgroundNotificationStub(systemAllowed: true)
        let checker = InfoFeedBackgroundChecker(
            settings: settings,
            service: BackgroundMessageServiceStub(messages: [message(1)]),
            notifications: notifications
        )

        let succeeded = await checker.run()
        let languages = await notifications.currentInformationLanguages()
        XCTAssertTrue(succeeded)
        XCTAssertTrue(languages.isEmpty)
    }

    func testDisabledOrSystemDeniedCheckDoesNotFetch() async {
        for (enabled, allowed) in [(false, true), (true, false)] {
            let settings = BackgroundSettingsStub(settings: AppSettings(
                selectedLanguage: nil,
                dismissedMessageIDs: [],
                knownMessageIDs: [],
                notificationPromptCompleted: true,
                notificationsEnabled: enabled
            ))
            let service = BackgroundMessageServiceStub(messages: [message(1)])
            let checker = InfoFeedBackgroundChecker(
                settings: settings,
                service: service,
                notifications: BackgroundNotificationStub(systemAllowed: allowed)
            )

            let succeeded = await checker.run()
            let fetchCount = await service.currentFetchCount()
            XCTAssertFalse(succeeded)
            XCTAssertEqual(fetchCount, 0)
        }
    }

    func testFetchFailureDoesNotChangeKnownIDsOrNotify() async throws {
        let settings = BackgroundSettingsStub(settings: AppSettings(
            selectedLanguage: .german,
            dismissedMessageIDs: [],
            knownMessageIDs: [1],
            notificationPromptCompleted: true,
            notificationsEnabled: true
        ))
        let notifications = BackgroundNotificationStub(systemAllowed: true)
        let checker = InfoFeedBackgroundChecker(
            settings: settings,
            service: BackgroundMessageServiceStub(fails: true),
            notifications: notifications
        )

        let succeeded = await checker.run()
        let restored = try await settings.load()
        let languages = await notifications.currentInformationLanguages()
        XCTAssertFalse(succeeded)
        XCTAssertEqual(restored.knownMessageIDs, [1])
        XCTAssertTrue(languages.isEmpty)
    }

    private func message(_ id: Int64) -> InfoMessage {
        InfoMessage(
            id: id,
            createdAt: Date(timeIntervalSince1970: Double(id)),
            textGerman: "Synthetische Nachricht \(id)",
            textEnglish: "Synthetic message \(id)"
        )
    }
}

private actor BackgroundSettingsStub: AppSettingsStoring {
    private var settings: AppSettings
    init(settings: AppSettings) { self.settings = settings }
    func load() async throws -> AppSettings { settings }
    func saveLanguage(_ language: AppLanguage) async throws { settings.selectedLanguage = language }
    func dismissMessage(id: Int64) async throws { settings.dismissedMessageIDs.insert(id) }
    func markMessagesKnown(ids: Set<Int64>) async throws { settings.knownMessageIDs.formUnion(ids) }
    func completeNotificationPrompt(enabled: Bool) async throws {
        settings.notificationPromptCompleted = true
        settings.notificationsEnabled = enabled
    }
}

private actor BackgroundMessageServiceStub: InfoFeedServicing {
    private let messages: [InfoMessage]
    private let fails: Bool
    private var fetchCount = 0
    init(messages: [InfoMessage] = [], fails: Bool = false) {
        self.messages = messages
        self.fails = fails
    }
    func fetchMessages() async throws -> [InfoMessage] {
        fetchCount += 1
        if fails { throw BackgroundTestError.expected }
        return messages
    }
    func currentFetchCount() -> Int { fetchCount }
}

private actor BackgroundNotificationStub: NotificationManaging {
    private let systemAllowed: Bool
    private var informationLanguages: [AppLanguage] = []
    init(systemAllowed: Bool) { self.systemAllowed = systemAllowed }
    func requestAuthorization() async -> Bool { systemAllowed }
    func systemAuthorizationAllowed() async -> Bool { systemAllowed }
    func reconcileStudyReminder(_ context: StudyReminderContext) async {}
    func scheduleInformationNotification(language: AppLanguage) async {
        informationLanguages.append(language)
    }
    func disableAll() async {}
    func currentInformationLanguages() -> [AppLanguage] { informationLanguages }
}

private enum BackgroundTestError: Error { case expected }
