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
    case productiveStudy
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

enum StudyTransferState: Equatable, Sendable {
    case idle
    case transferring
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
    private var productiveCountdownTask: Task<Void, Never>?
    private var initialStudyRecoveryAttempted = false

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
    private(set) var productiveRun: PreparedStudyRun?
    private(set) var productiveStudyFeatureEnabled = false
    private(set) var productiveStudyContentAvailable = false
    private(set) var productiveStudyViewportSuitable = true
    private(set) var productiveStudySubmitting = false
    private(set) var productiveStudyBlockReason: StartGateBlockReason?
    private(set) var studyTransferState: StudyTransferState = .idle
    private(set) var compensationCodeWasCopied = false

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
    var hasPendingStudyTransfer: Bool { studyState?.pendingCraving != nil }
    var hasPendingDirectConfirmation: Bool {
        guard let studyState else { return false }
        if case .directPendingConfirmation = studyState.completion { return true }
        return false
    }
    var directCompensationCode: String? {
        guard let studyState,
              case let .directCompleted(code) = studyState.completion else { return nil }
        return code.description
    }
    var hasProlificCompletion: Bool { studyState?.completion == .prolificCompleted }
    var hasInvalidStudyState: Bool { studyState?.completion == .invalid }
    var studyTransferIsRunning: Bool { studyTransferState == .transferring }
    var showsNextStudyRun: Bool {
        appActivated
            && !hasTokenStorageFailure
            && !isStudyCompleted
            && productiveStudyFeatureEnabled
            && productiveStudyContentAvailable
            && !hasPendingStudyTransfer
    }

    func nextStudyRunIsEnabled(now: Date) -> Bool {
        showsNextStudyRun
            && StudyCooldown.remainingSeconds(
                until: studyState?.nextSituationAvailableAt,
                now: now
            ) == 0
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

        await performInitialStudyRecoveryIfNeeded()
        await refreshProductiveStudyAvailability()

        await reconcileNotificationInfrastructure()
        await loadFeedWhenActive()
    }

    func updateLifecycle(_ phase: AppLifecyclePhase) async {
        lifecyclePhase = phase
        if phase == .active {
            startDemoCountdownIfNeeded()
            startProductiveCountdownIfNeeded()
        } else {
            stopDemoCountdown()
            stopProductiveCountdown()
        }
        if phase == .active, localStateLoaded {
            await performInitialStudyRecoveryIfNeeded()
            if let notificationRoute = await environment?.notificationRoutes.consume() {
                switch notificationRoute {
                case .informationFeed:
                    route = .loading
                    feedLoadPending = true
                case .studyHome:
                    feed = nil
                    route = .home
                    await refreshProductiveStudyAvailability()
                }
            }
            await reconcileNotificationInfrastructure()
            if route == .home {
                await refreshProductiveStudyAvailability()
            }
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
            await refreshProductiveStudyAvailability()
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

    func openProductiveStudy(viewportSize: CGSize) async {
        guard route == .home, let state = studyState, let environment else { return }
        await refreshProductiveStudyAvailability()
        let viewportSuitable = StudyViewportPolicy.allowsProductiveStudy(in: viewportSize)
        productiveStudyViewportSuitable = viewportSuitable
        let outcome = await environment.productiveStudy.prepare(
            state: state,
            isActivated: appActivated && !hasTokenStorageFailure,
            featureEnabled: productiveStudyFeatureEnabled,
            viewportSuitable: viewportSuitable,
            now: Date()
        )
        switch outcome {
        case let .ready(run):
            studyState = run.state
            productiveRun = run
            productiveStudyBlockReason = nil
            route = .productiveStudy
            startProductiveCountdownIfNeeded()
        case let .blocked(reason):
            productiveStudyBlockReason = reason
        case .persistenceFailed:
            route = .secureStorageFailure
        }
    }

    func updateProductiveStudyViewport(_ size: CGSize) {
        guard route == .productiveStudy else { return }
        productiveStudyViewportSuitable = StudyViewportPolicy.allowsProductiveStudy(in: size)
        if productiveStudyViewportSuitable {
            startProductiveCountdownIfNeeded()
        } else {
            stopProductiveCountdown()
        }
    }

    func selectProductiveStudyChoice() {
        guard route == .productiveStudy,
              productiveStudyViewportSuitable,
              productiveRun?.session.selectionEnabled == true else { return }
        stopProductiveCountdown()
        productiveRun?.session.selectCurrentTrial()
        startProductiveCountdownIfNeeded()
    }

    func updateProductiveCraving(_ value: Int) {
        guard route == .productiveStudy else { return }
        productiveRun?.session.updateCraving(value)
    }

    func submitProductiveCraving() async {
        guard route == .productiveStudy,
              !productiveStudySubmitting,
              let environment,
              let run = productiveRun,
              let state = studyState,
              run.session.phase == .craving else { return }
        productiveStudySubmitting = true
        studyTransferState = .transferring
        stopProductiveCountdown()
        let outcome = await environment.productiveStudy.submitCraving(
            run.session.craving,
            session: run.session,
            state: state
        )
        productiveStudySubmitting = false
        productiveRun = nil
        route = .home
        await applyStudyTransferOutcome(outcome)
    }

    func retryPendingStudyTransfer() async {
        guard route == .home,
              !studyTransferIsRunning,
              let environment,
              let state = studyState,
              state.pendingCraving != nil || hasPendingDirectConfirmation else { return }
        studyTransferState = .transferring
        let outcome = await environment.productiveStudy.recover(state: state)
        await applyStudyTransferOutcome(outcome)
    }

    func copyCompensationCode() async {
        guard route == .home,
              let code = directCompensationCode,
              let environment else { return }
        compensationCodeWasCopied = await environment.compensationCodeCopier.copy(code)
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
            await refreshProductiveStudyAvailability()
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

    private func refreshProductiveStudyAvailability() async {
        guard let environment,
              appActivated,
              !hasTokenStorageFailure,
              studyState?.completion == .incomplete else {
            productiveStudyFeatureEnabled = false
            productiveStudyContentAvailable = false
            return
        }
        async let feature = environment.features.isNextStudyRunEnabled()
        async let content = environment.productiveStudy.contentIsAvailable()
        productiveStudyFeatureEnabled = await feature
        productiveStudyContentAvailable = await content
    }

    private func performInitialStudyRecoveryIfNeeded() async {
        guard !initialStudyRecoveryAttempted,
              lifecyclePhase == .active,
              let environment,
              let state = studyState else { return }
        initialStudyRecoveryAttempted = true
        guard state.pendingCraving != nil || hasPendingDirectConfirmation else { return }
        studyTransferState = .transferring
        let outcome = await environment.productiveStudy.recover(state: state)
        await applyStudyTransferOutcome(outcome)
    }

    private func applyStudyTransferOutcome(_ outcome: StudyTransferOutcome) async {
        switch outcome {
        case let .progressed(newState), let .completed(newState):
            studyState = newState
            studyTransferState = .idle
            compensationCodeWasCopied = false
        case let .pending(newState), let .directConfirmationPending(newState):
            studyState = newState
            studyTransferState = .failed
        case .persistenceFailed:
            studyTransferState = .failed
            route = .secureStorageFailure
        case .secureIdentityUnavailable:
            studyTransferState = .failed
            tokenStorageFailed = true
        case .ignored:
            studyTransferState = .idle
        }
        await refreshProductiveStudyAvailability()
        await reconcileNotificationInfrastructure()
    }

    private func startProductiveCountdownIfNeeded() {
        guard lifecyclePhase == .active,
              route == .productiveStudy,
              productiveStudyViewportSuitable,
              productiveRun?.session.phase == .cueMatching,
              productiveRun?.session.remainingSeconds ?? 0 > 0,
              productiveCountdownTask == nil,
              let environment else { return }
        productiveCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await environment.productiveStudyClock.sleepForVisibleSecond()
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      self.lifecyclePhase == .active,
                      self.route == .productiveStudy,
                      self.productiveStudyViewportSuitable,
                      self.productiveRun?.session.phase == .cueMatching else { return }
                self.productiveRun?.session.countVisibleSecond()
                if self.productiveRun?.session.remainingSeconds == 0 {
                    self.productiveCountdownTask = nil
                    return
                }
            }
        }
    }

    private func stopProductiveCountdown() {
        productiveCountdownTask?.cancel()
        productiveCountdownTask = nil
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
