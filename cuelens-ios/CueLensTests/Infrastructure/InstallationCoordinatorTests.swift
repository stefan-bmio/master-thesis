import Foundation
import XCTest
@testable import CueLens

final class InstallationCoordinatorTests: XCTestCase {
    private let paths = PersistencePaths(
        rootDirectory: URL(fileURLWithPath: "/synthetic/Application Support/CueLens")
    )
    private let marker = Data(repeating: 0xA5, count: InstallationCoordinator.markerLength)

    func testNewInstallationDeletesOrphanedTokenBeforeWritingMarker() async throws {
        let token = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        let keychain = FakeKeychainClient(data: Data(token.description.utf8))
        let tokenStore = KeychainAppTokenStore(client: keychain)
        let files = InMemoryProtectedFileClient()
        let coordinator = makeCoordinator(files: files, tokenStore: tokenStore)

        let preparation = try await coordinator.prepareInstallation()
        let storedToken = await keychain.data
        let storedMarker = await files.storedData(at: paths.installationMarker)
        let markerSecurity = try await files.securityAttributes(at: paths.installationMarker)
        XCTAssertEqual(preparation, .newInstallation)
        XCTAssertNil(storedToken)
        XCTAssertEqual(storedMarker, marker)
        XCTAssertEqual(
            markerSecurity,
            ResourceSecurity(hasCompleteFileProtection: true, isExcludedFromBackup: true)
        )
    }

    func testExistingInstallationKeepsMarkerAndTokenAcrossUpdate() async throws {
        let token = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        let keychain = FakeKeychainClient(data: Data(token.description.utf8))
        let tokenStore = KeychainAppTokenStore(client: keychain)
        let files = InMemoryProtectedFileClient()
        await files.store(marker, at: paths.installationMarker, isSecure: false)
        let coordinator = makeCoordinator(files: files, tokenStore: tokenStore)

        let preparation = try await coordinator.prepareInstallation()
        let storedToken = await keychain.data
        let storedMarker = await files.storedData(at: paths.installationMarker)
        let markerSecurity = try await files.securityAttributes(at: paths.installationMarker)
        XCTAssertEqual(preparation, .existingInstallation)
        XCTAssertEqual(storedToken, Data(token.description.utf8))
        XCTAssertEqual(storedMarker, marker)
        XCTAssertTrue(markerSecurity.isValid)
    }

    func testMissingMarkerWithExistingStateFailsClosedWithoutDeletingToken() async throws {
        let token = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        let keychain = FakeKeychainClient(data: Data(token.description.utf8))
        let files = InMemoryProtectedFileClient()
        await files.store(Data("state".utf8), at: paths.studyState)
        let coordinator = makeCoordinator(
            files: files,
            tokenStore: KeychainAppTokenStore(client: keychain)
        )

        await assertPersistenceError(.installationIntegrityFailure) {
            _ = try await coordinator.prepareInstallation()
        }
        let storedToken = await keychain.data
        let storedMarker = await files.storedData(at: paths.installationMarker)
        XCTAssertEqual(storedToken, Data(token.description.utf8))
        XCTAssertNil(storedMarker)
    }

    func testCorruptMarkerFailsClosed() async throws {
        let files = InMemoryProtectedFileClient()
        await files.store(Data(repeating: 0, count: 31), at: paths.installationMarker)
        let coordinator = makeCoordinator(
            files: files,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient())
        )

        await assertPersistenceError(.installationIntegrityFailure) {
            _ = try await coordinator.prepareInstallation()
        }
    }

    func testTokenDeletionRandomAndMarkerWriteFailuresDoNotCreateMarker() async throws {
        let deleteClient = FakeKeychainClient()
        await deleteClient.setDeleteStatus(-9_010)
        let deleteFiles = InMemoryProtectedFileClient()
        let deleteCoordinator = makeCoordinator(
            files: deleteFiles,
            tokenStore: KeychainAppTokenStore(client: deleteClient)
        )
        await assertPersistenceError(
            .keychainFailure(operation: .delete, status: -9_010)
        ) {
            _ = try await deleteCoordinator.prepareInstallation()
        }
        let markerAfterDeleteFailure = await deleteFiles.storedData(at: paths.installationMarker)
        XCTAssertNil(markerAfterDeleteFailure)

        let randomFiles = InMemoryProtectedFileClient()
        let randomCoordinator = InstallationCoordinator(
            paths: paths,
            files: randomFiles,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient()),
            random: FixedSecureRandomGenerator(result: .failure(-9_011))
        )
        await assertPersistenceError(.randomGenerationFailure(status: -9_011)) {
            _ = try await randomCoordinator.prepareInstallation()
        }
        let markerAfterRandomFailure = await randomFiles.storedData(at: paths.installationMarker)
        XCTAssertNil(markerAfterRandomFailure)

        let writeFiles = InMemoryProtectedFileClient()
        await writeFiles.fail(.write)
        let writeCoordinator = makeCoordinator(
            files: writeFiles,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient())
        )
        await assertPersistenceError(.fileSystemFailure(operation: .writeMarker)) {
            _ = try await writeCoordinator.prepareInstallation()
        }
        let markerAfterWriteFailure = await writeFiles.storedData(at: paths.installationMarker)
        XCTAssertNil(markerAfterWriteFailure)
    }

    func testWrongRandomByteCountFailsClosed() async {
        let files = InMemoryProtectedFileClient()
        let coordinator = InstallationCoordinator(
            paths: paths,
            files: files,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient()),
            random: FixedSecureRandomGenerator(result: .bytes(Data(repeating: 1, count: 31)))
        )

        await assertPersistenceError(.installationIntegrityFailure) {
            _ = try await coordinator.prepareInstallation()
        }
    }

    func testFileInspectionAndProtectionFailuresAreMappedFailClosed() async {
        let inspectFiles = InMemoryProtectedFileClient()
        await inspectFiles.fail(.exists)
        let inspectCoordinator = makeCoordinator(
            files: inspectFiles,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient())
        )
        await assertPersistenceError(.fileSystemFailure(operation: .inspectMarker)) {
            _ = try await inspectCoordinator.prepareInstallation()
        }

        let protectFiles = InMemoryProtectedFileClient()
        await protectFiles.store(marker, at: paths.installationMarker)
        await protectFiles.fail(.secure)
        let protectCoordinator = makeCoordinator(
            files: protectFiles,
            tokenStore: KeychainAppTokenStore(client: FakeKeychainClient())
        )
        await assertPersistenceError(.fileSystemFailure(operation: .protectMarker)) {
            _ = try await protectCoordinator.prepareInstallation()
        }
    }

    func testSystemRandomGeneratorProducesThirtyTwoBytes() async {
        let generator = SystemSecureRandomByteGenerator()
        let first = await generator.bytes(count: InstallationCoordinator.markerLength)
        let second = await generator.bytes(count: InstallationCoordinator.markerLength)

        guard case .bytes(let firstData) = first,
              case .bytes(let secondData) = second else {
            XCTFail("System random generation failed.")
            return
        }
        XCTAssertEqual(firstData.count, InstallationCoordinator.markerLength)
        XCTAssertEqual(secondData.count, InstallationCoordinator.markerLength)
        XCTAssertNotEqual(firstData, secondData)
    }

    private func makeCoordinator(
        files: InMemoryProtectedFileClient,
        tokenStore: KeychainAppTokenStore
    ) -> InstallationCoordinator {
        InstallationCoordinator(
            paths: paths,
            files: files,
            tokenStore: tokenStore,
            random: FixedSecureRandomGenerator(result: .bytes(marker))
        )
    }
}
