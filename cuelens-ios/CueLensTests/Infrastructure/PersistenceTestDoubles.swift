import Foundation
import Security
import XCTest
@testable import CueLens

actor FakeKeychainClient: KeychainAccessing {
    private(set) var data: Data?
    private(set) var descriptors: [KeychainItemDescriptor] = []
    var readFailure: Int32?
    var addStatus: Int32?
    var deleteStatus: Int32?

    init(data: Data? = nil) {
        self.data = data
    }

    func read(_ descriptor: KeychainItemDescriptor) async -> KeychainReadResult {
        descriptors.append(descriptor)
        if let readFailure { return .failure(readFailure) }
        return data.map(KeychainReadResult.value) ?? .notFound
    }

    func add(_ data: Data, for descriptor: KeychainItemDescriptor) async -> Int32 {
        descriptors.append(descriptor)
        if let addStatus { return addStatus }
        guard self.data == nil else { return Int32(errSecDuplicateItem) }
        self.data = data
        return Int32(errSecSuccess)
    }

    func delete(_ descriptor: KeychainItemDescriptor) async -> Int32 {
        descriptors.append(descriptor)
        if let deleteStatus { return deleteStatus }
        guard data != nil else { return Int32(errSecItemNotFound) }
        data = nil
        return Int32(errSecSuccess)
    }

    func setAddStatus(_ status: Int32?) {
        addStatus = status
    }

    func setDeleteStatus(_ status: Int32?) {
        deleteStatus = status
    }

    func setReadFailure(_ status: Int32?) {
        readFailure = status
    }
}

enum FakeFileOperation: Hashable, Sendable {
    case prepareDirectory
    case exists
    case read
    case write
    case remove
    case secure
    case attributes
}

private struct FakeFileFailure: Error {}

actor InMemoryProtectedFileClient: ProtectedFileAccessing {
    private var resources: [URL: Data] = [:]
    private var security: [URL: ResourceSecurity] = [:]
    private var failures: Set<FakeFileOperation> = []
    private(set) var writes: [URL] = []

    func prepareDirectory(at url: URL) async throws {
        try failIfNeeded(.prepareDirectory)
        security[url] = ResourceSecurity(
            hasCompleteFileProtection: true,
            isExcludedFromBackup: true
        )
    }

    func resourceExists(at url: URL) async throws -> Bool {
        try failIfNeeded(.exists)
        return resources[url] != nil
    }

    func read(at url: URL) async throws -> Data {
        try failIfNeeded(.read)
        guard let data = resources[url] else { throw FakeFileFailure() }
        return data
    }

    func writeProtectedAtomically(_ data: Data, to url: URL) async throws {
        try failIfNeeded(.write)
        resources[url] = data
        security[url] = ResourceSecurity(
            hasCompleteFileProtection: true,
            isExcludedFromBackup: true
        )
        writes.append(url)
    }

    func removeResource(at url: URL) async throws {
        try failIfNeeded(.remove)
        resources[url] = nil
        security[url] = nil
    }

    func secureExistingResource(at url: URL) async throws {
        try failIfNeeded(.secure)
        guard resources[url] != nil || security[url] != nil else {
            throw FakeFileFailure()
        }
        security[url] = ResourceSecurity(
            hasCompleteFileProtection: true,
            isExcludedFromBackup: true
        )
    }

    func securityAttributes(at url: URL) async throws -> ResourceSecurity {
        try failIfNeeded(.attributes)
        guard let attributes = security[url] else { throw FakeFileFailure() }
        return attributes
    }

    func store(_ data: Data, at url: URL, isSecure: Bool = true) {
        resources[url] = data
        security[url] = ResourceSecurity(
            hasCompleteFileProtection: isSecure,
            isExcludedFromBackup: isSecure
        )
    }

    func storedData(at url: URL) -> Data? {
        resources[url]
    }

    func fail(_ operation: FakeFileOperation) {
        failures.insert(operation)
    }

    private func failIfNeeded(_ operation: FakeFileOperation) throws {
        if failures.contains(operation) { throw FakeFileFailure() }
    }
}

struct FixedSecureRandomGenerator: SecureRandomByteGenerating {
    let result: SecureRandomResult

    func bytes(count: Int) async -> SecureRandomResult {
        result
    }
}

func assertPersistenceError(
    _ expected: PersistenceError,
    operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected persistence error.", file: file, line: line)
    } catch let error as PersistenceError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error type.", file: file, line: line)
    }
}
