import Foundation
import UIKit
import UniformTypeIdentifiers

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

enum StudyTransferOutcome: Equatable, Sendable {
    case progressed(StudyState)
    case pending(StudyState)
    case directConfirmationPending(StudyState)
    case completed(StudyState)
    case persistenceFailed
    case secureIdentityUnavailable
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
    func recover(state: StudyState) async -> StudyTransferOutcome
    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyTransferOutcome
}

protocol ProductiveStudySleepClock: Sendable {
    func sleepForVisibleSecond() async throws
}

protocol CompensationCodeCopying: Sendable {
    func copy(_ code: String) async -> Bool
}

struct ContinuousProductiveStudySleepClock: ProductiveStudySleepClock {
    func sleepForVisibleSecond() async throws {
        try await ContinuousClock().sleep(for: .seconds(1))
    }
}

actor SystemCompensationCodeCopier: CompensationCodeCopying {
    func copy(_ code: String) async -> Bool {
        await MainActor.run {
            UIPasteboard.general.setItems(
                [[UTType.utf8PlainText.identifier: code]],
                options: [
                    .localOnly: true,
                    .expirationDate: Date().addingTimeInterval(600)
                ]
            )
            return UIPasteboard.general.string == code
        }
    }
}

actor ProductiveStudyCoordinator: ProductiveStudyManaging {
    private let contentRepository: any StudyContentServing
    private let stateStore: any StudyStateStore
    private let tokenStore: any AppTokenStore
    private let submission: any StudySubmissionServicing
    private let randomizer: any Randomizing
    private let dateProvider: any DateProviding
    private let cooldownSeconds: TimeInterval
    private let appVersion: String
    private var transferInProgress = false

    init(
        contentRepository: any StudyContentServing,
        stateStore: any StudyStateStore,
        tokenStore: any AppTokenStore,
        submission: any StudySubmissionServicing,
        randomizer: any Randomizing = SystemRandomizer(),
        dateProvider: any DateProviding = SystemDateProvider(),
        cooldownSeconds: TimeInterval,
        appVersion: String
    ) {
        self.contentRepository = contentRepository
        self.stateStore = stateStore
        self.tokenStore = tokenStore
        self.submission = submission
        self.randomizer = randomizer
        self.dateProvider = dateProvider
        self.cooldownSeconds = cooldownSeconds
        self.appVersion = appVersion
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
        } catch is PersistenceError {
            return .persistenceFailed
        } catch {
            return .blocked(.invalidState)
        }
    }

    func recover(state: StudyState) async -> StudyTransferOutcome {
        guard !transferInProgress else { return .ignored }
        switch state.completion {
        case .directPendingConfirmation:
            transferInProgress = true
            defer { transferInProgress = false }
            return await confirmDirectCompletion(state)
        case .invalid:
            return .ignored
        case .directCompleted, .prolificCompleted:
            return .completed(state)
        case .incomplete:
            guard state.pendingCraving != nil else { return .ignored }
            transferInProgress = true
            defer { transferInProgress = false }
            return await transferPending(state)
        }
    }

    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyTransferOutcome {
        guard !transferInProgress,
              session.phase == .craving,
              session.situation.value == state.confirmedSituationCount + 1,
              state.pendingCraving == nil,
              state.completion == .incomplete,
              let value = try? CravingValue(craving) else {
            return .ignored
        }
        transferInProgress = true
        defer { transferInProgress = false }

        let pendingState: StudyState
        do {
            pendingState = try replacing(state, pendingCraving: value.value)
            try await stateStore.writeState(pendingState)
        } catch {
            return .persistenceFailed
        }
        return await transferPending(pendingState)
    }

    private func transferPending(_ state: StudyState) async -> StudyTransferOutcome {
        guard let craving = state.pendingCraving,
              let situation = try? SituationNumber(state.confirmedSituationCount + 1) else {
            return .ignored
        }
        let token: UUIDv4
        do {
            guard let storedToken = try await tokenStore.readToken() else {
                return .secureIdentityUnavailable
            }
            token = storedToken
        } catch {
            return .secureIdentityUnavailable
        }

        let response: SelfReportResponse
        do {
            response = try await submission.submitSelfReport(
                token: token,
                craving: craving,
                appVersion: appVersion,
                expectedSituation: situation
            )
        } catch {
            return .pending(state)
        }

        switch response {
        case let .next(confirmedSituation):
            guard confirmedSituation == situation,
                  situation.value < StudySchedule.totalSituationCount else {
                return .pending(state)
            }
            do {
                let confirmed = try StudyState(
                    confirmedSituationCount: confirmedSituation.value,
                    nextSituationAvailableAt: dateProvider.now.addingTimeInterval(cooldownSeconds),
                    lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
                    matchingOrder: state.matchingOrder,
                    completion: .incomplete
                )
                try await stateStore.writeState(confirmed)
                return .progressed(confirmed)
            } catch {
                return .persistenceFailed
            }
        case let .directComplete(code):
            guard situation.value == StudySchedule.totalSituationCount else {
                return .pending(state)
            }
            let confirmationPending: StudyState
            do {
                confirmationPending = try StudyState(
                    confirmedSituationCount: state.confirmedSituationCount,
                    nextSituationAvailableAt: state.nextSituationAvailableAt,
                    lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
                    matchingOrder: state.matchingOrder,
                    completion: .directPendingConfirmation(code: code)
                )
                try await stateStore.writeState(confirmationPending)
            } catch {
                return .persistenceFailed
            }
            return await confirmDirectCompletion(confirmationPending)
        case .prolificComplete:
            guard situation.value == StudySchedule.totalSituationCount else {
                return .pending(state)
            }
            do {
                let completed = try StudyState(
                    confirmedSituationCount: StudySchedule.totalSituationCount,
                    lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
                    matchingOrder: state.matchingOrder,
                    completion: .prolificCompleted
                )
                try await stateStore.writeState(completed)
                return .completed(completed)
            } catch {
                return .persistenceFailed
            }
        }
    }

    private func confirmDirectCompletion(_ state: StudyState) async -> StudyTransferOutcome {
        guard case let .directPendingConfirmation(code) = state.completion else {
            return .ignored
        }
        do {
            try await submission.confirmCompensation(code: code)
        } catch {
            return .directConfirmationPending(state)
        }
        do {
            let completed = try StudyState(
                confirmedSituationCount: StudySchedule.totalSituationCount,
                lastNotifiedSituationNumber: state.lastNotifiedSituationNumber,
                matchingOrder: state.matchingOrder,
                completion: .directCompleted(code: code)
            )
            try await stateStore.writeState(completed)
            return .completed(completed)
        } catch {
            return .directConfirmationPending(state)
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

    func recover(state: StudyState) async -> StudyTransferOutcome { .ignored }

    func submitCraving(
        _ craving: Int,
        session: ProductiveStudySession,
        state: StudyState
    ) async -> StudyTransferOutcome {
        .ignored
    }
}

struct DisabledCompensationCodeCopier: CompensationCodeCopying {
    func copy(_ code: String) async -> Bool { false }
}
