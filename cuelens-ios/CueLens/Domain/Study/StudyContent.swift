struct LabelPair: Equatable, Sendable {
    let fitting: String
    let lessFitting: String
}

struct MatchingItem: Equatable, Sendable {
    let index: Int
    let cueAssetName: String
    let matchAAssetName: String
    let matchBAssetName: String
}

struct LabelingItem: Equatable, Sendable {
    let index: Int
    let cueAssetName: String
    let german: LabelPair
    let english: LabelPair

    func labels(for language: AppLanguage) -> LabelPair {
        language == .german ? german : english
    }
}

struct StudyContent: Equatable, Sendable {
    static let itemCount = 50

    let matchingItems: [MatchingItem]
    let labelingItems: [LabelingItem]

    init(matchingItems: [MatchingItem], labelingItems: [LabelingItem]) throws {
        let expectedIndices = Array(0..<Self.itemCount)
        guard matchingItems.map(\.index) == expectedIndices,
              labelingItems.map(\.index) == expectedIndices,
              matchingItems.allSatisfy({
                  !$0.cueAssetName.isEmpty
                      && !$0.matchAAssetName.isEmpty
                      && !$0.matchBAssetName.isEmpty
              }),
              labelingItems.allSatisfy({
                  !$0.cueAssetName.isEmpty
                      && !$0.german.fitting.isEmpty
                      && !$0.german.lessFitting.isEmpty
                      && !$0.english.fitting.isEmpty
                      && !$0.english.lessFitting.isEmpty
              }) else {
            throw DomainValidationError.invalidStudyContent
        }
        self.matchingItems = matchingItems
        self.labelingItems = labelingItems
    }
}
