import Foundation

struct ResourceSecurity: Equatable, Sendable {
    let hasCompleteFileProtection: Bool
    let isExcludedFromBackup: Bool

    var isValid: Bool {
        hasCompleteFileProtection && isExcludedFromBackup
    }
}

private enum ProtectedFileClientError: Error {
    case securityAttributesNotApplied
}

protocol ProtectedFileAccessing: Sendable {
    func prepareDirectory(at url: URL) async throws
    func resourceExists(at url: URL) async throws -> Bool
    func read(at url: URL) async throws -> Data
    func writeProtectedAtomically(_ data: Data, to url: URL) async throws
    func removeResource(at url: URL) async throws
    func secureExistingResource(at url: URL) async throws
    func securityAttributes(at url: URL) async throws -> ResourceSecurity
}

struct SystemProtectedFileClient: ProtectedFileAccessing {
    func prepareDirectory(at url: URL) async throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        try await secureExistingResource(at: url)
    }

    func resourceExists(at url: URL) async throws -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
            return true
        } catch {
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain,
               (cocoaError.code == NSFileNoSuchFileError
                || cocoaError.code == NSFileReadNoSuchFileError) {
                return false
            }
            throw error
        }
    }

    func read(at url: URL) async throws -> Data {
        try Data(contentsOf: url)
    }

    func writeProtectedAtomically(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try await secureExistingResource(at: url)
    }

    func removeResource(at url: URL) async throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            let cocoaError = error as NSError
            guard cocoaError.domain == NSCocoaErrorDomain,
                  (cocoaError.code == NSFileNoSuchFileError
                   || cocoaError.code == NSFileReadNoSuchFileError) else {
                throw error
            }
        }
    }

    func secureExistingResource(at url: URL) async throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        var resourceURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try resourceURL.setResourceValues(values)

        let security = try await securityAttributes(at: url)
        guard security.isExcludedFromBackup else {
            throw ProtectedFileClientError.securityAttributesNotApplied
        }
#if !targetEnvironment(simulator)
        guard security.hasCompleteFileProtection else {
            throw ProtectedFileClientError.securityAttributesNotApplied
        }
#endif
    }

    func securityAttributes(at url: URL) async throws -> ResourceSecurity {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return ResourceSecurity(
            hasCompleteFileProtection: protection == .complete,
            isExcludedFromBackup: values.isExcludedFromBackup == true
        )
    }
}
