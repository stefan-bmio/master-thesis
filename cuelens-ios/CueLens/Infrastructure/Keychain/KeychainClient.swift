import Foundation
import Security

enum KeychainAccessibility: Equatable, Sendable {
    case whenUnlockedThisDeviceOnly
}

struct KeychainItemDescriptor: Equatable, Sendable {
    let service: String
    let account: String
    let accessibility: KeychainAccessibility
    let synchronizable: Bool

    static let appToken = KeychainItemDescriptor(
        service: "de.eachandevery.cuelens",
        account: "app-token-v1",
        accessibility: .whenUnlockedThisDeviceOnly,
        synchronizable: false
    )
}

enum KeychainReadResult: Equatable, Sendable {
    case value(Data)
    case notFound
    case failure(Int32)
}

protocol KeychainAccessing: Sendable {
    func read(_ descriptor: KeychainItemDescriptor) async -> KeychainReadResult
    func add(_ data: Data, for descriptor: KeychainItemDescriptor) async -> Int32
    func delete(_ descriptor: KeychainItemDescriptor) async -> Int32
}

struct SystemKeychainClient: KeychainAccessing {
    func read(_ descriptor: KeychainItemDescriptor) async -> KeychainReadResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: descriptor.service,
            kSecAttrAccount as String: descriptor.account,
            kSecAttrSynchronizable as String: descriptor.synchronizable,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                return .failure(Int32(errSecDecode))
            }
            return .value(data)
        case errSecItemNotFound:
            return .notFound
        default:
            return .failure(Int32(status))
        }
    }

    func add(_ data: Data, for descriptor: KeychainItemDescriptor) async -> Int32 {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: descriptor.service,
            kSecAttrAccount as String: descriptor.account,
            kSecAttrAccessible as String: accessibilityValue(descriptor.accessibility),
            kSecAttrSynchronizable as String: descriptor.synchronizable,
            kSecValueData as String: data
        ]
        return Int32(SecItemAdd(query as CFDictionary, nil))
    }

    func delete(_ descriptor: KeychainItemDescriptor) async -> Int32 {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: descriptor.service,
            kSecAttrAccount as String: descriptor.account,
            kSecAttrSynchronizable as String: descriptor.synchronizable
        ]
        return Int32(SecItemDelete(query as CFDictionary))
    }

    private func accessibilityValue(_ accessibility: KeychainAccessibility) -> CFString {
        switch accessibility {
        case .whenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }
}
