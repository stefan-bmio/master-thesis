import Foundation

enum StartGateBlockReason: Equatable, Sendable {
    case invalidState
    case completed
    case pendingCompletionConfirmation
    case pendingSelfReport
    case missingToken
    case featureDisabled
    case resourcesUnavailable
    case unsuitableViewport
    case cooldown(until: Date)
}

enum StartGateDecision: Equatable, Sendable {
    case allowed(situation: SituationNumber, condition: StudyCondition)
    case blocked(StartGateBlockReason)
}

enum StudyStartGate {
    static func decide(
        state: StudyState,
        hasAppToken: Bool,
        featureEnabled: Bool,
        resourcesAvailable: Bool,
        viewportSuitable: Bool,
        now: Date
    ) -> StartGateDecision {
        switch state.completion {
        case .invalid:
            return .blocked(.invalidState)
        case .directCompleted, .prolificCompleted:
            return .blocked(.completed)
        case .directPendingConfirmation:
            return .blocked(.pendingCompletionConfirmation)
        case .incomplete:
            break
        }

        if state.pendingCraving != nil {
            return .blocked(.pendingSelfReport)
        }
        guard hasAppToken else { return .blocked(.missingToken) }
        guard featureEnabled else { return .blocked(.featureDisabled) }
        guard resourcesAvailable else { return .blocked(.resourcesUnavailable) }
        guard viewportSuitable else { return .blocked(.unsuitableViewport) }

        if let availability = state.nextSituationAvailableAt, availability > now {
            return .blocked(.cooldown(until: availability))
        }

        guard let situation = try? SituationNumber(state.confirmedSituationCount + 1) else {
            return .blocked(.invalidState)
        }
        return .allowed(situation: situation, condition: situation.condition)
    }
}
