import Foundation

enum FixtureLoader {
    static func data(directory: String, name: String) throws -> Data {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(
            contentsOf: repositoryRoot
                .appendingPathComponent("Fixtures", isDirectory: true)
                .appendingPathComponent(directory, isDirectory: true)
                .appendingPathComponent(name)
        )
    }
}
