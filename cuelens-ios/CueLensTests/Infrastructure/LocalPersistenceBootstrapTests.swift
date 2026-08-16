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
        XCTAssertFalse(snapshot.isActivated)
    }

    func testBootstrapExposesOnlyActivationStatusWithoutExposingToken() async throws {
        let token = try UUIDv4("550e8400-e29b-41d4-a716-446655440000")
        let bootstrap = LocalPersistenceBootstrap(
            installation: StubInstallationPreparer(result: .existingInstallation),
            tokenStore: StubTokenStore(token: token),
            stateStore: StubStudyStateStore(state: try StudyState.initial)
        )

        let snapshot = try await bootstrap.load()

        XCTAssertTrue(snapshot.isActivated)
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
            environment: AppEnvironment(
                persistence: StubPersistenceLoader(result: .success(
                    LocalPersistenceSnapshot(
                        installation: .existingInstallation,
                        studyState: initial
                    )
                )),
                settings: AppModelSettingsStub(),
                infoFeed: AppModelFeedStub()
            )
        )
        XCTAssertEqual(successfulModel.route, .loading)
        await successfulModel.initialize(lifecyclePhase: .active)
        XCTAssertEqual(successfulModel.route, .home)
        XCTAssertEqual(successfulModel.studyState, initial)

        let failingModel = CueLensAppModel(
            environment: AppEnvironment(
                persistence: StubPersistenceLoader(result: .failure(
                    PersistenceError.stateCorrupted
                )),
                settings: AppModelSettingsStub(),
                infoFeed: AppModelFeedStub()
            )
        )
        await failingModel.initialize(lifecyclePhase: .active)
        XCTAssertEqual(failingModel.route, .secureStorageFailure)
    }
}

private actor AppModelSettingsStub: AppSettingsStoring {
    func load() async throws -> AppSettings {
        AppSettings(
            selectedLanguage: nil,
            dismissedMessageIDs: [],
            knownMessageIDs: [],
            notificationPromptCompleted: true,
            notificationsEnabled: false
        )
    }
    func saveLanguage(_ language: AppLanguage) async throws {}
    func dismissMessage(id: Int64) async throws {}
    func markMessagesKnown(ids: Set<Int64>) async throws {}
    func completeNotificationPrompt(enabled: Bool) async throws {}
}

private actor AppModelFeedStub: InfoFeedRepositoryServing {
    func loadMessages() async throws -> InfoFeedBatch {
        InfoFeedBatch(visibleMessages: [], fetchedMessageIDs: [])
    }
    func dismissMessage(id: Int64) async throws {}
    func markMessagesKnown(ids: Set<Int64>) async throws {}
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
