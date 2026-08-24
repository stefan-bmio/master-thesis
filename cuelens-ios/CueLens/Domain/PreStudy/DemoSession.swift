import Foundation

enum DemoStep: Equatable, Sendable {
    case cueMatching
    case cueLabeling
    case craving
    case completed
}

enum DemoMatchingChoice: String, CaseIterable, Equatable, Hashable, Sendable {
    case matchA = "match_a_000"
    case matchB = "match_b_000"
}

enum DemoLabelChoice: Equatable, Sendable {
    case fitting
    case lessFitting
}

struct DemoPresentation: Equatable, Sendable {
    static let matchingWaitSeconds = 5

    var step: DemoStep
    let matchingChoices: [DemoMatchingChoice]
    var labelingChoices: [DemoLabelChoice]
    var craving: Int
    var remainingSeconds: Int

    var matchingSelectionEnabled: Bool {
        step == .cueMatching && remainingSeconds == 0
    }

    init(
        reverseMatching: Bool,
        step: DemoStep = .cueMatching,
        labelingChoices: [DemoLabelChoice] = [.fitting, .lessFitting],
        craving: Int = 50,
        remainingSeconds: Int = DemoPresentation.matchingWaitSeconds
    ) {
        self.step = step
        matchingChoices = reverseMatching
            ? [.matchB, .matchA]
            : [.matchA, .matchB]
        self.labelingChoices = labelingChoices
        self.craving = craving
        self.remainingSeconds = remainingSeconds
    }

    mutating func countVisibleSecond() {
        guard step == .cueMatching, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
    }

    mutating func selectMatching(reverseLabels: Bool) {
        guard matchingSelectionEnabled else { return }
        labelingChoices = reverseLabels
            ? [.lessFitting, .fitting]
            : [.fitting, .lessFitting]
        step = .cueLabeling
    }

    mutating func selectLabel() {
        guard step == .cueLabeling else { return }
        step = .craving
    }

    mutating func updateCraving(_ value: Int) {
        guard step == .craving else { return }
        craving = min(100, max(0, value))
    }

    mutating func completeCraving() {
        guard step == .craving else { return }
        step = .completed
    }
}

protocol DemoRandomizing: Sendable {
    func nextBoolean() async -> Bool
}

actor SystemDemoRandomizer: DemoRandomizing {
    func nextBoolean() -> Bool { Bool.random() }
}

protocol DemoSleepClock: Sendable {
    func sleepForVisibleSecond() async throws
}

struct ContinuousDemoSleepClock: DemoSleepClock {
    func sleepForVisibleSecond() async throws {
        try await ContinuousClock().sleep(for: .seconds(1))
    }
}
