import Foundation
import UserNotifications

actor SystemNotificationCenterClient: NotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func requestAlertAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert])
    }

    func registerCategories(language: AppLanguage) async {
        let categories = AppLanguage.allCases.flatMap { categoryLanguage in
            [
                UNNotificationCategory(
                    identifier: NotificationCoordinator.informationCategoryIdentifier(
                        language: categoryLanguage
                    ),
                    actions: [],
                    intentIdentifiers: [],
                    hiddenPreviewsBodyPlaceholder: NotificationText.informationBody(
                        language: categoryLanguage
                    ),
                    options: []
                ),
                UNNotificationCategory(
                    identifier: NotificationCoordinator.reminderCategoryIdentifier(
                        language: categoryLanguage
                    ),
                    actions: [],
                    intentIdentifiers: [],
                    hiddenPreviewsBodyPlaceholder: NotificationText.publicReminderBody(
                        language: categoryLanguage
                    ),
                    options: []
                )
            ]
        }
        center.setNotificationCategories(Set(categories))
    }

    func add(_ descriptor: LocalNotificationDescriptor) async throws {
        let content = UNMutableNotificationContent()
        content.title = descriptor.title
        content.body = descriptor.body
        content.categoryIdentifier = descriptor.categoryIdentifier
        let trigger: UNNotificationTrigger?
        if let deliveryDate = descriptor.deliveryDate {
            let interval = max(1, deliveryDate.timeIntervalSinceNow)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }
        try await center.add(
            UNNotificationRequest(
                identifier: descriptor.identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    func pendingIdentifiers() async -> Set<String> {
        Set(await center.pendingNotificationRequests().map(\.identifier))
    }

    func deliveredIdentifiers() async -> Set<String> {
        Set(await center.deliveredNotifications().map(\.request.identifier))
    }

    func removePending(identifiers: Set<String>) async {
        center.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
    }

    func removeDelivered(identifiers: Set<String>) async {
        center.removeDeliveredNotifications(withIdentifiers: Array(identifiers))
    }
}

actor NotificationCoordinator: NotificationManaging {
    static let informationIdentifier = "de.eachandevery.cuelens.infofeed.new-information"
    static let reminderIdentifierPrefix = "de.eachandevery.cuelens.study-reminder."

    private let client: any NotificationCenterClient

    init(client: any NotificationCenterClient = SystemNotificationCenterClient()) {
        self.client = client
    }

    func requestAuthorization() async -> Bool {
        switch await client.authorizationState() {
        case .allowed:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await client.requestAlertAuthorization()) == true
        }
    }

    func systemAuthorizationAllowed() async -> Bool {
        await client.authorizationState() == .allowed
    }

    func reconcileStudyReminder(_ context: StudyReminderContext) async {
        await client.registerCategories(language: context.language)
        let pendingIdentifiers = await client.pendingIdentifiers()
        let deliveredIdentifiers = await client.deliveredIdentifiers()
        let allIdentifiers = pendingIdentifiers.union(deliveredIdentifiers)
            .filteringCueLensNotifications()
        let reminderIdentifiers = Set(allIdentifiers.filter(Self.isReminderIdentifier))

        switch StudyReminderPolicy.decision(for: context) {
        case .cancel:
            await remove(identifiers: reminderIdentifiers)
        case let .schedule(situationNumber, deliveryDate):
            let identifier = Self.reminderIdentifier(situationNumber: situationNumber)
            await remove(identifiers: reminderIdentifiers.subtracting([identifier]))
            guard !deliveredIdentifiers.contains(identifier) else { return }
            try? await client.add(
                LocalNotificationDescriptor(
                    identifier: identifier,
                    title: "CueLens",
                    body: NotificationText.privateReminderBody(language: context.language),
                    categoryIdentifier: Self.reminderCategoryIdentifier(language: context.language),
                    deliveryDate: deliveryDate
                )
            )
        }
    }

    func scheduleInformationNotification(language: AppLanguage) async {
        guard await systemAuthorizationAllowed() else { return }
        await client.registerCategories(language: language)
        try? await client.add(
            LocalNotificationDescriptor(
                identifier: Self.informationIdentifier,
                title: "CueLens",
                body: NotificationText.informationBody(language: language),
                categoryIdentifier: Self.informationCategoryIdentifier(language: language),
                deliveryDate: nil
            )
        )
    }

    func disableAll() async {
        await remove(identifiers: await cueLensIdentifiers())
    }

    static func reminderIdentifier(situationNumber: Int) -> String {
        "\(reminderIdentifierPrefix)\(situationNumber)"
    }

    static func informationCategoryIdentifier(language: AppLanguage) -> String {
        "de.eachandevery.cuelens.information.\(language.rawValue)"
    }

    static func reminderCategoryIdentifier(language: AppLanguage) -> String {
        "de.eachandevery.cuelens.study-reminder.\(language.rawValue)"
    }

    static func route(for identifier: String) -> CueLensNotificationRoute? {
        if identifier == informationIdentifier { return .informationFeed }
        if isReminderIdentifier(identifier) { return .studyHome }
        return nil
    }

    private static func isReminderIdentifier(_ identifier: String) -> Bool {
        guard identifier.hasPrefix(reminderIdentifierPrefix),
              let situationNumber = Int(identifier.dropFirst(reminderIdentifierPrefix.count)) else {
            return false
        }
        return (2...StudySchedule.totalSituationCount).contains(situationNumber)
    }

    private func cueLensIdentifiers() async -> Set<String> {
        let pending = await client.pendingIdentifiers()
        let delivered = await client.deliveredIdentifiers()
        return pending.union(delivered).filteringCueLensNotifications()
    }

    private func remove(identifiers: Set<String>) async {
        guard !identifiers.isEmpty else { return }
        await client.removePending(identifiers: identifiers)
        await client.removeDelivered(identifiers: identifiers)
    }
}

private extension Set where Element == String {
    func filteringCueLensNotifications() -> Set<String> {
        Set(filter {
            $0 == NotificationCoordinator.informationIdentifier
                || $0.hasPrefix(NotificationCoordinator.reminderIdentifierPrefix)
        })
    }
}

enum NotificationText {
    static func informationBody(language: AppLanguage) -> String {
        switch language {
        case .german: "Neue Information zu CueLens verfügbar"
        case .english: "New CueLens information available"
        }
    }

    static func privateReminderBody(language: AppLanguage) -> String {
        switch language {
        case .german: "Eine neue Aufgabe ist verfügbar."
        case .english: "A new task is available."
        }
    }

    static func publicReminderBody(language: AppLanguage) -> String {
        switch language {
        case .german: "Eine neue Information ist verfügbar."
        case .english: "New information is available."
        }
    }
}
