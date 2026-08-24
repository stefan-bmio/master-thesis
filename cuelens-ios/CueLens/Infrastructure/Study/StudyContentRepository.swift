import Foundation
import UIKit

enum StudyContentRepositoryError: Error, Equatable, Sendable {
    case missingResource
    case invalidContent
    case invalidManifest
    case invalidImage
}

protocol StudyContentServing: Sendable {
    func load() async throws -> StudyContent
}

enum StudyImageResource {
    static let bundleSubdirectory = "Assets"

    static func url(named name: String, bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: bundleSubdirectory
        ) ?? bundle.url(forResource: name, withExtension: "png")
    }

    static func load(named name: String, bundle: Bundle = .main) -> UIImage? {
        guard let url = url(named: name, bundle: bundle) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

actor BundleStudyContentRepository: StudyContentServing {
    private let bundle: Bundle
    private var cachedContent: StudyContent?
    private var failed = false

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() throws -> StudyContent {
        if let cachedContent { return cachedContent }
        guard !failed else { throw StudyContentRepositoryError.invalidContent }
        do {
            let content = try Self.decodeAndValidate(bundle: bundle)
            cachedContent = content
            return content
        } catch {
            failed = true
            throw error
        }
    }

    private static func decodeAndValidate(bundle: Bundle) throws -> StudyContent {
        guard let contentURL = bundle.url(
            forResource: "study-content-v1",
            withExtension: "json"
        ), let manifestURL = bundle.url(
            forResource: "study-assets-manifest-v1",
            withExtension: "json"
        ) else {
            throw StudyContentRepositoryError.missingResource
        }
        let contentData = try Data(contentsOf: contentURL, options: .mappedIfSafe)
        let manifestData = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        try validateContentShape(contentData)
        try validateManifestShape(manifestData)

        let decoder = JSONDecoder()
        let contentDTO = try decoder.decode(StudyContentDTO.self, from: contentData)
        let manifestDTO = try decoder.decode(StudyAssetManifestDTO.self, from: manifestData)
        guard contentDTO.version == 1 else {
            throw StudyContentRepositoryError.invalidContent
        }
        guard manifestDTO.version == 1,
              manifestDTO.hashAlgorithm == "sha256" else {
            throw StudyContentRepositoryError.invalidManifest
        }

        let expectedIDs = Set(
            (0..<StudyContent.itemCount).flatMap { index in
                let suffix = String(format: "%03d", index)
                return ["cue_\(suffix)", "match_a_\(suffix)", "match_b_\(suffix)"]
            }
        )
        guard manifestDTO.assets.count == expectedIDs.count,
              Set(manifestDTO.assets.map(\.id)) == expectedIDs,
              Set(manifestDTO.assets.map(\.filename)).count == expectedIDs.count else {
            throw StudyContentRepositoryError.invalidManifest
        }
        for asset in manifestDTO.assets {
            guard asset.filename == "\(asset.id).png",
                  asset.pixelWidth == 512,
                  asset.pixelHeight == 512,
                  asset.sha256.range(
                    of: "^[a-f0-9]{64}$",
                    options: .regularExpression
                  ) != nil,
                  let image = StudyImageResource.load(named: asset.id, bundle: bundle),
                  image.size == CGSize(width: 512, height: 512) else {
                throw StudyContentRepositoryError.invalidImage
            }
        }

        do {
            return try StudyContent(
                matchingItems: contentDTO.matching.map {
                    MatchingItem(
                        index: $0.index,
                        cueAssetName: $0.cue,
                        matchAAssetName: $0.matchA,
                        matchBAssetName: $0.matchB
                    )
                },
                labelingItems: contentDTO.labeling.map {
                    LabelingItem(
                        index: $0.index,
                        cueAssetName: $0.cue,
                        german: LabelPair(
                            fitting: $0.german.fitting,
                            lessFitting: $0.german.lessFitting
                        ),
                        english: LabelPair(
                            fitting: $0.english.fitting,
                            lessFitting: $0.english.lessFitting
                        )
                    )
                }
            )
        } catch {
            throw StudyContentRepositoryError.invalidContent
        }
    }

    private static func validateContentShape(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["version", "demo", "matching", "labeling"],
              let demo = root["demo"] as? [String: Any],
              Set(demo.keys) == ["matching_index", "labeling_index"],
              demo["matching_index"] as? Int == 0,
              demo["labeling_index"] as? Int == 1,
              let matching = root["matching"] as? [[String: Any]],
              let labeling = root["labeling"] as? [[String: Any]],
              matching.allSatisfy({ Set($0.keys) == ["index", "cue", "match_a", "match_b"] }),
              labeling.allSatisfy({ item in
                  guard Set(item.keys) == ["index", "cue", "de", "en"],
                        let german = item["de"] as? [String: Any],
                        let english = item["en"] as? [String: Any] else { return false }
                  return Set(german.keys) == ["fitting", "less_fitting"]
                      && Set(english.keys) == ["fitting", "less_fitting"]
              }) else {
            throw StudyContentRepositoryError.invalidContent
        }
    }

    private static func validateManifestShape(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["version", "hash_algorithm", "assets"],
              let assets = root["assets"] as? [[String: Any]],
              assets.allSatisfy({
                  Set($0.keys) == ["id", "filename", "sha256", "pixel_width", "pixel_height"]
              }) else {
            throw StudyContentRepositoryError.invalidManifest
        }
    }
}

private struct StudyContentDTO: Decodable {
    let version: Int
    let matching: [MatchingDTO]
    let labeling: [LabelingDTO]
}

private struct MatchingDTO: Decodable {
    let index: Int
    let cue: String
    let matchA: String
    let matchB: String

    private enum CodingKeys: String, CodingKey {
        case index, cue
        case matchA = "match_a"
        case matchB = "match_b"
    }
}

private struct LabelingDTO: Decodable {
    let index: Int
    let cue: String
    let german: LabelPairDTO
    let english: LabelPairDTO

    private enum CodingKeys: String, CodingKey {
        case index, cue
        case german = "de"
        case english = "en"
    }
}

private struct LabelPairDTO: Decodable {
    let fitting: String
    let lessFitting: String

    private enum CodingKeys: String, CodingKey {
        case fitting
        case lessFitting = "less_fitting"
    }
}

private struct StudyAssetManifestDTO: Decodable {
    let version: Int
    let hashAlgorithm: String
    let assets: [StudyAssetDTO]

    private enum CodingKeys: String, CodingKey {
        case version, assets
        case hashAlgorithm = "hash_algorithm"
    }
}

private struct StudyAssetDTO: Decodable {
    let id: String
    let filename: String
    let sha256: String
    let pixelWidth: Int
    let pixelHeight: Int

    private enum CodingKeys: String, CodingKey {
        case id, filename, sha256
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
    }
}
