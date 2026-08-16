import Foundation

actor ProtectedStudyStateStore: StudyStateStore {
    static let maximumStateSize = 64 * 1_024

    private let paths: PersistencePaths
    private let files: any ProtectedFileAccessing
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        paths: PersistencePaths,
        files: any ProtectedFileAccessing = SystemProtectedFileClient()
    ) {
        self.paths = paths
        self.files = files
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    func readState() async throws -> StudyState {
        try await prepareDirectory()

        let exists: Bool
        do {
            exists = try await files.resourceExists(at: paths.studyState)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .inspectState)
        }
        guard exists else { return try StudyState.initial }

        do {
            try await files.secureExistingResource(at: paths.studyState)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .protectState)
        }
        let data: Data
        do {
            data = try await files.read(at: paths.studyState)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .readState)
        }
        return try decodeVersionedState(data)
    }

    func writeState(_ state: StudyState) async throws {
        try await prepareDirectory()

        let data: Data
        do {
            data = try encoder.encode(state)
            guard data.count <= Self.maximumStateSize,
                  try decodeVersionedState(data) == state else {
                throw PersistenceError.stateCorrupted
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.stateCorrupted
        }

        do {
            try await files.writeProtectedAtomically(data, to: paths.studyState)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .writeState)
        }
    }

    private func prepareDirectory() async throws {
        do {
            try await files.prepareDirectory(at: paths.rootDirectory)
        } catch {
            throw PersistenceError.fileSystemFailure(operation: .prepareDirectory)
        }
    }

    private func decodeVersionedState(_ data: Data) throws -> StudyState {
        guard !data.isEmpty, data.count <= Self.maximumStateSize else {
            throw PersistenceError.stateCorrupted
        }

        let object: [String: Any]
        do {
            object = try StrictJSON.object(from: data)
        } catch {
            throw PersistenceError.stateCorrupted
        }

        let requiredKeys: Set<String> = [
            "schemaVersion",
            "confirmedSituationCount",
            "lastNotifiedSituationNumber",
            "matchingOrder",
            "completion"
        ]
        let allowedKeys = requiredKeys.union([
            "nextSituationAvailableAtMilliseconds",
            "pendingCraving"
        ])
        let actualKeys = Set(object.keys)
        guard requiredKeys.isSubset(of: actualKeys), actualKeys.isSubset(of: allowedKeys),
              let version = StrictJSON.integer(object["schemaVersion"]) else {
            throw PersistenceError.stateCorrupted
        }
        guard version == StudyState.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchemaVersion(version)
        }
        guard let completion = object["completion"] as? [String: Any],
              let kind = StrictJSON.string(completion["kind"]) else {
            throw PersistenceError.stateCorrupted
        }
        let completionKeys = Set(completion.keys)
        switch kind {
        case "incomplete", "invalid", "prolific_completed":
            guard completionKeys == ["kind"] else {
                throw PersistenceError.stateCorrupted
            }
        case "direct_pending_confirmation", "direct_completed":
            guard completionKeys == ["kind", "code"] else {
                throw PersistenceError.stateCorrupted
            }
        default:
            throw PersistenceError.stateCorrupted
        }

        do {
            return try decoder.decode(StudyState.self, from: data)
        } catch {
            throw PersistenceError.stateCorrupted
        }
    }
}
