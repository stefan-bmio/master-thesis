import Foundation
import Security

enum SecureRandomResult: Equatable, Sendable {
    case bytes(Data)
    case failure(Int32)
}

protocol SecureRandomByteGenerating: Sendable {
    func bytes(count: Int) async -> SecureRandomResult
}

struct SystemSecureRandomByteGenerator: SecureRandomByteGenerating {
    func bytes(count: Int) async -> SecureRandomResult {
        guard count > 0 else { return .bytes(Data()) }
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, address)
        }
        guard status == errSecSuccess else {
            return .failure(Int32(status))
        }
        return .bytes(data)
    }
}
