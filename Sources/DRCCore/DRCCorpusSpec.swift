public struct DRCCorpusSpec: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let defaultMaxDurationSeconds: Double?
    public let evidenceKind: DRCCorpusEvidenceKind
    public let qualificationPolicy: DRCCorpusQualificationPolicy
    public let cases: [DRCCorpusCase]

    public init(
        schemaVersion: Int = 1,
        defaultMaxDurationSeconds: Double? = nil,
        evidenceKind: DRCCorpusEvidenceKind = .regression,
        qualificationPolicy: DRCCorpusQualificationPolicy = .strict,
        cases: [DRCCorpusCase]
    ) {
        self.schemaVersion = schemaVersion
        self.defaultMaxDurationSeconds = defaultMaxDurationSeconds
        self.evidenceKind = evidenceKind
        self.qualificationPolicy = qualificationPolicy
        self.cases = cases
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case defaultMaxDurationSeconds
        case evidenceKind
        case qualificationPolicy
        case cases
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        defaultMaxDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .defaultMaxDurationSeconds)
        evidenceKind = try container.decodeIfPresent(DRCCorpusEvidenceKind.self, forKey: .evidenceKind) ?? .regression
        qualificationPolicy = try container.decodeIfPresent(
            DRCCorpusQualificationPolicy.self,
            forKey: .qualificationPolicy
        ) ?? .strict
        cases = try container.decode([DRCCorpusCase].self, forKey: .cases)
    }

    public var effectiveQualificationPolicy: DRCCorpusQualificationPolicy {
        guard evidenceKind == .independentCorrelation, !qualificationPolicy.requireIndependentOracle else {
            return qualificationPolicy
        }
        return qualificationPolicy.with(requireIndependentOracle: true)
    }
}
