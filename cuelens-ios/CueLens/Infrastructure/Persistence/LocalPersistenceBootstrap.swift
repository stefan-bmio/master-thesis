import Foundation

struct LocalPersistenceSnapshot: Equatable, Sendable {
    let installation: InstallationPreparation
    let studyState: StudyState
    let isActivated: Bool
    let activationRequiresSupport: Bool

    init(
        installation: InstallationPreparation,
        studyState: StudyState,
        isActivated: Bool = false,
        activationRequiresSupport: Bool = false
    ) {
        self.installation = installation
        self.studyState = studyState
        self.isActivated = isActivated
        self.activationRequiresSupport = activationRequiresSupport
    }
}

protocol LocalPersistenceLoading: Sendable {
    func load() async throws -> LocalPersistenceSnapshot
}

actor LocalPersistenceBootstrap: LocalPersistenceLoading {
    private let installation: any InstallationPreparing
    private let tokenStore: any AppTokenStore
    private let stateStore: any StudyStateStore
    private let activationRecovery: any ActivationRecoveryStoring

    init(
        installation: any InstallationPreparing,
        tokenStore: any AppTokenStore,
        stateStore: any StudyStateStore,
        activationRecovery: any ActivationRecoveryStoring = DisabledActivationRecoveryStore()
    ) {
        self.installation = installation
        self.tokenStore = tokenStore
        self.stateStore = stateStore
        self.activationRecovery = activationRecovery
    }

    func load() async throws -> LocalPersistenceSnapshot {
        let preparation = try await installation.prepareInstallation()
        let state = try await stateStore.readState()
        let token = try await tokenStore.readToken()
        let confirmationUncertain = try await activationRecovery.isConfirmationUncertain()

        let stateRequiresToken = state.confirmedSituationCount > 0
            || !state.matchingOrder.isEmpty
            || state.pendingCraving != nil
            || state.completion != .incomplete
        guard !stateRequiresToken || token != nil else {
            throw PersistenceError.installationIntegrityFailure
        }

        if token != nil, confirmationUncertain {
            try await activationRecovery.clearConfirmationUncertain()
        }

        return LocalPersistenceSnapshot(
            installation: preparation,
            studyState: state,
            isActivated: token != nil,
            activationRequiresSupport: token == nil && confirmationUncertain
        )
    }
}

actor LiveLocalPersistenceBootstrap: LocalPersistenceLoading {
    func load() async throws -> LocalPersistenceSnapshot {
        let paths: PersistencePaths
        do {
            paths = try PersistencePaths.applicationSupport()
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .locateApplicationSupport)
        }

        let tokenStore = KeychainAppTokenStore()
        let installation = InstallationCoordinator(paths: paths, tokenStore: tokenStore)
        let stateStore = ProtectedStudyStateStore(paths: paths)
        let activationRecovery = ProtectedActivationRecoveryStore(paths: paths)
        let bootstrap = LocalPersistenceBootstrap(
            installation: installation,
            tokenStore: tokenStore,
            stateStore: stateStore,
            activationRecovery: activationRecovery
        )
        return try await bootstrap.load()
    }
}

struct DisabledActivationRecoveryStore: ActivationRecoveryStoring {
    func isConfirmationUncertain() async throws -> Bool { false }
    func markConfirmationUncertain() async throws {}
    func clearConfirmationUncertain() async throws {}
}
