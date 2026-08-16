import Foundation
import XCTest
@testable import CueLens

final class StartGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let order = Array(0..<MatchingOrder.itemCount)

    func testEligibleInitialStateAllowsFirstMatchingSituation() throws {
        XCTAssertEqual(
            decide(try StudyState.initial),
            .allowed(situation: try SituationNumber(1), condition: .cueMatching)
        )
    }

    func testEligibleProgressAllowsNextLabelingSituationAtCooldownBoundary() throws {
        let state = try StudyState(
            confirmedSituationCount: 10,
            nextSituationAvailableAt: now,
            matchingOrder: order
        )

        XCTAssertEqual(
            decide(state),
            .allowed(situation: try SituationNumber(11), condition: .cueLabeling)
        )
    }

    func testEveryPreconditionBlocksFailClosed() throws {
        let regular = try StudyState.initial
        XCTAssertEqual(decide(regular, hasAppToken: false), .blocked(.missingToken))
        XCTAssertEqual(decide(regular, featureEnabled: false), .blocked(.featureDisabled))
        XCTAssertEqual(decide(regular, resourcesAvailable: false), .blocked(.resourcesUnavailable))
        XCTAssertEqual(decide(regular, viewportSuitable: false), .blocked(.unsuitableViewport))

        let pending = try StudyState(
            confirmedSituationCount: 1,
            nextSituationAvailableAt: now,
            matchingOrder: order,
            pendingCraving: 50
        )
        XCTAssertEqual(decide(pending), .blocked(.pendingSelfReport))

        let availability = now.addingTimeInterval(3 * 60 * 60)
        let cooldown = try StudyState(
            confirmedSituationCount: 1,
            nextSituationAvailableAt: availability,
            matchingOrder: order
        )
        XCTAssertEqual(decide(cooldown), .blocked(.cooldown(until: availability)))
    }

    func testEveryCompletionStateHasExplicitDecision() throws {
        let code = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        let invalid = try StudyState(completion: .invalid)
        XCTAssertEqual(decide(invalid), .blocked(.invalidState))

        let pending = try StudyState(
            confirmedSituationCount: 19,
            nextSituationAvailableAt: now,
            matchingOrder: order,
            completion: .directPendingConfirmation(code: code)
        )
        XCTAssertEqual(decide(pending), .blocked(.pendingCompletionConfirmation))

        let direct = try StudyState(
            confirmedSituationCount: 20,
            matchingOrder: order,
            completion: .directCompleted(code: code)
        )
        XCTAssertEqual(decide(direct), .blocked(.completed))

        let prolific = try StudyState(
            confirmedSituationCount: 20,
            matchingOrder: order,
            completion: .prolificCompleted
        )
        XCTAssertEqual(decide(prolific), .blocked(.completed))
    }

    private func decide(
        _ state: StudyState,
        hasAppToken: Bool = true,
        featureEnabled: Bool = true,
        resourcesAvailable: Bool = true,
        viewportSuitable: Bool = true
    ) -> StartGateDecision {
        StudyStartGate.decide(
            state: state,
            hasAppToken: hasAppToken,
            featureEnabled: featureEnabled,
            resourcesAvailable: resourcesAvailable,
            viewportSuitable: viewportSuitable,
            now: now
        )
    }
}
