import Foundation
import XCTest
@testable import CueLens

final class ActivationCoordinatorTests: XCTestCase {
    private let tokenText = "123e4567-e89b-42d3-a456-426614174000"

    func testSuccessfulHandshakePersistsOnlyAfterConfirmationAndClearsRecoveryMarker() async throws {
        let service = ActivationServiceStub(token: try UUIDv4(tokenText))
        let tokenStore = ActivationTokenStoreStub()
        let recovery = ActivationRecoveryStoreStub()
        let coordinator = ActivationCoordinator(
            service: service,
            tokenStore: tokenStore,
            recoveryStore: recovery
        )
        let identifier = try ParticipantIdentifier.parse("  Person@Example.org  ")

        let requestOutcome = await coordinator.requestToken(identifier: identifier)
        let tokenBeforeConfirmation = await tokenStore.currentToken()
        let markerBeforeConfirmation = await recovery.currentMarker()
        XCTAssertEqual(requestOutcome, .readyToConfirm)
        XCTAssertNil(tokenBeforeConfirmation)
        XCTAssertFalse(markerBeforeConfirmation)

        let confirmationOutcome = await coordinator.confirmPendingToken()
        XCTAssertEqual(confirmationOutcome, .activated)

        let storedToken = await tokenStore.currentToken()
        let markerAfterConfirmation = await recovery.currentMarker()
        let recoveryOperations = await recovery.currentOperations()
        let requestedValues = await service.requestedValues()
        let confirmedValues = await service.confirmedValues()
        XCTAssertEqual(storedToken?.description, tokenText)
        XCTAssertFalse(markerAfterConfirmation)
        XCTAssertEqual(recoveryOperations, [.mark, .clear])
        XCTAssertEqual(requestedValues, ["Person@Example.org"])
        XCTAssertEqual(
            confirmedValues,
            [ActivationServiceStub.Confirmation(identifier: "Person@Example.org", token: tokenText)]
        )
    }

    func testSecondRequestAndConfirmationAreIgnoredWhileHandshakeIsPendingOrCompleted() async throws {
        let service = ActivationServiceStub(token: try UUIDv4(tokenText))
        let coordinator = ActivationCoordinator(
            service: service,
            tokenStore: ActivationTokenStoreStub(),
            recoveryStore: ActivationRecoveryStoreStub()
        )
        let identifier = try ParticipantIdentifier.parse("ABCDEFGHIJKLMNOPQRSTUVWX")

        let firstRequest = await coordinator.requestToken(identifier: identifier)
        let secondRequest = await coordinator.requestToken(identifier: identifier)
        let firstConfirmation = await coordinator.confirmPendingToken()
        let secondConfirmation = await coordinator.confirmPendingToken()
        let requestCount = await service.requestedValues().count
        let confirmationCount = await service.confirmedValues().count
        XCTAssertEqual(firstRequest, .readyToConfirm)
        XCTAssertEqual(secondRequest, .ignored)
        XCTAssertEqual(firstConfirmation, .activated)
        XCTAssertEqual(secondConfirmation, .ignored)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(confirmationCount, 1)
    }

    func testRequestFailureDoesNotCreateMarkerOrPersistToken() async throws {
        let service = ActivationServiceStub(
            token: try UUIDv4(tokenText),
            requestError: NetworkError.offline
        )
        let tokenStore = ActivationTokenStoreStub()
        let recovery = ActivationRecoveryStoreStub()
        let coordinator = ActivationCoordinator(
            service: service,
            tokenStore: tokenStore,
            recoveryStore: recovery
        )

        let result = await coordinator.requestToken(
            identifier: try ParticipantIdentifier.parse("person@example.org")
        )

        XCTAssertEqual(result, .failed)
        let storedToken = await tokenStore.currentToken()
        let operations = await recovery.currentOperations()
        XCTAssertNil(storedToken)
        XCTAssertEqual(operations, [])
    }

    func testConfirmationTimeoutRequiresSupportAndKeepsMarkerWithoutToken() async throws {
        let service = ActivationServiceStub(
            token: try UUIDv4(tokenText),
            confirmationError: NetworkError.timedOut
        )
        let tokenStore = ActivationTokenStoreStub()
        let recovery = ActivationRecoveryStoreStub()
        let coordinator = ActivationCoordinator(
            service: service,
            tokenStore: tokenStore,
            recoveryStore: recovery
        )
        _ = await coordinator.requestToken(
            identifier: try ParticipantIdentifier.parse("person@example.org")
        )

        let outcome = await coordinator.confirmPendingToken()
        let storedToken = await tokenStore.currentToken()
        let marker = await recovery.currentMarker()
        let operations = await recovery.currentOperations()
        let retry = await coordinator.requestToken(
            identifier: try ParticipantIdentifier.parse("person@example.org")
        )
        let requestCount = await service.requestedValues().count
        XCTAssertEqual(outcome, .supportRequired)
        XCTAssertNil(storedToken)
        XCTAssertTrue(marker)
        XCTAssertEqual(operations, [.mark])
        XCTAssertEqual(retry, .ignored)
        XCTAssertEqual(requestCount, 1)
    }

    func testDefiniteConfirmationFailureClearsMarkerAndAllowsFreshAttempt() async throws {
        let service = ActivationServiceStub(
            token: try UUIDv4(tokenText),
            confirmationError: NetworkError.httpStatus(400)
        )
        let recovery = ActivationRecoveryStoreStub()
        let coordinator = ActivationCoordinator(
            service: service,
            tokenStore: ActivationTokenStoreStub(),
            recoveryStore: recovery
        )
        let identifier = try ParticipantIdentifier.parse("person@example.org")
        _ = await coordinator.requestToken(identifier: identifier)

        let confirmation = await coordinator.confirmPendingToken()
        let marker = await recovery.currentMarker()
        let retry = await coordinator.requestToken(identifier: identifier)
        XCTAssertEqual(confirmation, .failed)
        XCTAssertFalse(marker)
        XCTAssertEqual(retry, .readyToConfirm)
    }

    func testMarkerOrTokenStorageFailureIsFailClosed() async throws {
        let identifier = try ParticipantIdentifier.parse("person@example.org")
        let markerFailure = ActivationRecoveryStoreStub(failMark: true)
        let serviceBeforeConfirmation = ActivationServiceStub(token: try UUIDv4(tokenText))
        let markerCoordinator = ActivationCoordinator(
            service: serviceBeforeConfirmation,
            tokenStore: ActivationTokenStoreStub(),
            recoveryStore: markerFailure
        )
        _ = await markerCoordinator.requestToken(identifier: identifier)
        let markerOutcome = await markerCoordinator.confirmPendingToken()
        let retryAfterMarkerFailure = await markerCoordinator.requestToken(identifier: identifier)
        let confirmationsBeforeMarker = await serviceBeforeConfirmation.confirmedValues()
        XCTAssertEqual(markerOutcome, .secureStorageFailure)
        XCTAssertEqual(retryAfterMarkerFailure, .ignored)
        XCTAssertEqual(confirmationsBeforeMarker, [])

        let tokenFailure = ActivationTokenStoreStub(failSave: true)
        let recovery = ActivationRecoveryStoreStub()
        let tokenCoordinator = ActivationCoordinator(
            service: ActivationServiceStub(token: try UUIDv4(tokenText)),
            tokenStore: tokenFailure,
            recoveryStore: recovery
        )
        _ = await tokenCoordinator.requestToken(identifier: identifier)
        let tokenOutcome = await tokenCoordinator.confirmPendingToken()
        let retryAfterTokenFailure = await tokenCoordinator.requestToken(identifier: identifier)
        let markerAfterTokenFailure = await recovery.currentMarker()
        XCTAssertEqual(tokenOutcome, .secureStorageFailure)
        XCTAssertEqual(retryAfterTokenFailure, .ignored)
        XCTAssertTrue(markerAfterTokenFailure)
    }
}

private actor ActivationServiceStub: ActivationServicing {
    struct Confirmation: Equatable, Sendable {
        let identifier: String
        let token: String
    }

    let token: UUIDv4
    let requestError: NetworkError?
    let confirmationError: NetworkError?
    private var requests: [String] = []
    private var confirmations: [Confirmation] = []

    init(
        token: UUIDv4,
        requestError: NetworkError? = nil,
        confirmationError: NetworkError? = nil
    ) {
        self.token = token
        self.requestError = requestError
        self.confirmationError = confirmationError
    }

    func requestToken(identifier: ParticipantIdentifier) async throws -> UUIDv4 {
        requests.append(identifier.value)
        if let requestError { throw requestError }
        return token
    }

    func confirmToken(identifier: ParticipantIdentifier, token: UUIDv4) async throws {
        confirmations.append(Confirmation(identifier: identifier.value, token: token.description))
        if let confirmationError { throw confirmationError }
    }

    func requestedValues() -> [String] { requests }
    func confirmedValues() -> [Confirmation] { confirmations }
}

private actor ActivationTokenStoreStub: AppTokenStore {
    private var token: UUIDv4?
    private let failSave: Bool

    init(failSave: Bool = false) {
        self.failSave = failSave
    }

    func readToken() async throws -> UUIDv4? { token }
    func saveToken(_ token: UUIDv4) async throws {
        if failSave { throw PersistenceError.tokenConflict }
        self.token = token
    }
    func clearToken() async throws { token = nil }
    func currentToken() -> UUIDv4? { token }
}

private actor ActivationRecoveryStoreStub: ActivationRecoveryStoring {
    enum Operation: Equatable, Sendable { case mark, clear }

    private var marker = false
    private var operations: [Operation] = []
    private let failMark: Bool
    private let failClear: Bool

    init(failMark: Bool = false, failClear: Bool = false) {
        self.failMark = failMark
        self.failClear = failClear
    }

    func isConfirmationUncertain() async throws -> Bool { marker }
    func markConfirmationUncertain() async throws {
        if failMark { throw PersistenceError.installationIntegrityFailure }
        marker = true
        operations.append(.mark)
    }
    func clearConfirmationUncertain() async throws {
        if failClear { throw PersistenceError.installationIntegrityFailure }
        marker = false
        operations.append(.clear)
    }
    func currentMarker() -> Bool { marker }
    func currentOperations() -> [Operation] { operations }
}
