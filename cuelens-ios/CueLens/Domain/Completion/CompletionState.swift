import Foundation

enum CompletionState: Codable, Equatable, Sendable {
    case incomplete
    case invalid
    case directPendingConfirmation(code: UUIDv4)
    case directCompleted(code: UUIDv4)
    case prolificCompleted

    var isCompleted: Bool {
        switch self {
        case .directCompleted, .prolificCompleted:
            true
        case .incomplete, .invalid, .directPendingConfirmation:
            false
        }
    }

    private enum CodingKeys: String, CodingKey, Hashable {
        case kind
        case code
    }

    private enum Kind: String, Codable {
        case incomplete
        case invalid
        case directPendingConfirmation = "direct_pending_confirmation"
        case directCompleted = "direct_completed"
        case prolificCompleted = "prolific_completed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let actualKeys = Set(container.allKeys)
        switch kind {
        case .incomplete:
            guard actualKeys == [.kind] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Incomplete completion state contains unexpected values."
                )
            }
            self = .incomplete
        case .invalid:
            guard actualKeys == [.kind] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Invalid completion state contains unexpected values."
                )
            }
            self = .invalid
        case .directPendingConfirmation:
            guard actualKeys == [.kind, .code] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Pending direct completion requires exactly one code."
                )
            }
            self = .directPendingConfirmation(
                code: try container.decode(UUIDv4.self, forKey: .code)
            )
        case .directCompleted:
            guard actualKeys == [.kind, .code] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Direct completion requires exactly one code."
                )
            }
            self = .directCompleted(
                code: try container.decode(UUIDv4.self, forKey: .code)
            )
        case .prolificCompleted:
            guard actualKeys == [.kind] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Prolific completion cannot contain a code."
                )
            }
            self = .prolificCompleted
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .incomplete:
            try container.encode(Kind.incomplete, forKey: .kind)
        case .invalid:
            try container.encode(Kind.invalid, forKey: .kind)
        case .directPendingConfirmation(let code):
            try container.encode(Kind.directPendingConfirmation, forKey: .kind)
            try container.encode(code, forKey: .code)
        case .directCompleted(let code):
            try container.encode(Kind.directCompleted, forKey: .kind)
            try container.encode(code, forKey: .code)
        case .prolificCompleted:
            try container.encode(Kind.prolificCompleted, forKey: .kind)
        }
    }
}
