import Foundation

enum StudyCondition: String, Codable, Equatable, Sendable {
    case cueMatching = "CUE_MATCHING"
    case cueLabeling = "CUE_LABELING"
}

struct SituationNumber: Codable, Comparable, Equatable, Hashable, Sendable {
    static let validRange = 1...20

    let value: Int

    init(_ value: Int) throws {
        guard Self.validRange.contains(value) else {
            throw DomainValidationError.invalidSituation
        }
        self.value = value
    }

    var condition: StudyCondition {
        value <= 10 ? .cueMatching : .cueLabeling
    }

    static func < (lhs: SituationNumber, rhs: SituationNumber) -> Bool {
        lhs.value < rhs.value
    }
}

struct CravingValue: Codable, Equatable, Hashable, Sendable {
    static let validRange = 0...100

    let value: Int

    init(_ value: Int) throws {
        guard Self.validRange.contains(value) else {
            throw DomainValidationError.invalidCraving
        }
        self.value = value
    }
}
