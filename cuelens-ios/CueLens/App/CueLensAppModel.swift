import Foundation
import Observation

enum AppRoute: Equatable, Sendable {
    case loading
    case infoFeed
    case home
    case secureStorageFailure
}

enum AppLifecyclePhase: Equatable, Sendable {
    case active
    case inactive
    case background
}

enum UserNotice: Equatable, Sendable {
    case feedLoadFailed
    case settingSaveFailed
}

struct InfoFeedPresentation: Equatable, Sendable {
    let messages: [InfoMessage]
    let fetchedMessageIDs: Set<Int64>
    var index: Int
    var hidePermanently: Bool
    var isConfirming: Bool

    var currentMessage: InfoMessage { messages[index] }
}

@MainActor
@Observable
final class CueLensAppModel {
    private let environment: AppEnvironment?
    private let preferredLanguages: [String]
    private var initializationStarted = false
    private var localStateLoaded = false
    private var feedLoadPending = false

    private(set) var route: AppRoute = .loading
    private(set) var language: AppLanguage = .german
    private(set) var notice: UserNotice?
    private(set) var feed: InfoFeedPresentation?
    private(set) var studyState: StudyState?
    private(set) var lifecyclePhase: AppLifecyclePhase = .inactive

    var showsPrivacyCurtain: Bool { lifecyclePhase != .active }

    init(
        environment: AppEnvironment,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.environment = environment
        self.preferredLanguages = preferredLanguages
    }

    init(configurationFailure: Void) {
        environment = nil
        preferredLanguages = []
        route = .secureStorageFailure
    }

    func initialize(lifecyclePhase: AppLifecyclePhase) async {
        self.lifecyclePhase = lifecyclePhase
        guard !initializationStarted, let environment else { return }
        initializationStarted = true

        do {
            let settings = try await environment.settings.load()
            language = settings.selectedLanguage
                ?? SystemLanguageResolver.resolve(preferredLanguages: preferredLanguages)
        } catch {
            language = SystemLanguageResolver.resolve(preferredLanguages: preferredLanguages)
            notice = .settingSaveFailed
        }
        do {
            let snapshot = try await environment.persistence.load()
            studyState = snapshot.studyState
            localStateLoaded = true
        } catch {
            route = .secureStorageFailure
            return
        }

        await loadFeedWhenActive()
    }

    func updateLifecycle(_ phase: AppLifecyclePhase) async {
        lifecyclePhase = phase
        if phase == .active, localStateLoaded, feedLoadPending {
            await loadFeedWhenActive()
        }
    }

    func toggleLanguage() async {
        language = language == .german ? .english : .german
        guard let environment else { return }
        do {
            try await environment.settings.saveLanguage(language)
        } catch {
            notice = .settingSaveFailed
        }
    }

    func setHidePermanently(_ value: Bool) {
        guard route == .infoFeed, feed?.isConfirming == false else { return }
        feed?.hidePermanently = value
    }

    func confirmCurrentMessage() async {
        guard let environment, var current = feed, !current.isConfirming else { return }
        current.isConfirming = true
        feed = current

        if current.hidePermanently {
            do {
                try await environment.infoFeed.dismissMessage(id: current.currentMessage.id)
            } catch {
                notice = .settingSaveFailed
            }
        }
        await advanceOrFinish(from: current)
    }

    func navigateBackInFeed() async {
        guard var current = feed, !current.isConfirming else { return }
        if current.index > 0 {
            current.index -= 1
            current.hidePermanently = false
            feed = current
        } else {
            await finishFeed(fetchedMessageIDs: current.fetchedMessageIDs)
        }
    }

    func dismissNotice() {
        notice = nil
    }

    private func loadFeedWhenActive() async {
        guard lifecyclePhase == .active else {
            feedLoadPending = true
            return
        }
        guard let environment else { return }
        feedLoadPending = false
        do {
            let batch = try await environment.infoFeed.loadMessages()
            if batch.visibleMessages.isEmpty {
                await finishFeed(fetchedMessageIDs: batch.fetchedMessageIDs)
            } else {
                feed = InfoFeedPresentation(
                    messages: batch.visibleMessages,
                    fetchedMessageIDs: batch.fetchedMessageIDs,
                    index: 0,
                    hidePermanently: false,
                    isConfirming: false
                )
                route = .infoFeed
            }
        } catch {
            notice = .feedLoadFailed
            route = .home
        }
    }

    private func advanceOrFinish(from current: InfoFeedPresentation) async {
        if current.index + 1 < current.messages.count {
            feed = InfoFeedPresentation(
                messages: current.messages,
                fetchedMessageIDs: current.fetchedMessageIDs,
                index: current.index + 1,
                hidePermanently: false,
                isConfirming: false
            )
        } else {
            await finishFeed(fetchedMessageIDs: current.fetchedMessageIDs)
        }
    }

    private func finishFeed(fetchedMessageIDs: Set<Int64>) async {
        if let environment {
            do {
                try await environment.infoFeed.markMessagesKnown(ids: fetchedMessageIDs)
            } catch {
                notice = .settingSaveFailed
            }
        }
        feed = nil
        route = .home
    }
}
