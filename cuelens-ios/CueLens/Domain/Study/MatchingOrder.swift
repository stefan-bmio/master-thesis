struct MatchingOrder: Codable, Equatable, Sendable {
    static let itemCount = 50
    static let trialsPerSituation = 5

    let indices: [Int]

    init(_ indices: [Int]) throws {
        guard indices.count == Self.itemCount,
              Set(indices) == Set(0..<Self.itemCount) else {
            throw DomainValidationError.invalidMatchingOrder
        }
        self.indices = indices
    }

    static func randomized(using randomizer: any Randomizing) throws -> MatchingOrder {
        try MatchingOrder(randomizer.shuffled(Array(0..<itemCount)))
    }

    func slice(for situation: SituationNumber) throws -> [Int] {
        guard situation.condition == .cueMatching else {
            throw DomainValidationError.invalidSituation
        }
        let lowerBound = (situation.value - 1) * Self.trialsPerSituation
        let upperBound = lowerBound + Self.trialsPerSituation
        return Array(indices[lowerBound..<upperBound])
    }
}

enum StudySchedule {
    static let totalSituationCount = 20
    static let matchingSituationCount = 10
    static let trialsPerSituation = 5

    static func trialIndices(
        for situation: SituationNumber,
        matchingOrder: MatchingOrder
    ) throws -> [Int] {
        if situation.condition == .cueMatching {
            return try matchingOrder.slice(for: situation)
        }

        let labelingSituationIndex = situation.value - matchingSituationCount - 1
        let lowerBound = labelingSituationIndex * trialsPerSituation
        return Array(lowerBound..<(lowerBound + trialsPerSituation))
    }
}
