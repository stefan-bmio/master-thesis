import Foundation

struct LocalPersistenceSnapshot: Equatable, Sendable {
    let installation: InstallationPreparation
    let studyState: StudyState
    let isActivated: Bool
    let activationRequiresSupport: Bool
    let tokenStorageFailed: Bool

    init(
        installation: InstallationPreparation,
        studyState: StudyState,
        isActivated: Bool = false,
        activationRequiresSupport: Bool = false,
        tokenStorageFailed: Bool = false
    ) {
        self.installation = installation
        self.studyState = studyState
        self.isActivated = isActivated
        self.activationRequiresSupport = activationRequiresSupport
        self.tokenStorageFailed = tokenStorageFailed
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
        let token: UUIDv4?
        do {
            token = try await tokenStore.readToken()
        } catch {
            return LocalPersistenceSnapshot(
                installation: preparation,
                studyState: state,
                activationRequiresSupport: true,
                tokenStorageFailed: true
            )
        }
        let confirmationUncertain: Bool
        do {
            confirmationUncertain = try await activationRecovery.isConfirmationUncertain()
        } catch {
            return LocalPersistenceSnapshot(
                installation: preparation,
                studyState: state,
                isActivated: token != nil,
                activationRequiresSupport: true,
                tokenStorageFailed: true
            )
        }

        let stateRequiresToken = state.confirmedSituationCount > 0
            || !state.matchingOrder.isEmpty
            || state.pendingCraving != nil
            || state.completion != .incomplete
        guard !stateRequiresToken || token != nil else {
            throw PersistenceError.installationIntegrityFailure
        }

        if token != nil, confirmationUncertain {
            do {
                try await activationRecovery.clearConfirmationUncertain()
            } catch {
                return LocalPersistenceSnapshot(
                    installation: preparation,
                    studyState: state,
                    isActivated: true,
                    activationRequiresSupport: true,
                    tokenStorageFailed: true
                )
            }
        }

        return LocalPersistenceSnapshot(
            installation: preparation,
            studyState: state,
            isActivated: token != nil,
            activationRequiresSupport: token == nil && confirmationUncertain,
            tokenStorageFailed: false
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
