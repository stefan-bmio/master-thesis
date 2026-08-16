import Foundation

enum SelfReportResponse: Equatable, Sendable {
    case next(situation: SituationNumber)
    case directComplete(compensationCode: UUIDv4)
    case prolificComplete
}

enum SelfReportResponseDecoder {
    private static let commonKeys: Set<String> = [
        "success", "situation_index", "condition_code"
    ]
    private static let directCompletionKeys = commonKeys.union([
        "status", "compensation_code"
    ])
    private static let prolificCompletionKeys = commonKeys.union([
        "status", "completion_mode"
    ])

    static func decode(
        _ data: Data,
        expectedSituation: SituationNumber
    ) throws -> SelfReportResponse {
        do {
            let object = try StrictJSON.object(from: data)
            guard StrictJSON.boolean(object["success"]) == true,
                  let rawSituation = StrictJSON.integer(object["situation_index"]),
                  let situation = try? SituationNumber(rawSituation),
                  situation == expectedSituation,
                  let conditionCode = StrictJSON.string(object["condition_code"]),
                  conditionCode == situation.condition.rawValue else {
                throw DomainValidationError.invalidSelfReportResponse
            }

            if StrictJSON.hasExactlyKeys(object, commonKeys) {
                guard situation.value < StudySchedule.totalSituationCount else {
                    throw DomainValidationError.invalidSelfReportResponse
                }
                return .next(situation: situation)
            }

            guard situation.value == StudySchedule.totalSituationCount,
                  StrictJSON.string(object["status"]) == "complete" else {
                throw DomainValidationError.invalidSelfReportResponse
            }

            if StrictJSON.hasExactlyKeys(object, directCompletionKeys),
               let rawCode = StrictJSON.string(object["compensation_code"]),
               let code = try? UUIDv4(rawCode) {
                return .directComplete(compensationCode: code)
            }

            if StrictJSON.hasExactlyKeys(object, prolificCompletionKeys),
               StrictJSON.string(object["completion_mode"]) == "PROLIFIC_MANUAL" {
                return .prolificComplete
            }

            throw DomainValidationError.invalidSelfReportResponse
        } catch let error as DomainValidationError {
            if error == .invalidSelfReportResponse {
                throw error
            }
            throw DomainValidationError.invalidSelfReportResponse
        } catch {
            throw DomainValidationError.invalidSelfReportResponse
        }
    }
}
