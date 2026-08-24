import Foundation
import XCTest
@testable import CueLens

final class ProductiveStudyCoordinatorTests: XCTestCase {
    private let order = Array(0..<50)
    private let tokenText = "550e8400-e29b-41d4-a716-446655440000"
    private let codeText = "123e4567-e89b-42d3-a456-426614174000"

    func testPendingRetryUsesStoredValueAndPersistsThreeHourProgress() async throws {
        let pending = try StudyState(
            matchingOrder: order,
            pendingCraving: 63
        )
        let store = CoordinatorStateStore(initial: pending)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.next(situation: try SituationNumber(1)))]
        )
        let now = Date(timeIntervalSince1970: 2_000)
        let coordinator = try makeCoordinator(
            store: store,
            service: service,
            now: now,
            cooldownSeconds: 10_800
        )

        let outcome = await coordinator.recover(state: pending)

        guard case let .progressed(state) = outcome else {
            return XCTFail("Expected confirmed progress")
        }
        XCTAssertEqual(state.confirmedSituationCount, 1)
        XCTAssertEqual(state.nextSituationAvailableAt, now.addingTimeInterval(10_800))
        XCTAssertNil(state.pendingCraving)
        let requests = await service.currentRequests()
        XCTAssertEqual(
            requests,
            [CoordinatorSubmissionService.Request(
                token: tokenText,
                craving: 63,
                appVersion: "1.0.0",
                expectedSituation: 1
            )]
        )
    }

    func testSuccessfulReportCanonicalizesRealClockPrecisionBeforePersistence() async throws {
        let pending = try StudyState(matchingOrder: order, pendingCraving: 63)
        let store = CoordinatorStateStore(initial: pending)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.next(situation: try SituationNumber(1)))]
        )
        let now = Date(timeIntervalSince1970: 2_000.123_456)
        let coordinator = try makeCoordinator(
            store: store,
            service: service,
            now: now,
            cooldownSeconds: 10_800
        )

        let outcome = await coordinator.recover(state: pending)

        guard case let .progressed(state) = outcome else {
            return XCTFail("Expected confirmed progress")
        }
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(StudyState.self, from: data), state)
    }

    func testNetworkOrProtocolFailureKeepsPendingWithoutProgress() async throws {
        let pending = try StudyState(matchingOrder: order, pendingCraving: 42)
        let store = CoordinatorStateStore(initial: pending)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.failure]
        )
        let coordinator = try makeCoordinator(store: store, service: service)

        let outcome = await coordinator.recover(state: pending)

        XCTAssertEqual(outcome, .pending(pending))
        let writes = await store.currentWrites()
        XCTAssertTrue(writes.isEmpty)
    }

    func testUnexpectedSituationFromServiceCannotAdvanceProgress() async throws {
        let pending = try StudyState(matchingOrder: order, pendingCraving: 42)
        let store = CoordinatorStateStore(initial: pending)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.next(situation: try SituationNumber(2)))]
        )
        let coordinator = try makeCoordinator(store: store, service: service)

        let outcome = await coordinator.recover(state: pending)

        XCTAssertEqual(outcome, .pending(pending))
        let writes = await store.currentWrites()
        XCTAssertTrue(writes.isEmpty)
    }

    func testDirectCodeIsPersistedBeforeConfirmationAndThenCompleted() async throws {
        let pending = try finalPendingState(craving: 50)
        let store = CoordinatorStateStore(initial: pending)
        let code = try UUIDv4(codeText)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.directComplete(compensationCode: code))],
            confirmationOutcomes: [true]
        )
        let coordinator = try makeCoordinator(store: store, service: service)

        let outcome = await coordinator.recover(state: pending)

        guard case let .completed(state) = outcome else {
            return XCTFail("Expected direct completion")
        }
        XCTAssertEqual(state.confirmedSituationCount, 20)
        XCTAssertEqual(state.completion, .directCompleted(code: code))
        let writes = await store.currentWrites()
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes.first?.completion, .directPendingConfirmation(code: code))
        XCTAssertEqual(writes.first?.confirmedSituationCount, 19)
        XCTAssertNil(writes.first?.pendingCraving)
        XCTAssertEqual(writes.last?.completion, .directCompleted(code: code))
        let observedCode = await service.confirmationObservedPersistedCode()
        XCTAssertTrue(observedCode)
    }

    func testFailedDirectConfirmationSurvivesRestartAndRetriesOnlyConfirmation() async throws {
        let pending = try finalPendingState(craving: 75)
        let store = CoordinatorStateStore(initial: pending)
        let code = try UUIDv4(codeText)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.directComplete(compensationCode: code))],
            confirmationOutcomes: [false, true]
        )
        let firstCoordinator = try makeCoordinator(store: store, service: service)

        let firstOutcome = await firstCoordinator.recover(state: pending)
        guard case let .directConfirmationPending(recoveryState) = firstOutcome else {
            return XCTFail("Expected persisted confirmation retry")
        }
        XCTAssertEqual(recoveryState.completion, .directPendingConfirmation(code: code))

        let restartedCoordinator = try makeCoordinator(store: store, service: service)
        let secondOutcome = await restartedCoordinator.recover(state: recoveryState)
        guard case let .completed(completed) = secondOutcome else {
            return XCTFail("Expected recovered direct completion")
        }
        XCTAssertEqual(completed.completion, .directCompleted(code: code))
        let requestCount = await service.currentRequests().count
        let confirmationCount = await service.currentConfirmations().count
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(confirmationCount, 2)
    }

    func testProlificCompletionPersistsNoCodeAndNoCooldown() async throws {
        let pending = try finalPendingState(craving: 20)
        let store = CoordinatorStateStore(initial: pending)
        let service = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.prolificComplete)]
        )
        let coordinator = try makeCoordinator(store: store, service: service)

        let outcome = await coordinator.recover(state: pending)

        guard case let .completed(state) = outcome else {
            return XCTFail("Expected Prolific completion")
        }
        XCTAssertEqual(state.confirmedSituationCount, 20)
        XCTAssertEqual(state.completion, .prolificCompleted)
        XCTAssertNil(state.pendingCraving)
        XCTAssertNil(state.nextSituationAvailableAt)
        let confirmations = await service.currentConfirmations()
        XCTAssertTrue(confirmations.isEmpty)
    }

    func testUnavailableTokenAndConcurrentRetryAreFailClosed() async throws {
        let pending = try StudyState(matchingOrder: order, pendingCraving: 10)
        let missingTokenStore = CoordinatorTokenStore(token: nil)
        let missingStore = CoordinatorStateStore(initial: pending)
        let missingService = CoordinatorSubmissionService(store: missingStore)
        let missingCoordinator = ProductiveStudyCoordinator(
            contentRepository: CoordinatorContentRepository(),
            stateStore: missingStore,
            tokenStore: missingTokenStore,
            submission: missingService,
            cooldownSeconds: 3,
            appVersion: "1.0.0"
        )
        let missingOutcome = await missingCoordinator.recover(state: pending)
        XCTAssertEqual(missingOutcome, .secureIdentityUnavailable)
        let missingRequests = await missingService.currentRequests()
        XCTAssertTrue(missingRequests.isEmpty)

        let store = CoordinatorStateStore(initial: pending)
        let delayedService = CoordinatorSubmissionService(
            store: store,
            selfReportOutcomes: [.response(.next(situation: try SituationNumber(1)))],
            delay: .milliseconds(100)
        )
        let coordinator = try makeCoordinator(store: store, service: delayedService)
        async let first = coordinator.recover(state: pending)
        async let second = coordinator.recover(state: pending)
        let outcomes = await [first, second]
        XCTAssertEqual(outcomes.filter { $0 == .ignored }.count, 1)
        let delayedRequestCount = await delayedService.currentRequests().count
        XCTAssertEqual(delayedRequestCount, 1)
    }

    func testPendingPersistenceFailurePreventsFirstNetworkRequest() async throws {
        let initial = try StudyState(matchingOrder: order)
        let store = CoordinatorStateStore(initial: initial, failWrites: true)
        let service = CoordinatorSubmissionService(store: store)
        let coordinator = try makeCoordinator(store: store, service: service)
        var session = try ProductiveStudySession(
            situation: SituationNumber(1),
            trialIndices: [0, 1, 2, 3, 4],
            reversedChoices: [false, false, false, false, false]
        )
        for _ in 0..<5 {
            for _ in 0..<4 { session.countVisibleSecond() }
            session.selectCurrentTrial()
        }

        let outcome = await coordinator.submitCraving(
            50,
            session: session,
            state: initial
        )

        XCTAssertEqual(outcome, .persistenceFailed)
        let requests = await service.currentRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    private func finalPendingState(craving: Int) throws -> StudyState {
        try StudyState(
            confirmedSituationCount: 19,
            nextSituationAvailableAt: Date(timeIntervalSince1970: 0),
            matchingOrder: order,
            pendingCraving: craving
        )
    }

    private func makeCoordinator(
        store: CoordinatorStateStore,
        service: CoordinatorSubmissionService,
        now: Date = Date(timeIntervalSince1970: 1_000),
        cooldownSeconds: TimeInterval = 3
    ) throws -> ProductiveStudyCoordinator {
        ProductiveStudyCoordinator(
            contentRepository: CoordinatorContentRepository(),
            stateStore: store,
            tokenStore: CoordinatorTokenStore(token: try UUIDv4(tokenText)),
            submission: service,
            dateProvider: CoordinatorDateProvider(now: now),
            cooldownSeconds: cooldownSeconds,
            appVersion: "1.0.0"
        )
    }
}

private struct CoordinatorContentRepository: StudyContentServing {
    func load() async throws -> StudyContent {
        try StudyContent(
            matchingItems: (0..<50).map {
                MatchingItem(
                    index: $0,
                    cueAssetName: "cue_\($0)",
                    matchAAssetName: "match_a_\($0)",
                    matchBAssetName: "match_b_\($0)"
                )
            },
            labelingItems: (0..<50).map {
                LabelingItem(
                    index: $0,
                    cueAssetName: "cue_\($0)",
                    german: LabelPair(fitting: "Passend", lessFitting: "Weniger passend"),
                    english: LabelPair(fitting: "Fitting", lessFitting: "Less fitting")
                )
            }
        )
    }
}

private struct CoordinatorDateProvider: DateProviding {
    let now: Date
}

private actor CoordinatorTokenStore: AppTokenStore {
    private let token: UUIDv4?
    init(token: UUIDv4?) { self.token = token }
    func readToken() async throws -> UUIDv4? { token }
    func saveToken(_ token: UUIDv4) async throws {}
    func clearToken() async throws {}
}

private actor CoordinatorStateStore: StudyStateStore {
    private var state: StudyState
    private var writes: [StudyState] = []
    private let failWrites: Bool

    init(initial: StudyState, failWrites: Bool = false) {
        state = initial
        self.failWrites = failWrites
    }
    func readState() async throws -> StudyState { state }
    func writeState(_ state: StudyState) async throws {
        if failWrites { throw NetworkError.transportFailure }
        self.state = state
        writes.append(state)
    }
    func currentState() -> StudyState { state }
    func currentWrites() -> [StudyState] { writes }
}

private actor CoordinatorSubmissionService: StudySubmissionServicing {
    struct Request: Equatable, Sendable {
        let token: String
        let craving: Int
        let appVersion: String
        let expectedSituation: Int
    }

    enum SelfReportOutcome: Sendable {
        case response(SelfReportResponse)
        case failure
    }

    private let store: CoordinatorStateStore
    private var selfReportOutcomes: [SelfReportOutcome]
    private var confirmationOutcomes: [Bool]
    private let delay: Duration?
    private var requests: [Request] = []
    private var confirmations: [String] = []
    private var observedPersistedCode = false

    init(
        store: CoordinatorStateStore,
        selfReportOutcomes: [SelfReportOutcome] = [],
        confirmationOutcomes: [Bool] = [],
        delay: Duration? = nil
    ) {
        self.store = store
        self.selfReportOutcomes = selfReportOutcomes
        self.confirmationOutcomes = confirmationOutcomes
        self.delay = delay
    }

    func submitSelfReport(
        token: UUIDv4,
        craving: Int,
        appVersion: String,
        expectedSituation: SituationNumber
    ) async throws -> SelfReportResponse {
        requests.append(Request(
            token: token.description,
            craving: craving,
            appVersion: appVersion,
            expectedSituation: expectedSituation.value
        ))
        if let delay { try await Task.sleep(for: delay) }
        guard !selfReportOutcomes.isEmpty else { throw NetworkError.transportFailure }
        switch selfReportOutcomes.removeFirst() {
        case let .response(response): return response
        case .failure: throw NetworkError.protocolViolation
        }
    }

    func confirmCompensation(code: UUIDv4) async throws {
        confirmations.append(code.description)
        let state = await store.currentState()
        observedPersistedCode = state.completion == .directPendingConfirmation(code: code)
        guard !confirmationOutcomes.isEmpty, confirmationOutcomes.removeFirst() else {
            throw NetworkError.transportFailure
        }
    }

    func currentRequests() -> [Request] { requests }
    func currentConfirmations() -> [String] { confirmations }
    func confirmationObservedPersistedCode() -> Bool { observedPersistedCode }
}
