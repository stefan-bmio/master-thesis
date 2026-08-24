import Foundation
import Observation

enum AppRoute: Equatable, Sendable {
    case loading
    case infoFeed
    case notificationConsent
    case home
    case activation
    case demo
    case feedback
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
    case externalLinkFailed
}

enum FeedbackState: Equatable, Sendable {
    case editing
    case submitting
    case submitted
    case failed
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
    private var notificationPromptCompleted = false
    private var notificationsEnabled = false
    private var appActivated = false
    private var activationRequiresSupport = false
    private var tokenStorageFailed = false
    private var demoCountdownTask: Task<Void, Never>?

    private(set) var route: AppRoute = .loading
    private(set) var language: AppLanguage = .german
    private(set) var notice: UserNotice?
    private(set) var feed: InfoFeedPresentation?
    private(set) var studyState: StudyState?
    private(set) var lifecyclePhase: AppLifecyclePhase = .inactive
    private(set) var notificationOptionEnabled = true
    private(set) var isCompletingNotificationConsent = false
    private(set) var activationInput = ""
    private(set) var activationState: ActivationState = .idle
    private(set) var demo: DemoPresentation?
    private(set) var feedbackSource = ""
    private(set) var feedbackComment = ""
    private(set) var feedbackState: FeedbackState = .editing

    var showsPrivacyCurtain: Bool { lifecyclePhase != .active }
    var isActivated: Bool { appActivated }
    var isStudyCompleted: Bool { studyState?.completion.isCompleted == true }
    var canOpenDemo: Bool { !isStudyCompleted }
    var hasTokenStorageFailure: Bool { tokenStorageFailed || activationRequiresSupport }
    var activationInputIsValid: Bool {
        !activationRequiresSupport && (try? ParticipantIdentifier.parse(activationInput)) != nil
    }
    var activationInputIsEnabled: Bool {
        !activationRequiresSupport && !activationIsRunning
    }
    var feedbackInputIsValid: Bool {
        (try? FeedbackDraft(source: feedbackSource, comment: feedbackComment)) != nil
    }

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
            notificationPromptCompleted = settings.notificationPromptCompleted
            notificationsEnabled = settings.notificationsEnabled
        } catch {
            language = SystemLanguageResolver.resolve(preferredLanguages: preferredLanguages)
            notificationPromptCompleted = true
            notificationsEnabled = false
            notice = .settingSaveFailed
        }
        do {
            let snapshot = try await environment.persistence.load()
            studyState = snapshot.studyState
            appActivated = snapshot.isActivated
            activationRequiresSupport = snapshot.activationRequiresSupport
            tokenStorageFailed = snapshot.tokenStorageFailed
            localStateLoaded = true
        } catch {
            route = .secureStorageFailure
            return
        }

        await reconcileNotificationInfrastructure()
        await loadFeedWhenActive()
    }

    func updateLifecycle(_ phase: AppLifecyclePhase) async {
        lifecyclePhase = phase
        if phase == .active {
            startDemoCountdownIfNeeded()
        } else {
            stopDemoCountdown()
        }
        if phase == .active, localStateLoaded {
            if let notificationRoute = await environment?.notificationRoutes.consume() {
                switch notificationRoute {
                case .informationFeed:
                    route = .loading
                    feedLoadPending = true
                case .studyHome:
                    feed = nil
                    route = .home
                }
            }
            await reconcileNotificationInfrastructure()
            if feedLoadPending {
                await loadFeedWhenActive()
            }
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
        await reconcileNotificationInfrastructure()
    }

    func openActivation() {
        guard route == .home, !appActivated, !activationRequiresSupport else { return }
        activationInput = ""
        activationState = activationRequiresSupport ? .supportRequired : .idle
        route = .activation
    }

    func updateActivationInput(_ value: String) {
        guard route == .activation,
              !activationIsRunning,
              !activationRequiresSupport else { return }
        activationInput = value
        if activationState == .failed || activationState == .supportRequired {
            activationState = .idle
        }
    }

    func cancelActivation() {
        guard route == .activation, !activationIsRunning else { return }
        activationInput = ""
        activationState = .idle
        route = .home
    }

    func activate() async {
        guard route == .activation,
              !appActivated,
              !activationRequiresSupport,
              !activationIsRunning,
              let environment,
              let identifier = try? ParticipantIdentifier.parse(activationInput) else { return }

        activationState = .requestingToken
        let requestOutcome = await environment.activation.requestToken(identifier: identifier)
        switch requestOutcome {
        case .readyToConfirm:
            activationState = .confirmingToken
        case .failed:
            activationInput = ""
            activationState = .failed
            return
        case .ignored:
            activationState = .idle
            return
        }

        let confirmationOutcome = await environment.activation.confirmPendingToken()
        activationInput = ""
        switch confirmationOutcome {
        case .activated:
            appActivated = true
            activationState = .activated
            route = .home
            await reconcileNotificationInfrastructure()
        case .failed:
            activationState = .failed
        case .supportRequired:
            activationRequiresSupport = true
            activationState = .supportRequired
        case .secureStorageFailure:
            activationRequiresSupport = true
            tokenStorageFailed = true
            route = .home
        case .ignored:
            activationState = .failed
        }
    }

    func openDemo() async {
        guard route == .home, canOpenDemo, let environment else { return }
        let reverseMatching = await environment.demoRandomizer.nextBoolean()
        demo = DemoPresentation(reverseMatching: reverseMatching)
        route = .demo
        startDemoCountdownIfNeeded()
    }

    func selectDemoMatching() async {
        guard route == .demo,
              demo?.matchingSelectionEnabled == true,
              let environment else { return }
        let reverseLabels = await environment.demoRandomizer.nextBoolean()
        demo?.selectMatching(reverseLabels: reverseLabels)
        stopDemoCountdown()
    }

    func selectDemoLabel() {
        guard route == .demo else { return }
        demo?.selectLabel()
    }

    func updateDemoCraving(_ value: Int) {
        guard route == .demo else { return }
        demo?.updateCraving(value)
    }

    func completeDemoCraving() {
        guard route == .demo else { return }
        demo?.completeCraving()
    }

    func leaveDemo() {
        guard route == .demo else { return }
        stopDemoCountdown()
        demo = nil
        route = .home
    }

    func openFeedback() {
        guard route == .home else { return }
        feedbackSource = ""
        feedbackComment = ""
        feedbackState = .editing
        route = .feedback
    }

    func updateFeedbackSource(_ value: String) {
        guard route == .feedback, feedbackState != .submitting else { return }
        feedbackSource = value
        if feedbackState == .failed { feedbackState = .editing }
    }

    func updateFeedbackComment(_ value: String) {
        guard route == .feedback, feedbackState != .submitting else { return }
        feedbackComment = value
        if feedbackState == .failed { feedbackState = .editing }
    }

    func submitFeedback() async {
        guard route == .feedback,
              feedbackState != .submitting,
              let environment,
              let draft = try? FeedbackDraft(
                source: feedbackSource,
                comment: feedbackComment
              ) else { return }
        feedbackState = .submitting
        switch await environment.feedback.submit(draft) {
        case .submitted:
            feedbackSource = ""
            feedbackComment = ""
            feedbackState = .submitted
        case .failed:
            feedbackState = .failed
        case .ignored:
            feedbackState = .editing
        }
    }

    func leaveFeedback() {
        guard route == .feedback, feedbackState != .submitting else { return }
        feedbackSource = ""
        feedbackComment = ""
        feedbackState = .editing
        route = .home
    }

    func openPrivacyInformation() async {
        guard let environment else { return }
        if !(await environment.externalLinks.openPrivacy(language: language)) {
            notice = .externalLinkFailed
        }
    }

    func openRightsContact() async {
        guard let environment else { return }
        if !(await environment.externalLinks.openRightsContact()) {
            notice = .externalLinkFailed
        }
    }

    func setNotificationOptionEnabled(_ value: Bool) {
        guard route == .notificationConsent, !isCompletingNotificationConsent else { return }
        notificationOptionEnabled = value
    }

    func completeNotificationConsent() async {
        guard route == .notificationConsent,
              !isCompletingNotificationConsent,
              let environment else { return }
        isCompletingNotificationConsent = true
        let enabled = notificationOptionEnabled
            ? await environment.notifications.requestAuthorization()
            : false
        do {
            try await environment.settings.completeNotificationPrompt(enabled: enabled)
            notificationPromptCompleted = true
            notificationsEnabled = enabled
        } catch {
            notificationPromptCompleted = true
            notificationsEnabled = false
            notice = .settingSaveFailed
        }
        if !notificationsEnabled {
            await environment.notifications.disableAll()
        }
        await reconcileNotificationInfrastructure()
        isCompletingNotificationConsent = false
        route = .home
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
        if notificationPromptCompleted {
            route = .home
        } else {
            notificationOptionEnabled = true
            route = .notificationConsent
        }
    }

    private func reconcileNotificationInfrastructure() async {
        guard let environment, let studyState else { return }
        let systemAllowed = await environment.notifications.systemAuthorizationAllowed()
        let effectivelyEnabled = notificationsEnabled && systemAllowed
        let featureEnabled: Bool
        if effectivelyEnabled, appActivated, reminderStateIsEligibleForFeatureCheck(studyState) {
            featureEnabled = await environment.features.isNextStudyRunEnabled()
        } else {
            featureEnabled = false
        }
        await environment.notifications.reconcileStudyReminder(
            StudyReminderContext(
                notificationsEnabled: notificationsEnabled,
                systemAuthorizationAllowed: systemAllowed,
                appActivated: appActivated,
                featureEnabled: featureEnabled,
                state: studyState,
                language: language,
                now: Date()
            )
        )
        await environment.backgroundRefresh.reconcile(enabled: effectivelyEnabled)
    }

    private func startDemoCountdownIfNeeded() {
        guard lifecyclePhase == .active,
              route == .demo,
              demo?.step == .cueMatching,
              demo?.remainingSeconds ?? 0 > 0,
              demoCountdownTask == nil,
              let environment else { return }
        demoCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await environment.demoClock.sleepForVisibleSecond()
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      self.lifecyclePhase == .active,
                      self.route == .demo,
                      self.demo?.step == .cueMatching else { return }
                self.demo?.countVisibleSecond()
                if self.demo?.remainingSeconds == 0 {
                    self.demoCountdownTask = nil
                    return
                }
            }
        }
    }

    private func stopDemoCountdown() {
        demoCountdownTask?.cancel()
        demoCountdownTask = nil
    }

    private func reminderStateIsEligibleForFeatureCheck(_ state: StudyState) -> Bool {
        state.completion == .incomplete
            && state.pendingCraving == nil
            && (1..<StudySchedule.totalSituationCount).contains(state.confirmedSituationCount)
            && state.nextSituationAvailableAt != nil
    }

    private var activationIsRunning: Bool {
        activationState == .requestingToken || activationState == .confirmingToken
    }
}
