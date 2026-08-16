import Foundation

struct AppSettings: Equatable, Sendable {
    var selectedLanguage: AppLanguage?
    var dismissedMessageIDs: Set<Int64>
    var knownMessageIDs: Set<Int64>
    var notificationPromptCompleted: Bool
    var notificationsEnabled: Bool

    init(
        selectedLanguage: AppLanguage?,
        dismissedMessageIDs: Set<Int64>,
        knownMessageIDs: Set<Int64>,
        notificationPromptCompleted: Bool = false,
        notificationsEnabled: Bool = false
    ) {
        self.selectedLanguage = selectedLanguage
        self.dismissedMessageIDs = dismissedMessageIDs
        self.knownMessageIDs = knownMessageIDs
        self.notificationPromptCompleted = notificationPromptCompleted
        self.notificationsEnabled = notificationsEnabled
    }

    static let empty = AppSettings(
        selectedLanguage: nil,
        dismissedMessageIDs: [],
        knownMessageIDs: [],
        notificationPromptCompleted: false,
        notificationsEnabled: false
    )
}

protocol AppSettingsStoring: Sendable {
    func load() async throws -> AppSettings
    func saveLanguage(_ language: AppLanguage) async throws
    func dismissMessage(id: Int64) async throws
    func markMessagesKnown(ids: Set<Int64>) async throws
    func completeNotificationPrompt(enabled: Bool) async throws
}

actor UserDefaultsAppSettingsStore: AppSettingsStoring {
    private enum Key {
        static let language = "selected_language"
        static let dismissedMessageIDs = "dismissed_message_ids"
        static let knownMessageIDs = "known_message_ids"
        static let notificationPromptCompleted = "notification_prompt_completed"
        static let notificationsEnabled = "notifications_enabled"
    }

    private let defaults: UserDefaults

    init(suiteName: String? = nil) {
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }
    }

    func load() async throws -> AppSettings {
        let notificationPromptCompleted = defaults.bool(forKey: Key.notificationPromptCompleted)
        return AppSettings(
            selectedLanguage: defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)),
            dismissedMessageIDs: positiveIDs(forKey: Key.dismissedMessageIDs),
            knownMessageIDs: positiveIDs(forKey: Key.knownMessageIDs),
            notificationPromptCompleted: notificationPromptCompleted,
            notificationsEnabled: notificationPromptCompleted
                && defaults.bool(forKey: Key.notificationsEnabled)
        )
    }

    func saveLanguage(_ language: AppLanguage) async throws {
        defaults.set(language.rawValue, forKey: Key.language)
    }

    func dismissMessage(id: Int64) async throws {
        guard id > 0 else { return }
        var values = positiveIDs(forKey: Key.dismissedMessageIDs)
        values.insert(id)
        defaults.set(values.map(String.init).sorted(), forKey: Key.dismissedMessageIDs)
    }

    func markMessagesKnown(ids: Set<Int64>) async throws {
        var values = positiveIDs(forKey: Key.knownMessageIDs)
        values.formUnion(ids.filter { $0 > 0 })
        defaults.set(values.map(String.init).sorted(), forKey: Key.knownMessageIDs)
    }

    func completeNotificationPrompt(enabled: Bool) async throws {
        defaults.set(enabled, forKey: Key.notificationsEnabled)
        defaults.set(true, forKey: Key.notificationPromptCompleted)
    }

    private func positiveIDs(forKey key: String) -> Set<Int64> {
        Set(defaults.stringArray(forKey: key).orEmpty.compactMap(Int64.init).filter { $0 > 0 })
    }
}

private extension Optional where Wrapped == [String] {
    var orEmpty: [String] { self ?? [] }
}
