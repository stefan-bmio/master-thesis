import Foundation

struct AppEnvironment: Sendable {
    let persistence: any LocalPersistenceLoading
    let settings: any AppSettingsStoring
    let infoFeed: any InfoFeedRepositoryServing
    let activation: any ActivationManaging
    let feedback: any FeedbackManaging
    let externalLinks: any ExternalLinkManaging
    let demoRandomizer: any DemoRandomizing
    let demoClock: any DemoSleepClock
    let notifications: any NotificationManaging
    let backgroundRefresh: any BackgroundRefreshManaging
    let notificationRoutes: NotificationRouteInbox
    let features: any FeatureConfigServicing
    let productiveStudy: any ProductiveStudyManaging
    let productiveStudyClock: any ProductiveStudySleepClock

    init(
        persistence: any LocalPersistenceLoading,
        settings: any AppSettingsStoring,
        infoFeed: any InfoFeedRepositoryServing,
        activation: any ActivationManaging = DisabledActivationManager(),
        feedback: any FeedbackManaging = DisabledFeedbackManager(),
        externalLinks: any ExternalLinkManaging = DisabledExternalLinkManager(),
        demoRandomizer: any DemoRandomizing = SystemDemoRandomizer(),
        demoClock: any DemoSleepClock = ContinuousDemoSleepClock(),
        notifications: any NotificationManaging = DisabledNotificationManager(),
        backgroundRefresh: any BackgroundRefreshManaging = DisabledBackgroundRefreshManager(),
        notificationRoutes: NotificationRouteInbox = NotificationRouteInbox(),
        features: any FeatureConfigServicing = DisabledFeatureConfigService(),
        productiveStudy: any ProductiveStudyManaging = DisabledProductiveStudyManager(),
        productiveStudyClock: any ProductiveStudySleepClock = ContinuousProductiveStudySleepClock()
    ) {
        self.persistence = persistence
        self.settings = settings
        self.infoFeed = infoFeed
        self.activation = activation
        self.feedback = feedback
        self.externalLinks = externalLinks
        self.demoRandomizer = demoRandomizer
        self.demoClock = demoClock
        self.notifications = notifications
        self.backgroundRefresh = backgroundRefresh
        self.notificationRoutes = notificationRoutes
        self.features = features
        self.productiveStudy = productiveStudy
        self.productiveStudyClock = productiveStudyClock
    }

    static func live() throws -> AppEnvironment {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let suiteName = argumentValue(after: "--ui-test-suite", in: arguments)
        let settings = UserDefaultsAppSettingsStore(suiteName: suiteName)
        if let scenario = argumentValue(after: "--ui-test-feed", in: arguments) {
            let activationScenario = argumentValue(after: "--ui-test-activation", in: arguments)
            let feedbackScenario = argumentValue(after: "--ui-test-feedback", in: arguments)
            let studyScenario = argumentValue(after: "--ui-test-study", in: arguments)
            let persistence: any LocalPersistenceLoading
            let activation: any ActivationManaging
            if activationScenario != nil || studyScenario != nil {
                persistence = UITestPersistenceLoader(
                    activationScenario: activationScenario,
                    studyScenario: studyScenario
                )
                let resolvedActivationScenario = activationScenario ?? "activated"
                activation = UITestActivationManager(resolvedActivationScenario)
            } else {
                persistence = LiveLocalPersistenceBootstrap()
                activation = DisabledActivationManager()
            }
            let studyStateStore = UITestStudyStateStore()
            return AppEnvironment(
                persistence: persistence,
                settings: settings,
                infoFeed: InfoFeedRepository(
                    service: UITestInfoFeedService(scenario: scenario),
                    settings: settings
                ),
                activation: activation,
                feedback: UITestFeedbackManager(scenario: feedbackScenario),
                externalLinks: UITestExternalLinkManager(),
                demoRandomizer: UITestDemoRandomizer(),
                notificationRoutes: .live,
                features: UITestFeatureConfigService(enabled: studyScenario != nil),
                productiveStudy: studyScenario == nil
                    ? DisabledProductiveStudyManager()
                    : ProductiveStudyCoordinator(
                        contentRepository: BundleStudyContentRepository(),
                        stateStore: studyStateStore,
                        randomizer: UITestProductiveRandomizer(),
                        dateProvider: UITestStudyDateProvider(),
                        cooldownSeconds: 3
                    ),
                productiveStudyClock: UITestProductiveStudyClock()
            )
        }
        #else
        let settings = UserDefaultsAppSettingsStore()
        #endif
        let configuration = try AppConfiguration.live()
        let services = try NetworkServices.live(configuration: configuration)
        let paths = try PersistencePaths.applicationSupport()
        let tokenStore = KeychainAppTokenStore()
        let recoveryStore = ProtectedActivationRecoveryStore(paths: paths)
        let stateStore = ProtectedStudyStateStore(paths: paths)
        let persistence = LocalPersistenceBootstrap(
            installation: InstallationCoordinator(paths: paths, tokenStore: tokenStore),
            tokenStore: tokenStore,
            stateStore: stateStore,
            activationRecovery: recoveryStore
        )
        let notifications = NotificationCoordinator()
        let checker = InfoFeedBackgroundChecker(
            settings: settings,
            service: services.messages,
            notifications: notifications
        )
        let backgroundRefresh = BackgroundRefreshCoordinator(
            checker: checker,
            notifications: notifications
        )
        _ = backgroundRefresh.register()
        #if RELEASE
        let productiveStudy: any ProductiveStudyManaging = DisabledProductiveStudyManager()
        #else
        let productiveStudy: any ProductiveStudyManaging = ProductiveStudyCoordinator(
            contentRepository: BundleStudyContentRepository(),
            stateStore: stateStore,
            cooldownSeconds: configuration.runCooldownSeconds
        )
        #endif
        return AppEnvironment(
            persistence: persistence,
            settings: settings,
            infoFeed: InfoFeedRepository(service: services.messages, settings: settings),
            activation: ActivationCoordinator(
                service: services.activation,
                tokenStore: tokenStore,
                recoveryStore: recoveryStore
            ),
            feedback: FeedbackCoordinator(
                service: services.feedback,
                appVersion: configuration.appVersion
            ),
            externalLinks: ExternalLinkCoordinator(configuration: configuration.externalLinks),
            notifications: notifications,
            backgroundRefresh: backgroundRefresh,
            notificationRoutes: .live,
            features: services.features,
            productiveStudy: productiveStudy
        )
    }

    #if DEBUG
    private static func argumentValue(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
    #endif
}

private struct DisabledFeatureConfigService: FeatureConfigServicing {
    func isNextStudyRunEnabled() async -> Bool { false }
}

#if DEBUG
private actor UITestInfoFeedService: InfoFeedServicing {
    let scenario: String

    init(scenario: String) {
        self.scenario = scenario
    }

    func fetchMessages() async throws -> [InfoMessage] {
        if scenario == "error" { throw NetworkError.transportFailure }
        if scenario == "empty" { return [] }
        return [
            InfoMessage(
                id: 101,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                textGerman: "Synthetische Information eins",
                textEnglish: "Synthetic information one"
            ),
            InfoMessage(
                id: 102,
                createdAt: Date(timeIntervalSince1970: 1_700_000_001),
                textGerman: "Synthetische Information zwei",
                textEnglish: "Synthetic information two"
            )
        ]
    }
}

private struct UITestPersistenceLoader: LocalPersistenceLoading {
    let activationScenario: String?
    let studyScenario: String?

    func load() async throws -> LocalPersistenceSnapshot {
        let state: StudyState
        if activationScenario == "completed" {
            state = try StudyState(
                confirmedSituationCount: 20,
                matchingOrder: Array(0..<50),
                completion: .prolificCompleted
            )
        } else if studyScenario == "labeling" {
            state = try StudyState(
                confirmedSituationCount: 10,
                nextSituationAvailableAt: Date(timeIntervalSince1970: 0),
                matchingOrder: Array(0..<50)
            )
        } else {
            state = try StudyState.initial
        }
        return LocalPersistenceSnapshot(
            installation: .existingInstallation,
            studyState: state,
            isActivated: activationScenario == "activated"
                || activationScenario == "completed"
                || studyScenario != nil,
            activationRequiresSupport: activationScenario == "recovered-support"
                || activationScenario == "token-failure",
            tokenStorageFailed: activationScenario == "token-failure"
        )
    }
}

private actor UITestActivationManager: ActivationManaging {
    let scenario: String

    init(_ scenario: String) {
        self.scenario = scenario
    }

    func requestToken(identifier: ParticipantIdentifier) async -> ActivationTokenRequestOutcome {
        if scenario == "failure" { return .failed }
        if scenario == "running" {
            try? await Task.sleep(for: .seconds(2))
        }
        return .readyToConfirm
    }

    func confirmPendingToken() async -> ActivationConfirmationOutcome {
        switch scenario {
        case "timeout": .supportRequired
        case "storage-failure": .secureStorageFailure
        default: .activated
        }
    }
}

private actor UITestFeedbackManager: FeedbackManaging {
    let scenario: String?

    init(scenario: String?) {
        self.scenario = scenario
    }

    func submit(_ draft: FeedbackDraft) async -> FeedbackSubmissionOutcome {
        if scenario == "running" {
            try? await Task.sleep(for: .seconds(2))
        }
        return scenario == "failure" ? .failed : .submitted
    }
}

private struct UITestExternalLinkManager: ExternalLinkManaging {
    func openPrivacy(language: AppLanguage) async -> Bool { true }
    func openRightsContact() async -> Bool { true }
}

private actor UITestDemoRandomizer: DemoRandomizing {
    private var nextValue = false

    func nextBoolean() -> Bool {
        defer { nextValue.toggle() }
        return nextValue
    }
}

private struct UITestFeatureConfigService: FeatureConfigServicing {
    let enabled: Bool
    func isNextStudyRunEnabled() async -> Bool { enabled }
}

private actor UITestStudyStateStore: StudyStateStore {
    private var state: StudyState?
    func readState() async throws -> StudyState { try state ?? StudyState.initial }
    func writeState(_ state: StudyState) async throws { self.state = state }
}

private struct UITestProductiveRandomizer: Randomizing {
    func shuffled<T>(_ values: [T]) -> [T] { values }
    func nextBoolean() -> Bool { false }
}

private struct UITestStudyDateProvider: DateProviding {
    var now: Date { Date() }
}

private struct UITestProductiveStudyClock: ProductiveStudySleepClock {
    func sleepForVisibleSecond() async throws {
        try await ContinuousClock().sleep(for: .milliseconds(20))
    }
}
#endif

enum SystemLanguageResolver {
    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        guard let primary = preferredLanguages.first,
              Locale(identifier: primary).language.languageCode?.identifier == "en" else {
            return .german
        }
        return .english
    }
}
