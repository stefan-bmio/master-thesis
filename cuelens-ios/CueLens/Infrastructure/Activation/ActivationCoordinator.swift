import Foundation

enum ActivationState: Equatable, Sendable {
    case idle
    case requestingToken
    case confirmingToken
    case activated
    case failed
    case supportRequired
}

enum ActivationTokenRequestOutcome: Equatable, Sendable {
    case readyToConfirm
    case failed
    case ignored
}

enum ActivationConfirmationOutcome: Equatable, Sendable {
    case activated
    case failed
    case supportRequired
    case secureStorageFailure
    case ignored
}

protocol ActivationManaging: Sendable {
    func requestToken(identifier: ParticipantIdentifier) async -> ActivationTokenRequestOutcome
    func confirmPendingToken() async -> ActivationConfirmationOutcome
}

actor ActivationCoordinator: ActivationManaging {
    private struct PendingActivation: Sendable {
        let identifier: ParticipantIdentifier
        let token: UUIDv4
    }

    private let service: any ActivationServicing
    private let tokenStore: any AppTokenStore
    private let recoveryStore: any ActivationRecoveryStoring
    private var pending: PendingActivation?
    private var requestRunning = false
    private var confirmationRunning = false
    private var activationBlocked = false

    init(
        service: any ActivationServicing,
        tokenStore: any AppTokenStore,
        recoveryStore: any ActivationRecoveryStoring
    ) {
        self.service = service
        self.tokenStore = tokenStore
        self.recoveryStore = recoveryStore
    }

    func requestToken(identifier: ParticipantIdentifier) async -> ActivationTokenRequestOutcome {
        guard !activationBlocked,
              !requestRunning,
              !confirmationRunning,
              pending == nil else { return .ignored }
        requestRunning = true
        defer { requestRunning = false }
        do {
            let token = try await service.requestToken(identifier: identifier)
            pending = PendingActivation(identifier: identifier, token: token)
            return .readyToConfirm
        } catch {
            pending = nil
            return .failed
        }
    }

    func confirmPendingToken() async -> ActivationConfirmationOutcome {
        guard !requestRunning, !confirmationRunning, let pending else { return .ignored }
        confirmationRunning = true
        defer {
            confirmationRunning = false
            self.pending = nil
        }

        do {
            try await recoveryStore.markConfirmationUncertain()
        } catch {
            activationBlocked = true
            return .secureStorageFailure
        }

        do {
            try await service.confirmToken(
                identifier: pending.identifier,
                token: pending.token
            )
        } catch NetworkError.timedOut {
            activationBlocked = true
            return .supportRequired
        } catch {
            do {
                try await recoveryStore.clearConfirmationUncertain()
                return .failed
            } catch {
                activationBlocked = true
                return .secureStorageFailure
            }
        }

        do {
            try await tokenStore.saveToken(pending.token)
        } catch {
            activationBlocked = true
            return .secureStorageFailure
        }

        try? await recoveryStore.clearConfirmationUncertain()
        return .activated
    }
}

struct DisabledActivationManager: ActivationManaging {
    func requestToken(identifier: ParticipantIdentifier) async -> ActivationTokenRequestOutcome {
        .failed
    }

    func confirmPendingToken() async -> ActivationConfirmationOutcome {
        .failed
    }
}
