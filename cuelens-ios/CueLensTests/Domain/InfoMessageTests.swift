import Foundation
import XCTest
@testable import CueLens

final class InfoMessageTests: XCTestCase {
    func testValidMessagesAreSortedByTimestampThenIdentifier() throws {
        let messages = try InfoMessageBatchDecoder.decode(
            FixtureLoader.data(directory: "messages", name: "valid-messages.json")
        )

        XCTAssertEqual(messages.map(\.id), [1, 2, 3])
        XCTAssertEqual(messages.first?.textGerman, "Erste Nachricht")
        XCTAssertEqual(messages.first?.textEnglish, "First message")
    }

    func testInvalidMessageFixturesRejectWholeResponse() throws {
        for name in [
            "invalid-duplicate-id.json",
            "invalid-fractional-id.json",
            "invalid-calendar-date.json",
            "invalid-extra-field.json"
        ] {
            XCTAssertThrowsError(
                try InfoMessageBatchDecoder.decode(
                    FixtureLoader.data(directory: "messages", name: name)
                ),
                "Fixture should fail: \(name)"
            )
        }
    }

    func testMissingOrWrongRootMessagesValueIsRejected() throws {
        for json in ["{}", #"{"messages":{}}"#, #"{"messages":[],"extra":true}"#] {
            XCTAssertThrowsError(
                try InfoMessageBatchDecoder.decode(Data(json.utf8))
            )
        }
    }
}
