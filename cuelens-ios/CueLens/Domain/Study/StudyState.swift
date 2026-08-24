import Foundation

struct StudyState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let confirmedSituationCount: Int
    let nextSituationAvailableAt: Date?
    let lastNotifiedSituationNumber: Int
    let matchingOrder: [Int]
    let pendingCraving: Int?
    let completion: CompletionState

    init(
        schemaVersion: Int = currentSchemaVersion,
        confirmedSituationCount: Int = 0,
        nextSituationAvailableAt: Date? = nil,
        lastNotifiedSituationNumber: Int = 0,
        matchingOrder: [Int] = [],
        pendingCraving: Int? = nil,
        completion: CompletionState = .incomplete
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion,
              (0...StudySchedule.totalSituationCount).contains(confirmedSituationCount),
              (0...StudySchedule.totalSituationCount).contains(lastNotifiedSituationNumber),
              lastNotifiedSituationNumber <= min(
                StudySchedule.totalSituationCount,
                confirmedSituationCount + 1
              ),
              nextSituationAvailableAt?.timeIntervalSinceReferenceDate.isFinite != false else {
            throw DomainValidationError.invalidStudyState
        }

        if let pendingCraving {
            _ = try CravingValue(pendingCraving)
        }

        if !matchingOrder.isEmpty {
            _ = try MatchingOrder(matchingOrder)
        }

        let completionNeedsMatchingOrder: Bool
        switch completion {
        case .directPendingConfirmation, .directCompleted, .prolificCompleted:
            completionNeedsMatchingOrder = true
        case .incomplete, .invalid:
            completionNeedsMatchingOrder = false
        }
        let needsMatchingOrder = confirmedSituationCount > 0
            || pendingCraving != nil
            || completionNeedsMatchingOrder
        guard !needsMatchingOrder || !matchingOrder.isEmpty else {
            throw DomainValidationError.invalidStudyState
        }

        if confirmedSituationCount == 0, pendingCraving == nil,
           nextSituationAvailableAt != nil {
            throw DomainValidationError.invalidStudyState
        }
        if (1...19).contains(confirmedSituationCount),
           nextSituationAvailableAt == nil {
            throw DomainValidationError.invalidStudyState
        }

        switch completion {
        case .incomplete:
            guard confirmedSituationCount < StudySchedule.totalSituationCount else {
                throw DomainValidationError.invalidStudyState
            }
        case .invalid:
            break
        case .directPendingConfirmation:
            guard confirmedSituationCount == 19, pendingCraving == nil else {
                throw DomainValidationError.invalidStudyState
            }
        case .directCompleted, .prolificCompleted:
            guard confirmedSituationCount == StudySchedule.totalSituationCount,
                  pendingCraving == nil else {
                throw DomainValidationError.invalidStudyState
            }
        }

        guard pendingCraving == nil || completion == .incomplete else {
            throw DomainValidationError.invalidStudyState
        }

        self.schemaVersion = schemaVersion
        self.confirmedSituationCount = confirmedSituationCount
        self.nextSituationAvailableAt = try Self.canonicalPersistenceDate(
            nextSituationAvailableAt
        )
        self.lastNotifiedSituationNumber = lastNotifiedSituationNumber
        self.matchingOrder = matchingOrder
        self.pendingCraving = pendingCraving
        self.completion = completion
    }

    private static func canonicalPersistenceDate(_ date: Date?) throws -> Date? {
        guard let date else { return nil }
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds >= Double(Int64.min),
              milliseconds <= Double(Int64.max) else {
            throw DomainValidationError.invalidStudyState
        }
        return Date(
            timeIntervalSince1970: Double(Int64(milliseconds.rounded())) / 1_000
        )
    }

    static var initial: StudyState {
        get throws { try StudyState() }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case confirmedSituationCount
        case nextSituationAvailableAtMilliseconds
        case lastNotifiedSituationNumber
        case matchingOrder
        case pendingCraving
        case completion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let milliseconds = try container.decodeIfPresent(
            Int64.self,
            forKey: .nextSituationAvailableAtMilliseconds
        )
        let date = milliseconds.map { Date(timeIntervalSince1970: Double($0) / 1_000) }

        do {
            try self.init(
                schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
                confirmedSituationCount: container.decode(
                    Int.self,
                    forKey: .confirmedSituationCount
                ),
                nextSituationAvailableAt: date,
                lastNotifiedSituationNumber: container.decode(
                    Int.self,
                    forKey: .lastNotifiedSituationNumber
                ),
                matchingOrder: container.decode([Int].self, forKey: .matchingOrder),
                pendingCraving: container.decodeIfPresent(Int.self, forKey: .pendingCraving),
                completion: container.decode(CompletionState.self, forKey: .completion)
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Study state violates domain invariants."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(confirmedSituationCount, forKey: .confirmedSituationCount)
        if let nextSituationAvailableAt {
            let milliseconds = nextSituationAvailableAt.timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite,
                  milliseconds >= Double(Int64.min),
                  milliseconds <= Double(Int64.max) else {
                throw EncodingError.invalidValue(
                    nextSituationAvailableAt,
                    .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "Availability date cannot be represented."
                    )
                )
            }
            try container.encode(
                Int64(milliseconds.rounded()),
                forKey: .nextSituationAvailableAtMilliseconds
            )
        }
        try container.encode(lastNotifiedSituationNumber, forKey: .lastNotifiedSituationNumber)
        try container.encode(matchingOrder, forKey: .matchingOrder)
        try container.encodeIfPresent(pendingCraving, forKey: .pendingCraving)
        try container.encode(completion, forKey: .completion)
    }
}
