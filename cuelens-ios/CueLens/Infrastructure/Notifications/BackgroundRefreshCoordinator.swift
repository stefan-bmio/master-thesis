import BackgroundTasks
import Foundation

actor InfoFeedBackgroundChecker {
    private let settings: any AppSettingsStoring
    private let service: any InfoFeedServicing
    private let notifications: any NotificationManaging
    private let preferredLanguages: @Sendable () -> [String]

    init(
        settings: any AppSettingsStoring,
        service: any InfoFeedServicing,
        notifications: any NotificationManaging,
        preferredLanguages: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
    ) {
        self.settings = settings
        self.service = service
        self.notifications = notifications
        self.preferredLanguages = preferredLanguages
    }

    func run() async -> Bool {
        do {
            let preferences = try await settings.load()
            guard preferences.notificationsEnabled,
                  await notifications.systemAuthorizationAllowed() else {
                return false
            }
            let messages = try await service.fetchMessages()
            let fetchedIDs = Set(messages.map(\.id).filter { $0 > 0 })
            let newIDs = fetchedIDs
                .subtracting(preferences.knownMessageIDs)
                .subtracting(preferences.dismissedMessageIDs)
            try await settings.markMessagesKnown(ids: fetchedIDs)
            if !newIDs.isEmpty {
                let language = preferences.selectedLanguage
                    ?? SystemLanguageResolver.resolve(preferredLanguages: preferredLanguages())
                await notifications.scheduleInformationNotification(language: language)
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }

    func isEnabled() async -> Bool {
        guard let preferences = try? await settings.load(),
              preferences.notificationsEnabled else {
            return false
        }
        return await notifications.systemAuthorizationAllowed()
    }
}

final class BackgroundRefreshCoordinator: BackgroundRefreshManaging, @unchecked Sendable {
    static let identifier = "de.eachandevery.cuelens.infofeed.refresh"
    static let interval: TimeInterval = 24 * 60 * 60

    private let checker: InfoFeedBackgroundChecker
    private let notifications: any NotificationManaging
    private let scheduler: BGTaskScheduler

    init(
        checker: InfoFeedBackgroundChecker,
        notifications: any NotificationManaging,
        scheduler: BGTaskScheduler = .shared
    ) {
        self.checker = checker
        self.notifications = notifications
        self.scheduler = scheduler
    }

    @discardableResult
    func register() -> Bool {
        scheduler.register(forTaskWithIdentifier: Self.identifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func reconcile(enabled: Bool) async {
        guard enabled, await notifications.systemAuthorizationAllowed() else {
            scheduler.cancel(taskRequestWithIdentifier: Self.identifier)
            return
        }
        scheduleNext()
    }

    private func handle(_ task: BGAppRefreshTask) {
        let completion = BackgroundTaskCompletion(task: task)
        let operation = Task { [checker, weak self] in
            guard await checker.isEnabled() else {
                completion.complete(success: false)
                return
            }
            self?.scheduleNext()
            let success = await checker.run()
            completion.complete(success: success)
        }
        task.expirationHandler = {
            operation.cancel()
        }
    }

    private func scheduleNext() {
        scheduler.cancel(taskRequestWithIdentifier: Self.identifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.interval)
        try? scheduler.submit(request)
    }
}

private final class BackgroundTaskCompletion: @unchecked Sendable {
    private let task: BGAppRefreshTask

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    func complete(success: Bool) {
        task.setTaskCompleted(success: success)
    }
}
