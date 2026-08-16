import Foundation

enum NotificationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

enum CueLensNotificationRoute: Equatable, Sendable {
    case informationFeed
    case studyHome
}

struct LocalNotificationDescriptor: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let categoryIdentifier: String
    let deliveryDate: Date?
}

protocol NotificationCenterClient: Sendable {
    func authorizationState() async -> NotificationAuthorizationState
    func requestAlertAuthorization() async throws -> Bool
    func registerCategories(language: AppLanguage) async
    func add(_ descriptor: LocalNotificationDescriptor) async throws
    func pendingIdentifiers() async -> Set<String>
    func deliveredIdentifiers() async -> Set<String>
    func removePending(identifiers: Set<String>) async
    func removeDelivered(identifiers: Set<String>) async
}

struct StudyReminderContext: Equatable, Sendable {
    let notificationsEnabled: Bool
    let systemAuthorizationAllowed: Bool
    let appActivated: Bool
    let featureEnabled: Bool
    let state: StudyState
    let language: AppLanguage
    let now: Date
}

enum StudyReminderDecision: Equatable, Sendable {
    case cancel
    case schedule(situationNumber: Int, deliveryDate: Date)
}

enum StudyReminderPolicy {
    static func decision(for context: StudyReminderContext) -> StudyReminderDecision {
        let state = context.state
        let situationNumber = state.confirmedSituationCount + 1
        guard context.notificationsEnabled,
              context.systemAuthorizationAllowed,
              context.appActivated,
              context.featureEnabled,
              state.completion == .incomplete,
              state.pendingCraving == nil,
              (1..<StudySchedule.totalSituationCount).contains(state.confirmedSituationCount),
              (2...StudySchedule.totalSituationCount).contains(situationNumber),
              state.lastNotifiedSituationNumber != situationNumber,
              let deliveryDate = state.nextSituationAvailableAt else {
            return .cancel
        }
        return .schedule(situationNumber: situationNumber, deliveryDate: deliveryDate)
    }
}

protocol NotificationManaging: Sendable {
    func requestAuthorization() async -> Bool
    func systemAuthorizationAllowed() async -> Bool
    func reconcileStudyReminder(_ context: StudyReminderContext) async
    func scheduleInformationNotification(language: AppLanguage) async
    func disableAll() async
}

protocol BackgroundRefreshManaging: Sendable {
    func reconcile(enabled: Bool) async
}

actor NotificationRouteInbox {
    static let live = NotificationRouteInbox()

    private var pendingRoute: CueLensNotificationRoute?

    func record(_ route: CueLensNotificationRoute) {
        pendingRoute = route
    }

    func consume() -> CueLensNotificationRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}

struct DisabledNotificationManager: NotificationManaging {
    func requestAuthorization() async -> Bool { false }
    func systemAuthorizationAllowed() async -> Bool { false }
    func reconcileStudyReminder(_ context: StudyReminderContext) async {}
    func scheduleInformationNotification(language: AppLanguage) async {}
    func disableAll() async {}
}

struct DisabledBackgroundRefreshManager: BackgroundRefreshManaging {
    func reconcile(enabled: Bool) async {}
}
