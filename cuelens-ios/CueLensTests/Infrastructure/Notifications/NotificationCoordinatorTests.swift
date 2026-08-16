import Foundation
import XCTest
@testable import CueLens

final class NotificationCoordinatorTests: XCTestCase {
    func testAuthorizationOnlyRequestsWhenUndetermined() async {
        let allowed = NotificationCenterClientStub(authorization: .allowed)
        let allowedResult = await NotificationCoordinator(client: allowed).requestAuthorization()
        let allowedRequestCount = await allowed.currentAuthorizationRequestCount()
        XCTAssertTrue(allowedResult)
        XCTAssertEqual(allowedRequestCount, 0)

        let denied = NotificationCenterClientStub(authorization: .denied)
        let deniedResult = await NotificationCoordinator(client: denied).requestAuthorization()
        let deniedRequestCount = await denied.currentAuthorizationRequestCount()
        XCTAssertFalse(deniedResult)
        XCTAssertEqual(deniedRequestCount, 0)

        let undetermined = NotificationCenterClientStub(
            authorization: .notDetermined,
            authorizationRequestResult: true
        )
        let undeterminedResult = await NotificationCoordinator(client: undetermined).requestAuthorization()
        let undeterminedRequestCount = await undetermined.currentAuthorizationRequestCount()
        XCTAssertTrue(undeterminedResult)
        XCTAssertEqual(undeterminedRequestCount, 1)
    }

    func testEligibleReminderUsesDeterministicIdentifierAndNeutralLocalizedText() async throws {
        let client = NotificationCenterClientStub(authorization: .allowed)
        let coordinator = NotificationCoordinator(client: client)
        let delivery = Date(timeIntervalSince1970: 2_000_000_000)

        await coordinator.reconcileStudyReminder(
            try reminderContext(delivery: delivery, language: .german)
        )

        let added = await client.currentAdded()
        let request = try XCTUnwrap(added.last)
        XCTAssertEqual(request.identifier, "de.eachandevery.cuelens.study-reminder.2")
        XCTAssertEqual(request.title, "CueLens")
        XCTAssertEqual(request.body, "Eine neue Aufgabe ist verfügbar.")
        XCTAssertEqual(request.deliveryDate, delivery)
        XCTAssertFalse(request.body.lowercased().contains("rauch"))
    }

    func testLanguageChangeReplacesPendingReminderAndRemovesObsoleteReminder() async throws {
        let current = NotificationCoordinator.reminderIdentifier(situationNumber: 2)
        let obsolete = NotificationCoordinator.reminderIdentifier(situationNumber: 3)
        let client = NotificationCenterClientStub(
            authorization: .allowed,
            pending: [current, obsolete]
        )
        let coordinator = NotificationCoordinator(client: client)

        await coordinator.reconcileStudyReminder(
            try reminderContext(
                delivery: Date(timeIntervalSince1970: 2_000_000_000),
                language: .english
            )
        )

        let removed = await client.currentRemovedPending()
        let added = await client.currentAdded()
        XCTAssertEqual(removed, [obsolete])
        let replacement = try XCTUnwrap(added.last)
        XCTAssertEqual(replacement.identifier, current)
        XCTAssertEqual(replacement.body, "A new task is available.")
    }

    func testDeliveredReminderIsNotScheduledAgain() async throws {
        let identifier = NotificationCoordinator.reminderIdentifier(situationNumber: 2)
        let client = NotificationCenterClientStub(
            authorization: .allowed,
            delivered: [identifier]
        )
        let coordinator = NotificationCoordinator(client: client)

        await coordinator.reconcileStudyReminder(
            try reminderContext(delivery: Date(timeIntervalSince1970: 2_000_000_000))
        )

        let added = await client.currentAdded()
        XCTAssertTrue(added.isEmpty)
    }

    func testIneligibleStatesCancelAllReminderRequests() async throws {
        let reminders: Set<String> = [
            NotificationCoordinator.reminderIdentifier(situationNumber: 2),
            NotificationCoordinator.reminderIdentifier(situationNumber: 7)
        ]
        let client = NotificationCenterClientStub(
            authorization: .allowed,
            pending: reminders
        )
        let coordinator = NotificationCoordinator(client: client)
        let context = try reminderContext(
            delivery: Date(timeIntervalSince1970: 2_000_000_000),
            notificationsEnabled: false
        )

        await coordinator.reconcileStudyReminder(context)

        let removed = await client.currentRemovedPending()
        let added = await client.currentAdded()
        XCTAssertEqual(removed, reminders)
        XCTAssertTrue(added.isEmpty)
    }

    func testPolicyRejectsMissingActivationFeaturePermissionPendingCompletionAndDuplicates() throws {
        let valid = try reminderContext(delivery: Date(timeIntervalSince1970: 2_000_000_000))
        XCTAssertEqual(
            StudyReminderPolicy.decision(for: valid),
            .schedule(situationNumber: 2, deliveryDate: valid.state.nextSituationAvailableAt ?? .distantPast)
        )

        let invalidContexts = [
            try reminderContext(delivery: valid.state.nextSituationAvailableAt, systemAllowed: false),
            try reminderContext(delivery: valid.state.nextSituationAvailableAt, appActivated: false),
            try reminderContext(delivery: valid.state.nextSituationAvailableAt, featureEnabled: false),
            try reminderContext(delivery: valid.state.nextSituationAvailableAt, pendingCraving: 50),
            try reminderContext(delivery: valid.state.nextSituationAvailableAt, lastNotified: 2)
        ]
        for context in invalidContexts {
            XCTAssertEqual(StudyReminderPolicy.decision(for: context), .cancel)
        }
    }

    func testInformationNotificationAndRoutesAreGeneric() async {
        let client = NotificationCenterClientStub(authorization: .allowed)
        let coordinator = NotificationCoordinator(client: client)
        await coordinator.scheduleInformationNotification(language: .english)

        let requests = await client.currentAdded()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].body, "New CueLens information available")
        XCTAssertEqual(
            NotificationCoordinator.route(for: requests[0].identifier),
            .informationFeed
        )
        XCTAssertEqual(
            NotificationCoordinator.route(
                for: NotificationCoordinator.reminderIdentifier(situationNumber: 20)
            ),
            .studyHome
        )
        XCTAssertNil(NotificationCoordinator.route(for: "unrelated"))
        XCTAssertEqual(
            NotificationText.publicReminderBody(language: .german),
            "Eine neue Information ist verfügbar."
        )
        XCTAssertEqual(
            NotificationText.publicReminderBody(language: .english),
            "New information is available."
        )
    }

    private func reminderContext(
        delivery: Date?,
        language: AppLanguage = .german,
        notificationsEnabled: Bool = true,
        systemAllowed: Bool = true,
        appActivated: Bool = true,
        featureEnabled: Bool = true,
        pendingCraving: Int? = nil,
        lastNotified: Int = 0
    ) throws -> StudyReminderContext {
        StudyReminderContext(
            notificationsEnabled: notificationsEnabled,
            systemAuthorizationAllowed: systemAllowed,
            appActivated: appActivated,
            featureEnabled: featureEnabled,
            state: try StudyState(
                confirmedSituationCount: 1,
                nextSituationAvailableAt: delivery,
                lastNotifiedSituationNumber: lastNotified,
                matchingOrder: Array(0..<MatchingOrder.itemCount),
                pendingCraving: pendingCraving
            ),
            language: language,
            now: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }
}

private actor NotificationCenterClientStub: NotificationCenterClient {
    private var authorization: NotificationAuthorizationState
    private let authorizationRequestResult: Bool
    private var authorizationRequestCount = 0
    private var pending: Set<String>
    private var delivered: Set<String>
    private var added: [LocalNotificationDescriptor] = []
    private var removedPending: Set<String> = []
    private var removedDelivered: Set<String> = []

    init(
        authorization: NotificationAuthorizationState,
        authorizationRequestResult: Bool = false,
        pending: Set<String> = [],
        delivered: Set<String> = []
    ) {
        self.authorization = authorization
        self.authorizationRequestResult = authorizationRequestResult
        self.pending = pending
        self.delivered = delivered
    }

    func authorizationState() async -> NotificationAuthorizationState { authorization }
    func requestAlertAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if authorizationRequestResult { authorization = .allowed }
        return authorizationRequestResult
    }
    func registerCategories(language: AppLanguage) async {}
    func add(_ descriptor: LocalNotificationDescriptor) async throws {
        pending.insert(descriptor.identifier)
        added.append(descriptor)
    }
    func pendingIdentifiers() async -> Set<String> { pending }
    func deliveredIdentifiers() async -> Set<String> { delivered }
    func removePending(identifiers: Set<String>) async {
        pending.subtract(identifiers)
        removedPending.formUnion(identifiers)
    }
    func removeDelivered(identifiers: Set<String>) async {
        delivered.subtract(identifiers)
        removedDelivered.formUnion(identifiers)
    }
    func currentAuthorizationRequestCount() -> Int { authorizationRequestCount }
    func currentAdded() -> [LocalNotificationDescriptor] { added }
    func currentRemovedPending() -> Set<String> { removedPending }
}
