import Foundation
import XCTest
@testable import CueLens

final class FeedbackCoordinatorTests: XCTestCase {
    func testCoordinatorForwardsOnlyValidatedDraftAndConfiguredVersion() async throws {
        let service = FeedbackServiceRecorder()
        let coordinator = FeedbackCoordinator(service: service, appVersion: "1.0.0")
        let draft = try FeedbackDraft(source: "  Praxis  ", comment: "  Verständlich.  ")

        let outcome = await coordinator.submit(draft)
        let submissions = await service.currentSubmissions()

        XCTAssertEqual(outcome, .submitted)
        XCTAssertEqual(submissions, [
            FeedbackServiceRecorder.Submission(
                source: "Praxis",
                comment: "Verständlich.",
                appVersion: "1.0.0"
            )
        ])
    }

    func testFailureIsRetryableAndDoesNotMutateDraft() async throws {
        let service = FeedbackServiceRecorder(failuresRemaining: 1)
        let coordinator = FeedbackCoordinator(service: service, appVersion: "1.0.0")
        let draft = try FeedbackDraft(source: "Flyer", comment: "")

        let firstOutcome = await coordinator.submit(draft)
        let secondOutcome = await coordinator.submit(draft)
        XCTAssertEqual(firstOutcome, .failed)
        XCTAssertEqual(secondOutcome, .submitted)
        let submissions = await service.currentSubmissions()
        XCTAssertEqual(submissions.count, 2)
    }

    func testConcurrentSubmissionsProduceOneRequest() async throws {
        let service = FeedbackServiceRecorder(delay: .milliseconds(100))
        let coordinator = FeedbackCoordinator(service: service, appVersion: "1.0.0")
        let draft = try FeedbackDraft(source: "Flyer", comment: "")

        async let first = coordinator.submit(draft)
        await Task.yield()
        async let second = coordinator.submit(draft)
        let outcomes = await [first, second]
        let requestCount = await service.currentSubmissions().count

        XCTAssertTrue(outcomes.contains(.submitted))
        XCTAssertTrue(outcomes.contains(.ignored))
        XCTAssertEqual(requestCount, 1)
    }
}

private actor FeedbackServiceRecorder: FeedbackServicing {
    struct Submission: Equatable, Sendable {
        let source: String?
        let comment: String?
        let appVersion: String
    }

    private var failuresRemaining: Int
    private let delay: Duration?
    private var submissions: [Submission] = []

    init(failuresRemaining: Int = 0, delay: Duration? = nil) {
        self.failuresRemaining = failuresRemaining
        self.delay = delay
    }

    func submit(source: String?, comment: String?, appVersion: String) async throws {
        submissions.append(Submission(source: source, comment: comment, appVersion: appVersion))
        if let delay { try await Task.sleep(for: delay) }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw NetworkError.transportFailure
        }
    }

    func currentSubmissions() -> [Submission] { submissions }
}
