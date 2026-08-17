import Foundation

enum SecureStoreOperation: String, Equatable, Sendable {
    case read
    case add
    case delete
}

enum ProtectedFileOperation: String, Equatable, Sendable {
    case locateApplicationSupport
    case prepareDirectory
    case inspectMarker
    case protectMarker
    case writeMarker
    case inspectState
    case protectState
    case readState
    case writeState
    case inspectActivationMarker
    case protectActivationMarker
    case writeActivationMarker
    case deleteActivationMarker
}

enum PersistenceError: Error, Equatable, Sendable {
    case keychainFailure(operation: SecureStoreOperation, status: Int32)
    case invalidStoredToken
    case tokenConflict
    case randomGenerationFailure(status: Int32)
    case installationIntegrityFailure
    case fileSystemFailure(operation: ProtectedFileOperation)
    case stateCorrupted
    case unsupportedSchemaVersion(Int)
}
