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
        let readyStatusExists = app.staticTexts["app.foundationStatus.ready"]
            .waitForExistence(timeout: 10)
        XCTAssertTrue(titleExists)
        XCTAssertTrue(readyStatusExists)
        XCTAssertFalse(app.staticTexts["app.foundationStatus.failure"].exists)
    }
}
