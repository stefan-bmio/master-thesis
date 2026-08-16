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
}

private struct ReverseRandomizer: Randomizing {
    func shuffled<T>(_ values: [T]) -> [T] {
        Array(values.reversed())
    }

    func nextBoolean() -> Bool { true }
}
