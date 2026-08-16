import Foundation

struct UUIDv4: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    let value: UUID

    init(_ value: UUID) throws {
        guard Self.isVersion4(value) else {
            throw DomainValidationError.invalidUUIDv4
        }
        self.value = value
    }

    init(_ string: String) throws {
        guard let value = UUID(uuidString: string), Self.isVersion4(value) else {
            throw DomainValidationError.invalidUUIDv4
        }
        self.value = value
    }

    var description: String {
        value.uuidString.lowercased()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(string)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a UUID version 4."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static func isVersion4(_ value: UUID) -> Bool {
        let bytes = value.uuid
        let versionIsFour = bytes.6 >> 4 == 4
        let variantIsRFC4122 = bytes.8 & 0b1100_0000 == 0b1000_0000
        return versionIsFour && variantIsRFC4122
    }
}
