enum ProductiveStudyPhase: Equatable, Sendable {
    case cueMatching
    case cueLabeling
    case craving
}

enum StudyLabelChoice: Equatable, Sendable {
    case fitting
    case lessFitting
}

struct ProductiveStudySession: Equatable, Sendable {
    static let matchingWaitSeconds = 4

    let situation: SituationNumber
    let trialIndices: [Int]
    let reversedChoices: [Bool]
    private(set) var phase: ProductiveStudyPhase
    private(set) var trialIndex: Int
    private(set) var craving: Int
    private(set) var remainingSeconds: Int

    init(
        situation: SituationNumber,
        trialIndices: [Int],
        reversedChoices: [Bool],
        craving: Int = 50
    ) throws {
        guard trialIndices.count == StudySchedule.trialsPerSituation,
              Set(trialIndices).count == StudySchedule.trialsPerSituation,
              trialIndices.allSatisfy({ (0..<StudyContent.itemCount).contains($0) }),
              reversedChoices.count == StudySchedule.trialsPerSituation else {
            throw DomainValidationError.invalidSituation
        }
        _ = try CravingValue(craving)
        self.situation = situation
        self.trialIndices = trialIndices
        self.reversedChoices = reversedChoices
        phase = situation.condition == .cueMatching ? .cueMatching : .cueLabeling
        trialIndex = 0
        self.craving = craving
        remainingSeconds = situation.condition == .cueMatching
            ? Self.matchingWaitSeconds
            : 0
    }

    var currentItemIndex: Int? {
        trialIndices.indices.contains(trialIndex) ? trialIndices[trialIndex] : nil
    }

    var selectionEnabled: Bool {
        phase == .cueLabeling || (phase == .cueMatching && remainingSeconds == 0)
    }

    var currentChoiceIsReversed: Bool {
        reversedChoices.indices.contains(trialIndex) && reversedChoices[trialIndex]
    }

    mutating func countVisibleSecond() {
        guard phase == .cueMatching, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
    }

    mutating func selectCurrentTrial() {
        guard selectionEnabled, phase != .craving else { return }
        if trialIndex + 1 < trialIndices.count {
            trialIndex += 1
            if phase == .cueMatching {
                remainingSeconds = Self.matchingWaitSeconds
            }
        } else {
            phase = .craving
            remainingSeconds = 0
        }
    }

    mutating func updateCraving(_ value: Int) {
        guard phase == .craving, CravingValue.validRange.contains(value) else { return }
        craving = value
    }
}
