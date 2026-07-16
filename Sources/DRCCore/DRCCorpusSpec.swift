public struct DRCCorpusSpec: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let defaultMaxDurationSeconds: Double?
    public let evidenceKind: DRCCorpusEvidenceKind
    public let acceptanceCriteria: DRCCorpusAcceptanceCriteria
    public let cases: [DRCCorpusCase]

    public init(
        schemaVersion: Int = 1,
        defaultMaxDurationSeconds: Double? = nil,
        evidenceKind: DRCCorpusEvidenceKind = .regression,
        acceptanceCriteria: DRCCorpusAcceptanceCriteria = .strict,
        cases: [DRCCorpusCase]
    ) {
        self.schemaVersion = schemaVersion
        self.defaultMaxDurationSeconds = defaultMaxDurationSeconds
        self.evidenceKind = evidenceKind
        self.acceptanceCriteria = acceptanceCriteria
        self.cases = cases
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case defaultMaxDurationSeconds
        case evidenceKind
        case acceptanceCriteria
        case cases
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        defaultMaxDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .defaultMaxDurationSeconds)
        evidenceKind = try container.decodeIfPresent(DRCCorpusEvidenceKind.self, forKey: .evidenceKind) ?? .regression
        acceptanceCriteria = try container.decodeIfPresent(
            DRCCorpusAcceptanceCriteria.self,
            forKey: .acceptanceCriteria
        ) ?? .strict
        cases = try container.decode([DRCCorpusCase].self, forKey: .cases)
    }

    public var effectiveAcceptanceCriteria: DRCCorpusAcceptanceCriteria {
        guard evidenceKind == .independentCorrelation, !acceptanceCriteria.requireIndependentOracle else {
            return acceptanceCriteria
        }
        return acceptanceCriteria.with(requireIndependentOracle: true)
    }
}
