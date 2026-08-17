import Foundation
import XCTest
@testable import CueLens

final class ProtectedActivationRecoveryStoreTests: XCTestCase {
    func testMarkerRoundTripUsesProtectedBackupExcludedFile() async throws {
        let files = InMemoryProtectedFileClient()
        let paths = testPaths()
        let store = ProtectedActivationRecoveryStore(paths: paths, files: files)

        let initiallyUncertain = try await store.isConfirmationUncertain()
        XCTAssertFalse(initiallyUncertain)
        try await store.markConfirmationUncertain()
        let markedUncertain = try await store.isConfirmationUncertain()
        XCTAssertTrue(markedUncertain)
        let security = try await files.securityAttributes(at: paths.activationConfirmationMarker)
        XCTAssertTrue(security.isValid)

        try await store.clearConfirmationUncertain()
        let clearedUncertain = try await store.isConfirmationUncertain()
        XCTAssertFalse(clearedUncertain)
    }

    func testCorruptMarkerFailsClosed() async {
        let files = InMemoryProtectedFileClient()
        let paths = testPaths()
        await files.store(Data("corrupt".utf8), at: paths.activationConfirmationMarker)
        let store = ProtectedActivationRecoveryStore(paths: paths, files: files)

        await assertPersistenceError(.installationIntegrityFailure) {
            _ = try await store.isConfirmationUncertain()
        }
    }

    func testFileFailuresAreMappedToTypedPersistenceOperations() async {
        let paths = testPaths()

        let writeFiles = InMemoryProtectedFileClient()
        await writeFiles.fail(.write)
        await assertPersistenceError(.fileSystemFailure(operation: .writeActivationMarker)) {
            try await ProtectedActivationRecoveryStore(
                paths: paths,
                files: writeFiles
            ).markConfirmationUncertain()
        }

        let removeFiles = InMemoryProtectedFileClient()
        await removeFiles.fail(.remove)
        await assertPersistenceError(.fileSystemFailure(operation: .deleteActivationMarker)) {
            try await ProtectedActivationRecoveryStore(
                paths: paths,
                files: removeFiles
            ).clearConfirmationUncertain()
        }
    }

    func testSystemMarkerIsBackupExcludedAndCanBeRemoved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cuelens-activation-marker-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = PersistencePaths(rootDirectory: root)
        let files = SystemProtectedFileClient()
        let store = ProtectedActivationRecoveryStore(paths: paths, files: files)

        try await store.markConfirmationUncertain()
        let security = try await files.securityAttributes(at: paths.activationConfirmationMarker)
        let isUncertain = try await store.isConfirmationUncertain()
        XCTAssertTrue(security.isExcludedFromBackup)
        XCTAssertTrue(isUncertain)

        try await store.clearConfirmationUncertain()
        let exists = try await files.resourceExists(at: paths.activationConfirmationMarker)
        XCTAssertFalse(exists)
    }

    private func testPaths() -> PersistencePaths {
        PersistencePaths(
            rootDirectory: URL(fileURLWithPath: "/private/tmp/cuelens-activation-recovery-tests")
        )
    }
}
