import Foundation

struct InfoMessage: Equatable, Sendable {
    let id: Int64
    let createdAt: Date
    let textGerman: String
    let textEnglish: String
}

enum InfoMessageBatchDecoder {
    private static let rootKeys: Set<String> = ["messages"]
    private static let messageKeys: Set<String> = ["id", "created_at", "text_de", "text_en"]

    static func decode(_ data: Data) throws -> [InfoMessage] {
        do {
            let root = try StrictJSON.object(from: data)
            guard StrictJSON.hasExactlyKeys(root, rootKeys),
                  let values = root["messages"] as? [Any] else {
                throw DomainValidationError.invalidMessagePayload
            }

            var seenIDs = Set<Int64>()
            var messages: [InfoMessage] = []
            messages.reserveCapacity(values.count)

            for value in values {
                guard let object = value as? [String: Any],
                      StrictJSON.hasExactlyKeys(object, messageKeys),
                      let integerID = StrictJSON.integer(object["id"]),
                      let id = Int64(exactly: integerID),
                      id > 0,
                      seenIDs.insert(id).inserted,
                      let createdAtText = StrictJSON.string(object["created_at"]),
                      let createdAt = parseUTCDate(createdAtText),
                      let textGerman = StrictJSON.string(object["text_de"]),
                      let textEnglish = StrictJSON.string(object["text_en"]) else {
                    throw DomainValidationError.invalidMessagePayload
                }

                messages.append(
                    InfoMessage(
                        id: id,
                        createdAt: createdAt,
                        textGerman: textGerman,
                        textEnglish: textEnglish
                    )
                )
            }

            return messages.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id < $1.id
                }
                return $0.createdAt < $1.createdAt
            }
        } catch let error as DomainValidationError {
            throw error
        } catch {
            throw DomainValidationError.invalidMessagePayload
        }
    }

    private static func parseUTCDate(_ value: String) -> Date? {
        guard value.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.isLenient = false

        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            return nil
        }
        return date
    }
}
