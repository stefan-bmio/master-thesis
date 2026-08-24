import Foundation

struct PreparedStudyRun: Equatable, Sendable {
    var session: ProductiveStudySession
    let content: StudyContent
    let state: StudyState
}

enum StudyPreparationOutcome: Equatable, Sendable {
    case ready(PreparedStudyRun)
    case blocked(StartGateBlockReason)
    case persistenceFailed
}

enum StudyCravingSubmissionOutcome: Equatable, Sendable {
    case locallyConfirmed(StudyState)
    case pending(StudyState)
    case persistenceFailed
    case ignored
}

protocol ProductiveStudyManaging: Sendable {
    func contentIsAvailable() async -> Bool
    func prepare(
        state: StudyState,
        isActivated: Bool,
        featureEnabled: Bool,
        viewportSuitable: Bool,
        now: Date
    ) async -> StudyPreparationOutcome
    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyCravingSubmissionOutcome
}

protocol LocalStudySubmissionServing: Sendable {
    func acknowledges(situation: SituationNumber) async -> Bool
}

protocol ProductiveStudySleepClock: Sendable {
    func sleepForVisibleSecond() async throws
}

struct ContinuousProductiveStudySleepClock: ProductiveStudySleepClock {
    func sleepForVisibleSecond() async throws {
        try await ContinuousClock().sleep(for: .seconds(1))
    }
}

struct StagingStudySubmissionService: LocalStudySubmissionServing {
    func acknowledges(situation: SituationNumber) async -> Bool {
        situation.value < StudySchedule.totalSituationCount
    }
}

actor ProductiveStudyCoordinator: ProductiveStudyManaging {
    private let contentRepository: any StudyContentServing
    private let stateStore: any StudyStateStore
    private let randomizer: any Randomizing
    private let dateProvider: any DateProviding
    private let cooldownSeconds: TimeInterval
    private let submission: any LocalStudySubmissionServing
    private var submissionInProgress = false

    init(
        contentRepository: any StudyContentServing,
        stateStore: any StudyStateStore,
        randomizer: any Randomizing = SystemRandomizer(),
        dateProvider: any DateProviding = SystemDateProvider(),
        cooldownSeconds: TimeInterval,
        submission: any LocalStudySubmissionServing = StagingStudySubmissionService()
    ) {
        self.contentRepository = contentRepository
        self.stateStore = stateStore
        self.randomizer = randomizer
        self.dateProvider = dateProvider
        self.cooldownSeconds = cooldownSeconds
        self.submission = submission
    }

    func contentIsAvailable() async -> Bool {
        (try? await contentRepository.load()) != nil
    }

    func prepare(
        state: StudyState,
        isActivated: Bool,
        featureEnabled: Bool,
        viewportSuitable: Bool,
        now: Date
    ) async -> StudyPreparationOutcome {
        let content: StudyContent
        do {
            content = try await contentRepository.load()
        } catch {
            return .blocked(.resourcesUnavailable)
        }

        let decision = StudyStartGate.decide(
            state: state,
            hasAppToken: isActivated,
            featureEnabled: featureEnabled,
            resourcesAvailable: true,
            viewportSuitable: viewportSuitable,
            now: now
        )
        guard case let .allowed(situation, _) = decision else {
            if case let .blocked(reason) = decision { return .blocked(reason) }
            return .blocked(.invalidState)
        }

        var preparedState = state
        let matchingOrder: MatchingOrder
        do {
            if state.matchingOrder.isEmpty {
                matchingOrder = try MatchingOrder.randomized(using: randomizer)
                preparedState = try replacing(state, matchingOrder: matchingOrder.indices)
                try await stateStore.writeState(preparedState)
            } else {
                matchingOrder = try MatchingOrder(state.matchingOrder)
            }
            let trialIndices = try StudySchedule.trialIndices(
                for: situation,
                matchingOrder: matchingOrder
            )
            let session = try ProductiveStudySession(
                situation: situation,
                trialIndices: trialIndices,
                reversedChoices: trialIndices.map { _ in randomizer.nextBoolean() }
            )
            return .ready(PreparedStudyRun(session: session, content: content, state: preparedState))
        } catch let error as PersistenceError {
            _ = error
            return .persistenceFailed
        } catch {
            return .blocked(.invalidState)
        }
    }

    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyCravingSubmissionOutcome {
        guard !submissionInProgress,
              session.phase == .craving,
              session.situation.value == state.confirmedSituationCount + 1,
              state.pendingCraving == nil,
              let value = try? CravingValue(craving) else {
            return .ignored
        }
        submissionInProgress = true
        defer { submissionInProgress = false }

        let pendingState: StudyState
        do {
            pendingState = try replacing(state, pendingCraving: value.value)
            try await stateStore.writeState(pendingState)
        } catch {
            return .persistenceFailed
        }

        guard await submission.acknowledges(situation: session.situation) else {
            return .pending(pendingState)
        }

        do {
            let confirmedState = try StudyState(
                confirmedSituationCount: session.situation.value,
                nextSituationAvailableAt: dateProvider.now.addingTimeInterval(cooldownSeconds),
                lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
                matchingOrder: state.matchingOrder,
                completion: .incomplete
            )
            try await stateStore.writeState(confirmedState)
            return .locallyConfirmed(confirmedState)
        } catch {
            return .pending(pendingState)
        }
    }

    private func replacing(
        _ state: StudyState,
        matchingOrder: [Int]? = nil,
        pendingCraving: Int? = nil
    ) throws -> StudyState {
        try StudyState(
            schemaVersion: state.schemaVersion,
            confirmedSituationCount: state.confirmedSituationCount,
            nextSituationAvailableAt: state.nextSituationAvailableAt,
            lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
            matchingOrder: matchingOrder ?? state.matchingOrder,
            pendingCraving: pendingCraving,
            completion: state.completion
        )
    }
}

struct DisabledProductiveStudyManager: ProductiveStudyManaging {
    func contentIsAvailable() async -> Bool { false }

    func prepare(
        state: StudyState,
        isActivated: Bool,
        featureEnabled: Bool,
        viewportSuitable: Bool,
        now: Date
    ) async -> StudyPreparationOutcome {
        .blocked(.featureDisabled)
    }

    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyCravingSubmissionOutcome {
        .ignored
    }
}
