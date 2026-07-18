import Foundation

public struct DRCCorpusCase: Sendable, Hashable, Codable {
    public let caseID: String
    public let layoutPath: String
    public let topCell: String
    public let layoutFormat: DRCLayoutFormat?
    public let technologyPath: String?
    public let generatedLayoutFixture: DRCGeneratedLayoutFixture?
    public let waiverPath: String?
    public let backendID: String?
    public let oracleBackendID: String?
    public let additionalEnvironment: [String: String]
    public let designRevision: String?
    public let canonicalStateDigest: String?
    public let expectedPassed: Bool
    public let expectedActiveErrorRuleIDs: [String]
    public let expectedOracleActiveErrorRuleIDs: [String]?
    public let coverageTags: [String]
    public let maxDurationSeconds: Double?

    public init(
        caseID: String,
        layoutPath: String,
        topCell: String,
        layoutFormat: DRCLayoutFormat? = nil,
        technologyPath: String? = nil,
        generatedLayoutFixture: DRCGeneratedLayoutFixture? = nil,
        waiverPath: String? = nil,
        backendID: String? = nil,
        oracleBackendID: String? = nil,
        additionalEnvironment: [String: String] = [:],
        designRevision: String? = nil,
        canonicalStateDigest: String? = nil,
        expectedPassed: Bool,
        expectedActiveErrorRuleIDs: [String] = [],
        expectedOracleActiveErrorRuleIDs: [String]? = nil,
        coverageTags: [String] = [],
        maxDurationSeconds: Double? = nil
    ) {
        self.caseID = caseID
        self.layoutPath = layoutPath
        self.topCell = topCell
        self.layoutFormat = layoutFormat
        self.technologyPath = technologyPath
        self.generatedLayoutFixture = generatedLayoutFixture
        self.waiverPath = waiverPath
        self.backendID = backendID
        self.oracleBackendID = oracleBackendID
        self.additionalEnvironment = additionalEnvironment
        self.designRevision = designRevision
        self.canonicalStateDigest = canonicalStateDigest
        self.expectedPassed = expectedPassed
        self.expectedActiveErrorRuleIDs = expectedActiveErrorRuleIDs
        self.expectedOracleActiveErrorRuleIDs = expectedOracleActiveErrorRuleIDs?.sorted()
        self.coverageTags = Self.normalizedCoverageTags(coverageTags)
        self.maxDurationSeconds = maxDurationSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case caseID
        case layoutPath
        case topCell
        case layoutFormat
        case technologyPath
        case generatedLayoutFixture
        case waiverPath
        case backendID
        case oracleBackendID
        case additionalEnvironment
        case designRevision
        case canonicalStateDigest
        case expectedPassed
        case expectedActiveErrorRuleIDs
        case expectedOracleActiveErrorRuleIDs
        case coverageTags
        case maxDurationSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caseID = try container.decode(String.self, forKey: .caseID)
        layoutPath = try container.decode(String.self, forKey: .layoutPath)
        topCell = try container.decode(String.self, forKey: .topCell)
        layoutFormat = try container.decodeIfPresent(DRCLayoutFormat.self, forKey: .layoutFormat)
        technologyPath = try container.decodeIfPresent(String.self, forKey: .technologyPath)
        generatedLayoutFixture = try container.decodeIfPresent(
            DRCGeneratedLayoutFixture.self,
            forKey: .generatedLayoutFixture
        )
        waiverPath = try container.decodeIfPresent(String.self, forKey: .waiverPath)
        backendID = try container.decodeIfPresent(String.self, forKey: .backendID)
        oracleBackendID = try container.decodeIfPresent(String.self, forKey: .oracleBackendID)
        additionalEnvironment = try container.decodeIfPresent(
            [String: String].self,
            forKey: .additionalEnvironment
        ) ?? [:]
        designRevision = try container.decodeIfPresent(String.self, forKey: .designRevision)
        canonicalStateDigest = try container.decodeIfPresent(String.self, forKey: .canonicalStateDigest)
        expectedPassed = try container.decode(Bool.self, forKey: .expectedPassed)
        expectedActiveErrorRuleIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .expectedActiveErrorRuleIDs
        ) ?? []
        expectedOracleActiveErrorRuleIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .expectedOracleActiveErrorRuleIDs
        )?.sorted()
        coverageTags = Self.normalizedCoverageTags(try container.decodeIfPresent(
            [String].self,
            forKey: .coverageTags
        ) ?? [])
        maxDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .maxDurationSeconds)
    }

    private static func normalizedCoverageTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}

public struct DRCGeneratedLayoutFixture: Sendable, Hashable, Codable {
    public let kind: String
    public let technology: String
    public let technologyPath: String?
    public let format: DRCLayoutFormat

    public init(
        kind: String,
        technology: String = "sampleProcess",
        technologyPath: String? = nil,
        format: DRCLayoutFormat = .gds
    ) {
        self.kind = kind
        self.technology = technology
        self.technologyPath = technologyPath
        self.format = format
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case technology
        case technologyPath
        case format
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        technology = try container.decodeIfPresent(String.self, forKey: .technology) ?? "sampleProcess"
        technologyPath = try container.decodeIfPresent(String.self, forKey: .technologyPath)
        format = try container.decodeIfPresent(DRCLayoutFormat.self, forKey: .format) ?? .gds
    }
}
