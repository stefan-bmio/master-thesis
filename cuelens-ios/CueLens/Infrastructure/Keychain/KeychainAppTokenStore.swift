import Foundation
import Security

actor KeychainAppTokenStore: AppTokenStore {
    private let client: any KeychainAccessing
    private let descriptor: KeychainItemDescriptor

    init(
        client: any KeychainAccessing = SystemKeychainClient(),
        descriptor: KeychainItemDescriptor = .appToken
    ) {
        self.client = client
        self.descriptor = descriptor
    }

    func readToken() async throws -> UUIDv4? {
        switch await client.read(descriptor) {
        case .notFound:
            return nil
        case .failure(let status):
            throw PersistenceError.keychainFailure(operation: .read, status: status)
        case .value(let data):
            guard let string = String(data: data, encoding: .utf8),
                  let token = try? UUIDv4(string) else {
                throw PersistenceError.invalidStoredToken
            }
            return token
        }
    }

    func saveToken(_ token: UUIDv4) async throws {
        if let existing = try await readToken() {
            guard existing == token else {
                throw PersistenceError.tokenConflict
            }
            return
        }

        let data = Data(token.description.utf8)
        let status = await client.add(data, for: descriptor)
        switch status {
        case Int32(errSecSuccess):
            return
        case Int32(errSecDuplicateItem):
            guard let existing = try await readToken(), existing == token else {
                throw PersistenceError.tokenConflict
            }
        default:
            throw PersistenceError.keychainFailure(operation: .add, status: status)
        }
    }

    func clearToken() async throws {
        let status = await client.delete(descriptor)
        guard status == Int32(errSecSuccess) || status == Int32(errSecItemNotFound) else {
            throw PersistenceError.keychainFailure(operation: .delete, status: status)
        }
    }
}
