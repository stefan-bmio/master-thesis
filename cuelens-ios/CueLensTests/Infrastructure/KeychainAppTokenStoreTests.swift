import Foundation
import Security
import XCTest
@testable import CueLens

final class KeychainAppTokenStoreTests: XCTestCase {
    private let firstTokenText = "123e4567-e89b-42d3-a456-426614174000"
    private let secondTokenText = "123e4567-e89b-42d3-b456-426614174000"

    func testMissingTokenCanBeSavedReadIdempotentlyAndCleared() async throws {
        let client = FakeKeychainClient()
        let store = KeychainAppTokenStore(client: client)
        let token = try UUIDv4(firstTokenText)

        let initialToken = try await store.readToken()
        XCTAssertNil(initialToken)
        try await store.saveToken(token)
        try await store.saveToken(token)
        let storedToken = try await store.readToken()
        XCTAssertEqual(storedToken, token)
        try await store.clearToken()
        try await store.clearToken()
        let clearedToken = try await store.readToken()
        XCTAssertNil(clearedToken)

        let descriptors = await client.descriptors
        XCTAssertFalse(descriptors.isEmpty)
        XCTAssertTrue(descriptors.allSatisfy { descriptor in
            descriptor == .appToken
                && descriptor.accessibility == .whenUnlockedThisDeviceOnly
                && !descriptor.synchronizable
        })
    }

    func testExistingDifferentTokenIsNeverOverwritten() async throws {
        let existing = try UUIDv4(firstTokenText)
        let client = FakeKeychainClient(data: Data(existing.description.utf8))
        let store = KeychainAppTokenStore(client: client)

        await assertPersistenceError(.tokenConflict) {
            try await store.saveToken(UUIDv4(self.secondTokenText))
        }
        let storedData = await client.data
        XCTAssertEqual(storedData, Data(existing.description.utf8))
    }

    func testInvalidStoredValueFailsWithoutSilentDeletion() async {
        let client = FakeKeychainClient(data: Data("not-a-token".utf8))
        let store = KeychainAppTokenStore(client: client)

        await assertPersistenceError(.invalidStoredToken) {
            _ = try await store.readToken()
        }
        let storedData = await client.data
        XCTAssertEqual(storedData, Data("not-a-token".utf8))
    }

    func testUnexpectedStatusesAreMappedForEveryOperation() async throws {
        let token = try UUIDv4(firstTokenText)

        let readClient = FakeKeychainClient()
        await readClient.setReadFailure(-9_001)
        await assertPersistenceError(.keychainFailure(operation: .read, status: -9_001)) {
            _ = try await KeychainAppTokenStore(client: readClient).readToken()
        }

        let addClient = FakeKeychainClient()
        await addClient.setAddStatus(-9_002)
        await assertPersistenceError(.keychainFailure(operation: .add, status: -9_002)) {
            try await KeychainAppTokenStore(client: addClient).saveToken(token)
        }

        let deleteClient = FakeKeychainClient()
        await deleteClient.setDeleteStatus(-9_003)
        await assertPersistenceError(.keychainFailure(operation: .delete, status: -9_003)) {
            try await KeychainAppTokenStore(client: deleteClient).clearToken()
        }
    }

    func testDuplicateItemRaceAcceptsOnlySameToken() async throws {
        let token = try UUIDv4(firstTokenText)
        let sameClient = DuplicateRaceKeychainClient(racedData: Data(token.description.utf8))
        try await KeychainAppTokenStore(client: sameClient).saveToken(token)

        let other = try UUIDv4(secondTokenText)
        let otherClient = DuplicateRaceKeychainClient(racedData: Data(other.description.utf8))
        await assertPersistenceError(.tokenConflict) {
            try await KeychainAppTokenStore(client: otherClient).saveToken(token)
        }
    }

    func testConcurrentIdenticalSavesAreSerializedAndIdempotent() async throws {
        let client = FakeKeychainClient()
        let store = KeychainAppTokenStore(client: client)
        let token = try UUIDv4(firstTokenText)

        async let firstSave: Void = store.saveToken(token)
        async let secondSave: Void = store.saveToken(token)
        _ = try await (firstSave, secondSave)

        let storedToken = try await store.readToken()
        XCTAssertEqual(storedToken, token)
    }

    func testSystemKeychainRoundTripUsesIsolatedSyntheticService() async throws {
        let descriptor = KeychainItemDescriptor(
            service: "de.eachandevery.cuelens.tests.\(UUID().uuidString)",
            account: "synthetic-token",
            accessibility: .whenUnlockedThisDeviceOnly,
            synchronizable: false
        )
        let store = KeychainAppTokenStore(
            client: SystemKeychainClient(),
            descriptor: descriptor
        )
        let token = try UUIDv4(firstTokenText)

        try await store.clearToken()
        try await store.saveToken(token)
        let storedToken = try await store.readToken()
        XCTAssertEqual(storedToken, token)
        try await store.clearToken()
        let clearedToken = try await store.readToken()
        XCTAssertNil(clearedToken)
    }
}

private actor DuplicateRaceKeychainClient: KeychainAccessing {
    private let racedData: Data
    private var hasAdded = false

    init(racedData: Data) {
        self.racedData = racedData
    }

    func read(_ descriptor: KeychainItemDescriptor) async -> KeychainReadResult {
        hasAdded ? .value(racedData) : .notFound
    }

    func add(_ data: Data, for descriptor: KeychainItemDescriptor) async -> Int32 {
        hasAdded = true
        return Int32(errSecDuplicateItem)
    }

    func delete(_ descriptor: KeychainItemDescriptor) async -> Int32 {
        Int32(errSecItemNotFound)
    }
}
