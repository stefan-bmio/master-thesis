import Foundation
import XCTest
@testable import CueLens

final class LocalPersistenceBootstrapTests: XCTestCase {
    func testBootstrapReturnsValidatedInitialSnapshot() async throws {
        let tokenStore = StubTokenStore(token: nil)
        let bootstrap = LocalPersistenceBootstrap(
            installation: StubInstallationPreparer(result: .newInstallation),
            tokenStore: tokenStore,
            stateStore: StubStudyStateStore(state: try StudyState.initial)
        )

        let snapshot = try await bootstrap.load()
        XCTAssertEqual(snapshot.installation, .newInstallation)
        XCTAssertEqual(snapshot.studyState, try StudyState.initial)
    }

    func testFreshSystemFileBootstrapCreatesInstallationAndLoadsInitialState() async throws {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let rootDirectory = applicationSupport
            .appendingPathComponent("cuelens-bootstrap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let paths = PersistencePaths(rootDirectory: rootDirectory)
        let tokenStore = KeychainAppTokenStore(client: FakeKeychainClient())
        let bootstrap = LocalPersistenceBootstrap(
            installation: InstallationCoordinator(paths: paths, tokenStore: tokenStore),
            tokenStore: tokenStore,
            stateStore: ProtectedStudyStateStore(paths: paths)
        )

        let snapshot = try await bootstrap.load()

        XCTAssertEqual(snapshot.installation, .newInstallation)
        XCTAssertEqual(snapshot.studyState, try StudyState.initial)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.installationMarker.path))
    }

    func testProgressWithoutTokenFailsClosed() async throws {
        let state = try StudyState(
            confirmedSituationCount: 1,
            nextSituationAvailableAt: Date(timeIntervalSince1970: 1_700_000_000),
            matchingOrder: Array(0..<50)
        )
        let bootstrap = LocalPersistenceBootstrap(
            installation: StubInstallationPreparer(result: .existingInstallation),
            tokenStore: StubTokenStore(token: nil),
            stateStore: StubStudyStateStore(state: state)
        )

        await assertPersistenceError(.installationIntegrityFailure) {
            _ = try await bootstrap.load()
        }
    }

    @MainActor
    func testAppModelPublishesStateOnlyAfterSuccessfulLoad() async throws {
        let initial = try StudyState.initial
        let successfulModel = CueLensAppModel(
            persistence: StubPersistenceLoader(result: .success(
                LocalPersistenceSnapshot(
                    installation: .existingInstallation,
                    studyState: initial
                )
            ))
        )
        XCTAssertEqual(successfulModel.initializationState, .loading)
        await successfulModel.initialize()
        XCTAssertEqual(successfulModel.initializationState, .ready(initial))

        let failingModel = CueLensAppModel(
            persistence: StubPersistenceLoader(result: .failure(
                PersistenceError.stateCorrupted
            ))
        )
        await failingModel.initialize()
        XCTAssertEqual(failingModel.initializationState, .secureStorageFailure)
    }
}

private actor StubInstallationPreparer: InstallationPreparing {
    let result: InstallationPreparation

    init(result: InstallationPreparation) {
        self.result = result
    }

    func prepareInstallation() async throws -> InstallationPreparation {
        result
    }
}

private actor StubTokenStore: AppTokenStore {
    let token: UUIDv4?

    init(token: UUIDv4?) {
        self.token = token
    }

    func readToken() async throws -> UUIDv4? { token }
    func saveToken(_ token: UUIDv4) async throws {}
    func clearToken() async throws {}
}

private actor StubStudyStateStore: StudyStateStore {
    let state: StudyState

    init(state: StudyState) {
        self.state = state
    }

    func readState() async throws -> StudyState { state }
    func writeState(_ state: StudyState) async throws {}
}

private struct StubPersistenceLoader: LocalPersistenceLoading {
    let result: Result<LocalPersistenceSnapshot, PersistenceError>

    func load() async throws -> LocalPersistenceSnapshot {
        try result.get()
    }
}
