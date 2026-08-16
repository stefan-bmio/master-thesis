protocol AppTokenStore: Sendable {
    func readToken() async throws -> UUIDv4?
    func saveToken(_ token: UUIDv4) async throws
    func clearToken() async throws
}

protocol StudyStateStore: Sendable {
    func readState() async throws -> StudyState
    func writeState(_ state: StudyState) async throws
}
