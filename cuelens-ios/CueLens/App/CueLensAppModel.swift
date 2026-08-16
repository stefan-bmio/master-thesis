import Foundation
import Observation

enum AppInitializationState: Equatable, Sendable {
    case loading
    case ready(StudyState)
    case secureStorageFailure
}

@MainActor
@Observable
final class CueLensAppModel {
    private let persistence: any LocalPersistenceLoading
    private(set) var initializationState: AppInitializationState = .loading

    init(persistence: any LocalPersistenceLoading) {
        self.persistence = persistence
    }

    func initialize() async {
        guard initializationState == .loading else { return }
        do {
            let snapshot = try await persistence.load()
            initializationState = .ready(snapshot.studyState)
        } catch {
            initializationState = .secureStorageFailure
        }
    }
}
