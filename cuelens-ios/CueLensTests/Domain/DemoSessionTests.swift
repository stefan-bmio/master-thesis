import XCTest
@testable import CueLens

final class DemoSessionTests: XCTestCase {
    func testMatchingContainsBothChoicesExactlyOnceAndWaitsFiveVisibleTicks() {
        var session = DemoPresentation(reverseMatching: true)

        XCTAssertEqual(session.matchingChoices, [.matchB, .matchA])
        XCTAssertEqual(Set(session.matchingChoices), Set(DemoMatchingChoice.allCases))
        XCTAssertEqual(session.remainingSeconds, 5)
        XCTAssertFalse(session.matchingSelectionEnabled)

        for expected in stride(from: 4, through: 0, by: -1) {
            session.countVisibleSecond()
            XCTAssertEqual(session.remainingSeconds, expected)
        }
        XCTAssertTrue(session.matchingSelectionEnabled)
        session.countVisibleSecond()
        XCTAssertEqual(session.remainingSeconds, 0)
    }

    func testDemoTransitionsDiscardSelectionsAndClampCraving() {
        var session = DemoPresentation(reverseMatching: false, remainingSeconds: 0)

        session.selectMatching(reverseLabels: true)
        XCTAssertEqual(session.step, .cueLabeling)
        XCTAssertEqual(session.labelingChoices, [.lessFitting, .fitting])
        session.selectLabel()
        XCTAssertEqual(session.step, .craving)
        XCTAssertEqual(session.craving, 50)
        session.updateCraving(-1)
        XCTAssertEqual(session.craving, 0)
        session.updateCraving(101)
        XCTAssertEqual(session.craving, 100)
        session.completeCraving()
        XCTAssertEqual(session.step, .completed)
    }

    func testPrematureMatchingSelectionDoesNothing() {
        var session = DemoPresentation(reverseMatching: false)
        session.selectMatching(reverseLabels: true)
        XCTAssertEqual(session.step, .cueMatching)
    }
}
