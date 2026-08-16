import XCTest
@testable import CueLens

final class ParticipantAndFeedbackTests: XCTestCase {
    func testParticipantIdentifierTrimsAndClassifiesInput() throws {
        XCTAssertEqual(
            try ParticipantIdentifier.parse("  Person@Test.invalid\n"),
            .directEmail("Person@Test.invalid")
        )
        XCTAssertEqual(
            try ParticipantIdentifier.parse("A1B2C3D4E5F6G7H8I9J0K1L2"),
            .prolificID("A1B2C3D4E5F6G7H8I9J0K1L2")
        )
    }

    func testParticipantIdentifierRejectsInvalidValues() throws {
        for value in [
            "",
            "missing-at.example",
            "name@example",
            "name @example.invalid",
            "name..dots@example.invalid",
            "name.@example.invalid",
            "name@example..invalid",
            "name@-example.invalid",
            "A1B2C3D4E5F6G7H8I9J0K1!2",
            "A1B2C3D4E5F6G7H8I9J0K1"
        ] {
            XCTAssertThrowsError(try ParticipantIdentifier.parse(value))
        }
    }

    func testFeedbackTrimsAndRequiresAtLeastOneField() throws {
        XCTAssertEqual(
            try FeedbackDraft(source: "  Flyer  ", comment: "  "),
            try FeedbackDraft(source: "Flyer", comment: "")
        )
        XCTAssertEqual(
            try FeedbackDraft(source: "", comment: "  Verständlich.\n").comment,
            "Verständlich."
        )
        XCTAssertThrowsError(try FeedbackDraft(source: " \n", comment: "\t"))
    }

    func testFeedbackUsesUnicodeScalarLimitsCompatibleWithBackend() throws {
        XCTAssertNoThrow(
            try FeedbackDraft(
                source: String(repeating: "é", count: 500),
                comment: ""
            )
        )
        XCTAssertThrowsError(
            try FeedbackDraft(
                source: String(repeating: "e\u{301}", count: 251),
                comment: ""
            )
        )
        XCTAssertThrowsError(
            try FeedbackDraft(
                source: "x",
                comment: String(repeating: "a", count: 5_001)
            )
        )
    }

    func testAppLanguageHasStableProtocolValues() {
        XCTAssertEqual(AppLanguage.allCases, [.german, .english])
        XCTAssertEqual(AppLanguage.german.rawValue, "de")
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
    }
}
