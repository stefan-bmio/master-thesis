import Foundation

struct LocalPersistenceSnapshot: Equatable, Sendable {
    let installation: InstallationPreparation
    let studyState: StudyState
}

protocol LocalPersistenceLoading: Sendable {
    func load() async throws -> LocalPersistenceSnapshot
}

actor LocalPersistenceBootstrap: LocalPersistenceLoading {
    private let installation: any InstallationPreparing
    private let tokenStore: any AppTokenStore
    private let stateStore: any StudyStateStore

    init(
        installation: any InstallationPreparing,
        tokenStore: any AppTokenStore,
        stateStore: any StudyStateStore
    ) {
        self.installation = installation
        self.tokenStore = tokenStore
        self.stateStore = stateStore
    }

    func load() async throws -> LocalPersistenceSnapshot {
        let preparation = try await installation.prepareInstallation()
        let state = try await stateStore.readState()
        let token = try await tokenStore.readToken()

        let stateRequiresToken = state.confirmedSituationCount > 0
            || !state.matchingOrder.isEmpty
            || state.pendingCraving != nil
            || state.completion != .incomplete
        guard !stateRequiresToken || token != nil else {
            throw PersistenceError.installationIntegrityFailure
        }

        return LocalPersistenceSnapshot(
            installation: preparation,
            studyState: state
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
        let bootstrap = LocalPersistenceBootstrap(
            installation: installation,
            tokenStore: tokenStore,
            stateStore: stateStore
        )
        return try await bootstrap.load()
    }
}
