import Foundation

enum JSONContract {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(value)
        } catch {
            throw NetworkError.protocolViolation
        }
    }

    static func object(from data: Data) throws -> [String: Any] {
        do {
            guard !data.isEmpty,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NetworkError.malformedJSON
            }
            return object
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.malformedJSON
        }
    }

    static func validateAppVersion(_ value: String) throws {
        guard value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$"#,
            options: .regularExpression
        ) != nil else {
            throw NetworkError.protocolViolation
        }
    }
}
