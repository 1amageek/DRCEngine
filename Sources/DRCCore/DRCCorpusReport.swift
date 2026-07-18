public struct DRCCorpusReport: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let generatedAt: String?
    public let runID: String?
    public let parentRunID: String?
    public let specSHA256: String?
    public let completed: Bool
    public let passed: Bool
    public let caseCount: Int
    public let matchedCaseCount: Int
    public let budgetExceededCaseCount: Int
    public let totalDurationSeconds: Double
    public let evidenceKind: DRCCorpusEvidenceKind
    public let runOptions: DRCCorpusRunOptions
    public let summary: DRCCorpusSummary
    public let assessment: DRCCorpusAssessment
    public let caseResults: [DRCCorpusCaseResult]

    public init(
        schemaVersion: Int = DRCCorpusReport.currentSchemaVersion,
        generatedAt: String? = nil,
        runID: String? = nil,
        parentRunID: String? = nil,
        specSHA256: String? = nil,
        completed: Bool = true,
        passed: Bool,
        caseCount: Int,
        matchedCaseCount: Int,
        budgetExceededCaseCount: Int = 0,
        totalDurationSeconds: Double = 0,
        evidenceKind: DRCCorpusEvidenceKind = .regression,
        runOptions: DRCCorpusRunOptions = DRCCorpusRunOptions(),
        summary: DRCCorpusSummary? = nil,
        acceptanceCriteria: DRCCorpusAcceptanceCriteria = .strict,
        assessment: DRCCorpusAssessment? = nil,
        caseResults: [DRCCorpusCaseResult]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.runID = runID
        self.parentRunID = parentRunID
        self.specSHA256 = specSHA256
        self.completed = completed
        self.passed = passed
        self.caseCount = caseCount
        self.matchedCaseCount = matchedCaseCount
        self.budgetExceededCaseCount = budgetExceededCaseCount
        self.totalDurationSeconds = totalDurationSeconds
        self.evidenceKind = evidenceKind
        self.runOptions = runOptions
        let resolvedSummary = summary ?? DRCCorpusSummary(caseResults: caseResults)
        self.summary = resolvedSummary
        let resolvedAcceptanceCriteria = evidenceKind.requiresIndependentOracle
            ? acceptanceCriteria.with(requireIndependentOracle: true)
            : acceptanceCriteria
        self.assessment = assessment ?? resolvedAcceptanceCriteria.evaluate(
            passed: passed,
            caseCount: caseCount,
            summary: resolvedSummary,
            completed: completed
        )
        self.caseResults = caseResults
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case generatedAt
        case runID
        case parentRunID
        case specSHA256
        case completed
        case passed
        case caseCount
        case matchedCaseCount
        case budgetExceededCaseCount
        case totalDurationSeconds
        case evidenceKind
        case runOptions
        case summary
        case assessment
        case caseResults
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported DRC corpus report schema version: \(schemaVersion)."
            )
        }
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        runID = try container.decodeIfPresent(String.self, forKey: .runID)
        parentRunID = try container.decodeIfPresent(String.self, forKey: .parentRunID)
        specSHA256 = try container.decodeIfPresent(String.self, forKey: .specSHA256)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true
        passed = try container.decode(Bool.self, forKey: .passed)
        caseCount = try container.decode(Int.self, forKey: .caseCount)
        matchedCaseCount = try container.decode(Int.self, forKey: .matchedCaseCount)
        budgetExceededCaseCount = try container.decode(Int.self, forKey: .budgetExceededCaseCount)
        totalDurationSeconds = try container.decode(Double.self, forKey: .totalDurationSeconds)
        evidenceKind = try container.decodeIfPresent(DRCCorpusEvidenceKind.self, forKey: .evidenceKind) ?? .regression
        runOptions = try container.decode(DRCCorpusRunOptions.self, forKey: .runOptions)
        caseResults = try container.decode([DRCCorpusCaseResult].self, forKey: .caseResults)
        summary = try container.decode(DRCCorpusSummary.self, forKey: .summary)
        assessment = try container.decode(DRCCorpusAssessment.self, forKey: .assessment)
    }
}
