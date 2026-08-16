import Foundation
import XCTest
@testable import CueLens

final class SelfReportResponseTests: XCTestCase {
    func testValidNextSituationResponsesDecodeForBothConditions() throws {
        XCTAssertEqual(
            try decode("next-matching.json", expectedSituation: 1),
            .next(situation: try SituationNumber(1))
        )
        XCTAssertEqual(
            try decode("next-labeling.json", expectedSituation: 11),
            .next(situation: try SituationNumber(11))
        )
        XCTAssertEqual(
            try decode("next-nineteen.json", expectedSituation: 19),
            .next(situation: try SituationNumber(19))
        )
    }

    func testDirectAndProlificCompletionResponsesRemainDistinct() throws {
        let code = try UUIDv4("123e4567-e89b-42d3-a456-426614174000")
        XCTAssertEqual(
            try decode("direct-complete.json", expectedSituation: 20),
            .directComplete(compensationCode: code)
        )
        XCTAssertEqual(
            try decode("prolific-complete.json", expectedSituation: 20),
            .prolificComplete
        )
    }

    func testInvalidProtocolFixturesAreRejected() throws {
        for (name, expectedSituation) in [
            ("invalid-completion-combination.json", 20),
            ("invalid-condition.json", 11),
            ("invalid-extra-field.json", 1),
            ("invalid-fractional-index.json", 1),
            ("invalid-success.json", 1),
            ("invalid-uuid.json", 20)
        ] {
            XCTAssertThrowsError(
                try decode(name, expectedSituation: expectedSituation),
                "Fixture should fail: \(name)"
            )
        }
    }

    func testUnexpectedSituationAndFinalSituationWithoutCompletionAreRejected() throws {
        XCTAssertThrowsError(try decode("next-matching.json", expectedSituation: 2))

        let finalWithoutCompletion = """
        {"success":true,"situation_index":20,"condition_code":"CUE_LABELING"}
        """
        XCTAssertThrowsError(
            try SelfReportResponseDecoder.decode(
                Data(finalWithoutCompletion.utf8),
                expectedSituation: SituationNumber(20)
            )
        )
    }

    private func decode(
        _ fixtureName: String,
        expectedSituation: Int
    ) throws -> SelfReportResponse {
        try SelfReportResponseDecoder.decode(
            FixtureLoader.data(directory: "submission", name: fixtureName),
            expectedSituation: SituationNumber(expectedSituation)
        )
    }
}
