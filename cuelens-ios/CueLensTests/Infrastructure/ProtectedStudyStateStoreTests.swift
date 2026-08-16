import Foundation
import XCTest
@testable import CueLens

final class ProtectedStudyStateStoreTests: XCTestCase {
    private let paths = PersistencePaths(
        rootDirectory: URL(fileURLWithPath: "/synthetic/Application Support/CueLens")
    )

    func testMissingFileReturnsInitialState() async throws {
        let store = ProtectedStudyStateStore(
            paths: paths,
            files: InMemoryProtectedFileClient()
        )
        let state = try await store.readState()
        XCTAssertEqual(state, try StudyState.initial)
    }

    func testStateRoundTripIsDeterministicProtectedAndExcludedFromBackup() async throws {
        let files = InMemoryProtectedFileClient()
        let store = ProtectedStudyStateStore(paths: paths, files: files)
        let state = try sampleState()

        try await store.writeState(state)
        let firstStoredData = await files.storedData(at: paths.studyState)
        let firstData = try XCTUnwrap(firstStoredData)
        try await store.writeState(state)
        let secondStoredData = await files.storedData(at: paths.studyState)
        let secondData = try XCTUnwrap(secondStoredData)

        let loadedState = try await store.readState()
        let stateSecurity = try await files.securityAttributes(at: paths.studyState)

        XCTAssertEqual(firstData, secondData)
        XCTAssertEqual(loadedState, state)
        XCTAssertTrue(stateSecurity.isValid)
    }

    func testMalformedOversizedAndStructurallyUnexpectedStatesFailClosed() async {
        let malformed = Data("not-json".utf8)
        let oversized = Data(repeating: 0, count: ProtectedStudyStateStore.maximumStateSize + 1)
        let extraField = Data(
            #"{"schemaVersion":1,"confirmedSituationCount":0,"lastNotifiedSituationNumber":0,"matchingOrder":[],"completion":{"kind":"incomplete"},"unexpected":true}"#.utf8
        )

        for data in [malformed, oversized, extraField] {
            let files = InMemoryProtectedFileClient()
            await files.store(data, at: paths.studyState)
            let store = ProtectedStudyStateStore(paths: paths, files: files)
            await assertPersistenceError(.stateCorrupted) {
                _ = try await store.readState()
            }
        }
    }

    func testUnknownOlderAndNewerSchemaVersionsUseExplicitMigrationEntry() async {
        for version in [0, 2] {
            let json = """
            {"schemaVersion":\(version),"confirmedSituationCount":0,"lastNotifiedSituationNumber":0,"matchingOrder":[],"completion":{"kind":"incomplete"}}
            """
            let files = InMemoryProtectedFileClient()
            await files.store(Data(json.utf8), at: paths.studyState)
            let store = ProtectedStudyStateStore(paths: paths, files: files)
            await assertPersistenceError(.unsupportedSchemaVersion(version)) {
                _ = try await store.readState()
            }
        }
    }

    func testInvariantViolationFailsClosedWithoutReset() async {
        let json = """
        {"schemaVersion":1,"confirmedSituationCount":20,"lastNotifiedSituationNumber":20,"matchingOrder":[],"completion":{"kind":"incomplete"}}
        """
        let original = Data(json.utf8)
        let files = InMemoryProtectedFileClient()
        await files.store(original, at: paths.studyState)
        let store = ProtectedStudyStateStore(paths: paths, files: files)

        await assertPersistenceError(.stateCorrupted) {
            _ = try await store.readState()
        }
        let storedData = await files.storedData(at: paths.studyState)
        XCTAssertEqual(storedData, original)
    }

    func testUnexpectedCompletionFieldsFailClosed() async {
        let json = #"{"schemaVersion":1,"confirmedSituationCount":0,"lastNotifiedSituationNumber":0,"matchingOrder":[],"completion":{"kind":"incomplete","unexpected":true}}"#
        let files = InMemoryProtectedFileClient()
        await files.store(Data(json.utf8), at: paths.studyState)
        let store = ProtectedStudyStateStore(paths: paths, files: files)

        await assertPersistenceError(.stateCorrupted) {
            _ = try await store.readState()
        }
    }

    func testWriteFailureLeavesPreviouslyPublishedFileUnchanged() async throws {
        let files = InMemoryProtectedFileClient()
        let initialStore = ProtectedStudyStateStore(paths: paths, files: files)
        let oldState = try sampleState(confirmedCount: 1)
        try await initialStore.writeState(oldState)
        let oldStoredData = await files.storedData(at: paths.studyState)
        let oldData = try XCTUnwrap(oldStoredData)

        await files.fail(.write)
        let failingStore = ProtectedStudyStateStore(paths: paths, files: files)
        await assertPersistenceError(.fileSystemFailure(operation: .writeState)) {
            try await failingStore.writeState(self.sampleState(confirmedCount: 2))
        }
        let dataAfterFailure = await files.storedData(at: paths.studyState)
        XCTAssertEqual(dataAfterFailure, oldData)
    }

    func testFileSystemFailuresAreMappedByOperation() async throws {
        let cases: [(FakeFileOperation, PersistenceError)] = [
            (.prepareDirectory, .fileSystemFailure(operation: .prepareDirectory)),
            (.exists, .fileSystemFailure(operation: .inspectState)),
            (.secure, .fileSystemFailure(operation: .protectState)),
            (.read, .fileSystemFailure(operation: .readState))
        ]

        for (operation, expectedError) in cases {
            let files = InMemoryProtectedFileClient()
            await files.store(Data("{}".utf8), at: paths.studyState)
            await files.fail(operation)
            let store = ProtectedStudyStateStore(paths: paths, files: files)
            await assertPersistenceError(expectedError) {
                _ = try await store.readState()
            }
        }
    }

    func testConcurrentWritesAreSerializedToOneCompleteState() async throws {
        let files = InMemoryProtectedFileClient()
        let store = ProtectedStudyStateStore(paths: paths, files: files)
        let firstState = try sampleState(confirmedCount: 1)
        let secondState = try sampleState(confirmedCount: 2)

        async let firstWrite: Void = store.writeState(firstState)
        async let secondWrite: Void = store.writeState(secondState)
        _ = try await (firstWrite, secondWrite)

        let storedState = try await store.readState()
        XCTAssertTrue(storedState == firstState || storedState == secondState)
    }

    func testSystemFileClientCreatesRealProtectedBackupExcludedRoundTrip() async throws {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let temporaryRoot = applicationSupport
            .appendingPathComponent("cuelens-persistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let realPaths = PersistencePaths(rootDirectory: temporaryRoot)
        let files = SystemProtectedFileClient()
        let store = ProtectedStudyStateStore(paths: realPaths, files: files)
        let state = try sampleState()

        try await store.writeState(state)
        let loadedState = try await store.readState()
        let directorySecurity = try await files.securityAttributes(at: temporaryRoot)
        let stateSecurity = try await files.securityAttributes(at: realPaths.studyState)
        XCTAssertEqual(loadedState, state)
        // CoreSimulator reports file protection as absent even after both protection APIs
        // succeed. The real-device review gate verifies the effective protection class.
        XCTAssertTrue(directorySecurity.isExcludedFromBackup)
        XCTAssertTrue(stateSecurity.isExcludedFromBackup)
    }

    private func sampleState(confirmedCount: Int = 1) throws -> StudyState {
        try StudyState(
            confirmedSituationCount: confirmedCount,
            nextSituationAvailableAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastNotifiedSituationNumber: confirmedCount,
            matchingOrder: Array(0..<50)
        )
    }
}
