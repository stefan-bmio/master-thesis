import Foundation
import XCTest
@testable import CueLens

final class StudyStateTests: XCTestCase {
    private let order = Array(0..<MatchingOrder.itemCount)

    func testInitialStateHasNoStudyProgressOrSensitiveValue() throws {
        let state = try StudyState.initial

        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.confirmedSituationCount, 0)
        XCTAssertNil(state.nextSituationAvailableAt)
        XCTAssertEqual(state.lastNotifiedSituationNumber, 0)
        XCTAssertTrue(state.matchingOrder.isEmpty)
        XCTAssertNil(state.pendingCraving)
        XCTAssertEqual(state.completion, .incomplete)
    }

    func testValidPendingAndCompletionStatesAreRepresentable() throws {
        let availability = Date(timeIntervalSince1970: 1_700_000_000)
        let pending = try StudyState(
            confirmedSituationCount: 7,
            nextSituationAvailableAt: availability,
            lastNotifiedSituationNumber: 8,
            matchingOrder: order,
            pendingCraving: 63
        )
        XCTAssertEqual(pending.pendingCraving, 63)

        let code = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        XCTAssertNoThrow(
            try StudyState(
                confirmedSituationCount: 19,
                nextSituationAvailableAt: availability,
                matchingOrder: order,
                completion: .directPendingConfirmation(code: code)
            )
        )
        XCTAssertNoThrow(
            try StudyState(
                confirmedSituationCount: 20,
                matchingOrder: order,
                completion: .directCompleted(code: code)
            )
        )
        XCTAssertNoThrow(
            try StudyState(
                confirmedSituationCount: 20,
                matchingOrder: order,
                completion: .prolificCompleted
            )
        )
    }

    func testInvalidStateCombinationsAreRejected() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let code = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")

        XCTAssertThrowsError(try StudyState(schemaVersion: 2))
        XCTAssertThrowsError(try StudyState(confirmedSituationCount: -1))
        XCTAssertThrowsError(try StudyState(confirmedSituationCount: 21))
        XCTAssertThrowsError(try StudyState(nextSituationAvailableAt: date))
        XCTAssertThrowsError(try StudyState(confirmedSituationCount: 1))
        XCTAssertThrowsError(
            try StudyState(
                confirmedSituationCount: 1,
                nextSituationAvailableAt: date,
                matchingOrder: []
            )
        )
        XCTAssertThrowsError(
            try StudyState(
                confirmedSituationCount: 20,
                matchingOrder: order,
                completion: .incomplete
            )
        )
        XCTAssertThrowsError(
            try StudyState(
                confirmedSituationCount: 18,
                nextSituationAvailableAt: date,
                matchingOrder: order,
                completion: .directPendingConfirmation(code: code)
            )
        )
        XCTAssertThrowsError(
            try StudyState(
                confirmedSituationCount: 20,
                matchingOrder: order,
                pendingCraving: 50,
                completion: .prolificCompleted
            )
        )
        XCTAssertThrowsError(
            try StudyState(
                confirmedSituationCount: 1,
                nextSituationAvailableAt: date,
                lastNotifiedSituationNumber: 3,
                matchingOrder: order
            )
        )
    }

    func testCodableRepresentationRoundTripsWithMillisecondsAndTaggedCompletion() throws {
        let code = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        let state = try StudyState(
            confirmedSituationCount: 19,
            nextSituationAvailableAt: Date(timeIntervalSince1970: 1_700_000_000.125),
            lastNotifiedSituationNumber: 19,
            matchingOrder: order,
            completion: .directPendingConfirmation(code: code)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains(#""nextSituationAvailableAtMilliseconds":1700000000125"#))
        XCTAssertTrue(json.contains(#""kind":"direct_pending_confirmation""#))
        XCTAssertEqual(try JSONDecoder().decode(StudyState.self, from: data), state)
    }

    func testAvailabilityIsCanonicalizedToPersistedMillisecondPrecision() throws {
        let rawAvailability = Date(timeIntervalSince1970: 1_700_000_000.123_456)
        let expectedMilliseconds = Int64(
            (rawAvailability.timeIntervalSince1970 * 1_000).rounded()
        )
        let state = try StudyState(
            confirmedSituationCount: 1,
            nextSituationAvailableAt: rawAvailability,
            matchingOrder: order
        )

        XCTAssertEqual(
            state.nextSituationAvailableAt,
            Date(timeIntervalSince1970: Double(expectedMilliseconds) / 1_000)
        )
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(StudyState.self, from: data), state)
    }

    func testDecoderRejectsPersistedStateThatViolatesInvariants() throws {
        let json = """
        {
          "schemaVersion": 1,
          "confirmedSituationCount": 20,
          "lastNotifiedSituationNumber": 20,
          "matchingOrder": [],
          "completion": {"kind": "incomplete"}
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(StudyState.self, from: Data(json.utf8))
        )
    }

    func testCompletionDecoderRejectsMissingForbiddenAndUnknownValues() throws {
        let invalidRepresentations = [
            #"{"kind":"direct_completed"}"#,
            #"{"kind":"prolific_completed","code":"123e4567-e89b-42d3-a456-426614174000"}"#,
            #"{"kind":"unknown"}"#
        ]

        for json in invalidRepresentations {
            XCTAssertThrowsError(
                try JSONDecoder().decode(CompletionState.self, from: Data(json.utf8))
            )
        }
    }
}
