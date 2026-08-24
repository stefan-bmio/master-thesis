import Foundation
import XCTest
@testable import CueLens

final class StudyRulesTests: XCTestCase {
    func testAllTwentySituationsHaveExpectedConditionAndFiveTrials() throws {
        let order = try MatchingOrder(Array(0..<50))
        var allMatchingIndices: [Int] = []

        for rawSituation in 1...20 {
            let situation = try SituationNumber(rawSituation)
            let indices = try StudySchedule.trialIndices(
                for: situation,
                matchingOrder: order
            )
            XCTAssertEqual(indices.count, 5)

            if rawSituation <= 10 {
                XCTAssertEqual(situation.condition, .cueMatching)
                allMatchingIndices.append(contentsOf: indices)
            } else {
                XCTAssertEqual(situation.condition, .cueLabeling)
                XCTAssertEqual(indices, Array(((rawSituation - 11) * 5)..<((rawSituation - 10) * 5)))
            }
        }

        XCTAssertEqual(allMatchingIndices, Array(0..<50))
    }

    func testMatchingOrderGenerationChecksInvariantNotConcreteOrder() throws {
        let order = try MatchingOrder.randomized(using: ReverseRandomizer())
        XCTAssertEqual(order.indices.count, 50)
        XCTAssertEqual(Set(order.indices), Set(0..<50))
        XCTAssertEqual(try order.slice(for: SituationNumber(1)), [49, 48, 47, 46, 45])
    }

    func testMatchingOrderRejectsDuplicatesGapsAndWrongSizes() throws {
        XCTAssertThrowsError(try MatchingOrder(Array(0..<49)))
        XCTAssertThrowsError(try MatchingOrder(Array(0...50)))
        XCTAssertThrowsError(try MatchingOrder(Array(repeating: 0, count: 50)))
    }

    func testCravingAndSituationBoundaries() throws {
        XCTAssertEqual(try CravingValue(0).value, 0)
        XCTAssertEqual(try CravingValue(50).value, 50)
        XCTAssertEqual(try CravingValue(100).value, 100)
        XCTAssertThrowsError(try CravingValue(-1))
        XCTAssertThrowsError(try CravingValue(101))
        XCTAssertThrowsError(try SituationNumber(0))
        XCTAssertThrowsError(try SituationNumber(21))
    }

    func testCooldownRoundsUpAndUnlocksExactlyAtAvailability() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(
            StudyCooldown.formattedRemaining(
                until: now.addingTimeInterval(3_600.001),
                now: now
            ),
            "01:00:01"
        )
        XCTAssertEqual(
            StudyCooldown.formattedRemaining(until: now, now: now),
            "00:00:00"
        )
        XCTAssertEqual(
            StudyCooldown.formattedRemaining(
                until: now.addingTimeInterval(-1),
                now: now
            ),
            "00:00:00"
        )
        XCTAssertEqual(StudyCooldown.format(seconds: 10_800), "03:00:00")
    }

    func testProductiveMatchingRequiresFourVisibleSecondsForEveryTrial() throws {
        var session = try ProductiveStudySession(
            situation: SituationNumber(1),
            trialIndices: [0, 1, 2, 3, 4],
            reversedChoices: [false, true, false, true, false]
        )

        XCTAssertEqual(session.phase, .cueMatching)
        XCTAssertFalse(session.selectionEnabled)
        session.selectCurrentTrial()
        XCTAssertEqual(session.trialIndex, 0)
        for second in stride(from: 3, through: 0, by: -1) {
            session.countVisibleSecond()
            XCTAssertEqual(session.remainingSeconds, second)
        }
        XCTAssertTrue(session.selectionEnabled)
        session.selectCurrentTrial()
        XCTAssertEqual(session.trialIndex, 1)
        XCTAssertEqual(session.remainingSeconds, 4)
        XCTAssertTrue(session.currentChoiceIsReversed)

        for _ in 1..<StudySchedule.trialsPerSituation {
            for _ in 0..<4 { session.countVisibleSecond() }
            session.selectCurrentTrial()
        }
        XCTAssertEqual(session.phase, .craving)
        XCTAssertEqual(session.craving, 50)
    }

    func testProductiveLabelingUsesFiveFixedTrialsWithoutPersistingAChoice() throws {
        var session = try ProductiveStudySession(
            situation: SituationNumber(11),
            trialIndices: [0, 1, 2, 3, 4],
            reversedChoices: [true, false, true, false, true]
        )

        XCTAssertEqual(session.phase, .cueLabeling)
        XCTAssertTrue(session.selectionEnabled)
        for expectedIndex in 0..<StudySchedule.trialsPerSituation {
            XCTAssertEqual(session.currentItemIndex, expectedIndex)
            session.selectCurrentTrial()
        }
        XCTAssertEqual(session.phase, .craving)
        session.updateCraving(0)
        XCTAssertEqual(session.craving, 0)
        session.updateCraving(100)
        XCTAssertEqual(session.craving, 100)
        session.updateCraving(101)
        XCTAssertEqual(session.craving, 100)
    }

    func testCoordinatorPersistsPermutationAndPendingBeforeLocalAcknowledgement() async throws {
        let store = RecordingStudyStateStore(initial: try StudyState.initial)
        let submission = InspectingStudySubmission(store: store, acknowledges: true)
        let now = Date(timeIntervalSince1970: 1_000)
        let coordinator = ProductiveStudyCoordinator(
            contentRepository: StaticStudyContentRepository(),
            stateStore: store,
            randomizer: ReverseRandomizer(),
            dateProvider: FixedStudyDateProvider(now: now),
            cooldownSeconds: 3,
            submission: submission
        )

        let preparation = await coordinator.prepare(
            state: try StudyState.initial,
            isActivated: true,
            featureEnabled: true,
            viewportSuitable: true,
            now: now
        )
        guard case var .ready(run) = preparation else {
            return XCTFail("Expected prepared study run")
        }
        XCTAssertEqual(run.session.trialIndices, [49, 48, 47, 46, 45])
        for _ in 0..<5 {
            for _ in 0..<4 { run.session.countVisibleSecond() }
            run.session.selectCurrentTrial()
        }

        let result = await coordinator.submitCraving(
            37,
            session: run.session,
            state: run.state
        )
        guard case let .locallyConfirmed(state) = result else {
            return XCTFail("Expected local confirmation")
        }
        XCTAssertEqual(state.confirmedSituationCount, 1)
        XCTAssertEqual(state.nextSituationAvailableAt, now.addingTimeInterval(3))
        XCTAssertNil(state.pendingCraving)
        let observedPending = await submission.observedPendingBeforeCall()
        XCTAssertTrue(observedPending)
        let writes = await store.writtenStates()
        XCTAssertEqual(writes.map(\.pendingCraving), [nil, 37, nil])
        XCTAssertEqual(writes.last?.confirmedSituationCount, 1)
    }

    func testTwentiethSituationRemainsPendingForRecoveryInNextOrder() async throws {
        let initial = try StudyState(
            confirmedSituationCount: 19,
            nextSituationAvailableAt: Date(timeIntervalSince1970: 0),
            matchingOrder: Array(0..<50)
        )
        let store = RecordingStudyStateStore(initial: initial)
        let coordinator = ProductiveStudyCoordinator(
            contentRepository: StaticStudyContentRepository(),
            stateStore: store,
            randomizer: ReverseRandomizer(),
            dateProvider: FixedStudyDateProvider(now: Date()),
            cooldownSeconds: 3
        )
        let preparation = await coordinator.prepare(
            state: initial,
            isActivated: true,
            featureEnabled: true,
            viewportSuitable: true,
            now: Date()
        )
        guard case var .ready(run) = preparation else {
            return XCTFail("Expected situation 20")
        }
        XCTAssertEqual(run.session.situation.value, 20)
        XCTAssertEqual(run.session.trialIndices, [45, 46, 47, 48, 49])
        for _ in 0..<5 { run.session.selectCurrentTrial() }

        let result = await coordinator.submitCraving(
            50,
            session: run.session,
            state: run.state
        )
        guard case let .pending(state) = result else {
            return XCTFail("Final fake submission must remain pending")
        }
        XCTAssertEqual(state.confirmedSituationCount, 19)
        XCTAssertEqual(state.pendingCraving, 50)
    }
}

private struct ReverseRandomizer: Randomizing {
    func shuffled<T>(_ values: [T]) -> [T] {
        Array(values.reversed())
    }

    func nextBoolean() -> Bool { true }
}

private struct FixedStudyDateProvider: DateProviding {
    let now: Date
}

private struct StaticStudyContentRepository: StudyContentServing {
    func load() async throws -> StudyContent {
        try StudyContent(
            matchingItems: (0..<50).map {
                MatchingItem(
                    index: $0,
                    cueAssetName: "cue_\($0)",
                    matchAAssetName: "a_\($0)",
                    matchBAssetName: "b_\($0)"
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

private actor RecordingStudyStateStore: StudyStateStore {
    private var state: StudyState
    private var writes: [StudyState] = []

    init(initial: StudyState) { state = initial }
    func readState() async throws -> StudyState { state }
    func writeState(_ state: StudyState) async throws {
        self.state = state
        writes.append(state)
    }
    func currentState() -> StudyState { state }
    func writtenStates() -> [StudyState] { writes }
}

private actor InspectingStudySubmission: LocalStudySubmissionServing {
    private let store: RecordingStudyStateStore
    private let result: Bool
    private var observedPending = false

    init(store: RecordingStudyStateStore, acknowledges: Bool) {
        self.store = store
        result = acknowledges
    }

    func acknowledges(situation: SituationNumber) async -> Bool {
        observedPending = await store.currentState().pendingCraving != nil
        return result
    }

    func observedPendingBeforeCall() -> Bool { observedPending }
}
