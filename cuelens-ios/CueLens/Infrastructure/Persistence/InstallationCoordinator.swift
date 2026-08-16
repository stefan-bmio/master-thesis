import Foundation

enum InstallationPreparation: Equatable, Sendable {
    case existingInstallation
    case newInstallation
}

protocol InstallationPreparing: Sendable {
    func prepareInstallation() async throws -> InstallationPreparation
}

actor InstallationCoordinator: InstallationPreparing {
    static let markerLength = 32

    private let paths: PersistencePaths
    private let files: any ProtectedFileAccessing
    private let tokenStore: any AppTokenStore
    private let random: any SecureRandomByteGenerating

    init(
        paths: PersistencePaths,
        files: any ProtectedFileAccessing = SystemProtectedFileClient(),
        tokenStore: any AppTokenStore,
        random: any SecureRandomByteGenerating = SystemSecureRandomByteGenerator()
    ) {
        self.paths = paths
        self.files = files
        self.tokenStore = tokenStore
        self.random = random
    }

    func prepareInstallation() async throws -> InstallationPreparation {
        try await prepareDirectory()

        let markerExists: Bool
        do {
            markerExists = try await files.resourceExists(at: paths.installationMarker)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .inspectMarker)
        }

        if markerExists {
            do {
                try await files.secureExistingResource(at: paths.installationMarker)
            } catch {
                throw PersistenceError.fileSystemFailure(operation: .protectMarker)
            }
            let marker: Data
            do {
                marker = try await files.read(at: paths.installationMarker)
            } catch {
                throw PersistenceError.fileSystemFailure(operation: .inspectMarker)
            }
            guard marker.count == Self.markerLength else {
                throw PersistenceError.installationIntegrityFailure
            }
            return .existingInstallation
        }

        let stateExists: Bool
        do {
            stateExists = try await files.resourceExists(at: paths.studyState)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .inspectState)
        }
        guard !stateExists else {
            throw PersistenceError.installationIntegrityFailure
        }

        try await tokenStore.clearToken()

        let marker: Data
        switch await random.bytes(count: Self.markerLength) {
        case .bytes(let data):
            guard data.count == Self.markerLength else {
                throw PersistenceError.installationIntegrityFailure
            }
            marker = data
        case .failure(let status):
            throw PersistenceError.randomGenerationFailure(status: status)
        }

        do {
            try await files.writeProtectedAtomically(marker, to: paths.installationMarker)
            let writtenMarker = try await files.read(at: paths.installationMarker)
            guard writtenMarker == marker else {
                throw PersistenceError.installationIntegrityFailure
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .writeMarker)
        }
        return .newInstallation
    }

    private func prepareDirectory() async throws {
        do {
            try await files.prepareDirectory(at: paths.rootDirectory)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .prepareDirectory)
        }
    }
}
