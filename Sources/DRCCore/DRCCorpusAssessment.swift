public struct DRCCorpusAssessment: Sendable, Hashable, Codable {
    public let criteria: DRCCorpusAcceptanceCriteria
    public let findings: [DRCCorpusAssessmentFinding]

    public var meetsCriteria: Bool { findings.isEmpty }

    public init(
        criteria: DRCCorpusAcceptanceCriteria,
        findings: [DRCCorpusAssessmentFinding]
    ) {
        self.criteria = criteria
        self.findings = findings
    }

    private enum CodingKeys: String, CodingKey {
        case criteria
        case findings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        criteria = try container.decode(DRCCorpusAcceptanceCriteria.self, forKey: .criteria)
        findings = try container.decode([DRCCorpusAssessmentFinding].self, forKey: .findings)
    }
}
