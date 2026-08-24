import XCTest
@testable import CueLens

final class AccessibilityHardeningTests: XCTestCase {
    func testAllTextColorPairsMeetWCAGAAForNormalText() {
        let requiredRatio = 4.5
        let pairs: [(String, CueLensSRGBColor, CueLensSRGBColor)] = [
            ("primary text on background", CueLensPalette.textDefinition, CueLensPalette.backgroundDefinition),
            ("secondary text on background", CueLensPalette.secondaryTextDefinition, CueLensPalette.backgroundDefinition),
            ("error text on background", CueLensPalette.errorDefinition, CueLensPalette.backgroundDefinition),
            ("button text on primary", CueLensPalette.whiteDefinition, CueLensPalette.primaryDefinition),
            ("button text on disabled primary", CueLensPalette.whiteDefinition, CueLensPalette.disabledPrimaryDefinition)
        ]

        for (name, foreground, background) in pairs {
            XCTAssertGreaterThanOrEqual(
                foreground.contrastRatio(with: background),
                requiredRatio,
                "Insufficient contrast for \(name)"
            )
        }
    }
}
