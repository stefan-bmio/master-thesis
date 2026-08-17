import Foundation

protocol ActivationRecoveryStoring: Sendable {
    func isConfirmationUncertain() async throws -> Bool
    func markConfirmationUncertain() async throws
    func clearConfirmationUncertain() async throws
}

actor ProtectedActivationRecoveryStore: ActivationRecoveryStoring {
    private static let marker = Data("cuelens-activation-confirmation-uncertain-v1\n".utf8)

    private let paths: PersistencePaths
    private let files: any ProtectedFileAccessing

    init(
        paths: PersistencePaths,
        files: any ProtectedFileAccessing = SystemProtectedFileClient()
    ) {
        self.paths = paths
        self.files = files
    }

    func isConfirmationUncertain() async throws -> Bool {
        try await prepareDirectory()
        let exists: Bool
        do {
            exists = try await files.resourceExists(at: paths.activationConfirmationMarker)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .inspectActivationMarker)
        }
        guard exists else { return false }
        do {
            try await files.secureExistingResource(at: paths.activationConfirmationMarker)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .protectActivationMarker)
        }
        let data: Data
        do {
            data = try await files.read(at: paths.activationConfirmationMarker)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .inspectActivationMarker)
        }
        guard data == Self.marker else {
            throw PersistenceError.installationIntegrityFailure
        }
        return true
    }

    func markConfirmationUncertain() async throws {
        try await prepareDirectory()
        do {
            try await files.writeProtectedAtomically(
                Self.marker,
                to: paths.activationConfirmationMarker
            )
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .writeActivationMarker)
        }
    }

    func clearConfirmationUncertain() async throws {
        do {
            try await files.removeResource(at: paths.activationConfirmationMarker)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .deleteActivationMarker)
        }
    }

    private func prepareDirectory() async throws {
        do {
            try await files.prepareDirectory(at: paths.rootDirectory)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .prepareDirectory)
        }
    }
}
