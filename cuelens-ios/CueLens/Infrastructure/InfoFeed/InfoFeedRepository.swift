import Foundation

protocol InfoFeedRepositoryServing: Sendable {
    func loadMessages() async throws -> InfoFeedBatch
    func dismissMessage(id: Int64) async throws
    func markMessagesKnown(ids: Set<Int64>) async throws
}

struct InfoFeedBatch: Equatable, Sendable {
    let visibleMessages: [InfoMessage]
    let fetchedMessageIDs: Set<Int64>
}

actor InfoFeedRepository: InfoFeedRepositoryServing {
    private let service: any InfoFeedServicing
    private let settings: any AppSettingsStoring

    init(service: any InfoFeedServicing, settings: any AppSettingsStoring) {
        self.service = service
        self.settings = settings
    }

    func loadMessages() async throws -> InfoFeedBatch {
        let dismissedIDs = try await settings.load().dismissedMessageIDs
        let messages = try await service.fetchMessages().sorted {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt < $1.createdAt
        }
        return InfoFeedBatch(
            visibleMessages: messages.filter { !dismissedIDs.contains($0.id) },
            fetchedMessageIDs: Set(messages.map(\.id))
        )
    }

    func dismissMessage(id: Int64) async throws {
        try await settings.dismissMessage(id: id)
    }

    func markMessagesKnown(ids: Set<Int64>) async throws {
        try await settings.markMessagesKnown(ids: ids)
    }
}
