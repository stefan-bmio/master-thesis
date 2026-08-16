import XCTest

final class CueLensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesOnSupportedDevice() {
        let app = XCUIApplication()
        app.launch()

        let titleExists = app.staticTexts["app.title"].waitForExistence(timeout: 10)
        let foundationStatusExists = app.staticTexts["app.foundationStatus"].exists
        XCTAssertTrue(titleExists)
        XCTAssertTrue(foundationStatusExists)
    }
}
