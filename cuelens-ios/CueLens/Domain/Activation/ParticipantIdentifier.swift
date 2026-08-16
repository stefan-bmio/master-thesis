import Foundation

enum ParticipantIdentifier: Equatable, Sendable {
    case directEmail(String)
    case prolificID(String)

    var value: String {
        switch self {
        case .directEmail(let value), .prolificID(let value):
            value
        }
    }

    static func parse(_ input: String) throws -> ParticipantIdentifier {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.range(of: #"^[A-Za-z0-9]{24}$"#, options: .regularExpression) != nil {
            return .prolificID(value)
        }
        if isValidEmail(value) {
            return .directEmail(value)
        }
        throw DomainValidationError.invalidParticipantIdentifier
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard value.utf8.count <= 254 else { return false }
        let components = value.split(separator: "@", omittingEmptySubsequences: false)
        guard components.count == 2 else { return false }

        let local = String(components[0])
        let domain = String(components[1])
        guard !local.isEmpty,
              local.utf8.count <= 64,
              local.first != ".",
              local.last != ".",
              !local.contains(".."),
              local.range(
                of: #"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$"#,
                options: .regularExpression
              ) != nil else {
            return false
        }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy { label in
            guard (1...63).contains(label.utf8.count),
                  let first = label.first,
                  let last = label.last,
                  first.isASCII,
                  last.isASCII,
                  first.isLetter || first.isNumber,
                  last.isLetter || last.isNumber else {
                return false
            }
            return label.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
            }
        }
    }
}
