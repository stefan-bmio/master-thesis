import CoreGraphics
import XCTest
@testable import CueLens

final class StudyViewportPolicyTests: XCTestCase {
    func testAllowsMinimumPortraitGeometry() {
        XCTAssertTrue(
            StudyViewportPolicy.allowsProductiveStudy(
                in: CGSize(width: 375, height: 667)
            )
        )
    }

    func testRejectsLandscapeGeometry() {
        XCTAssertFalse(
            StudyViewportPolicy.allowsProductiveStudy(
                in: CGSize(width: 667, height: 375)
            )
        )
    }

    func testRejectsUndersizedPortraitGeometry() {
        XCTAssertFalse(
            StudyViewportPolicy.allowsProductiveStudy(
                in: CGSize(width: 374, height: 667)
            )
        )
        XCTAssertFalse(
            StudyViewportPolicy.allowsProductiveStudy(
                in: CGSize(width: 375, height: 666)
            )
        )
    }
}
