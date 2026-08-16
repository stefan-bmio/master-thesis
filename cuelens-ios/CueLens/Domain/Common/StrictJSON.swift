import Foundation

enum StrictJSON {
    static func object(from data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data, options: [])
        guard let object = value as? [String: Any] else {
            throw DomainValidationError.invalidMessagePayload
        }
        return object
    }

    static func hasExactlyKeys(_ object: [String: Any], _ keys: Set<String>) -> Bool {
        Set(object.keys) == keys
    }

    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        let type = String(cString: number.objCType)
        guard !["c", "f", "d"].contains(type) else { return nil }

        let int64 = number.int64Value
        guard int64 >= Int64(Int.min), int64 <= Int64(Int.max) else { return nil }
        return Int(int64)
    }

    static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber else { return nil }
        guard String(cString: number.objCType) == "c" else { return nil }
        return number.boolValue
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }
}
