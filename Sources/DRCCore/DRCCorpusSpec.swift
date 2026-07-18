public struct DRCCorpusSpec: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let defaultMaxDurationSeconds: Double?
    public let evidenceKind: DRCCorpusEvidenceKind
    public let acceptanceCriteria: DRCCorpusAcceptanceCriteria
    public let cases: [DRCCorpusCase]

    public init(
        defaultMaxDurationSeconds: Double? = nil,
        evidenceKind: DRCCorpusEvidenceKind = .regression,
        acceptanceCriteria: DRCCorpusAcceptanceCriteria = .strict,
        cases: [DRCCorpusCase]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
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
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported DRC corpus spec schema version: \(schemaVersion)."
            )
        }
        defaultMaxDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .defaultMaxDurationSeconds)
        evidenceKind = try container.decode(DRCCorpusEvidenceKind.self, forKey: .evidenceKind)
        acceptanceCriteria = try container.decode(
            DRCCorpusAcceptanceCriteria.self,
            forKey: .acceptanceCriteria
        )
        cases = try container.decode([DRCCorpusCase].self, forKey: .cases)
    }

    public var effectiveAcceptanceCriteria: DRCCorpusAcceptanceCriteria {
        guard evidenceKind.requiresIndependentOracle, !acceptanceCriteria.requireIndependentOracle else {
            return acceptanceCriteria
        }
        return acceptanceCriteria.with(requireIndependentOracle: true)
    }
}
