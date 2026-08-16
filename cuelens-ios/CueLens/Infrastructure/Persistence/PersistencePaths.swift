import Foundation

struct PersistencePaths: Equatable, Sendable {
    let rootDirectory: URL

    var installationMarker: URL {
        rootDirectory.appendingPathComponent("installation-v1", isDirectory: false)
    }

    var studyState: URL {
        rootDirectory.appendingPathComponent("study-state-v1.json", isDirectory: false)
    }

    static func applicationSupport() throws -> PersistencePaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return PersistencePaths(
            rootDirectory: base.appendingPathComponent("CueLens", isDirectory: true)
        )
    }
}
