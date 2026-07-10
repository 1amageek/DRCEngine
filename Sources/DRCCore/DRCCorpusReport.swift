public struct DRCCorpusReport: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: String?
    public let passed: Bool
    public let caseCount: Int
    public let matchedCaseCount: Int
    public let budgetExceededCaseCount: Int
    public let totalDurationSeconds: Double
    public let runOptions: DRCCorpusRunOptions
    public let summary: DRCCorpusSummary
    public let qualification: DRCCorpusQualificationResult
    public let caseResults: [DRCCorpusCaseResult]

    public init(
        schemaVersion: Int = DRCCorpusReport.currentSchemaVersion,
        generatedAt: String? = nil,
        passed: Bool,
        caseCount: Int,
        matchedCaseCount: Int,
        budgetExceededCaseCount: Int = 0,
        totalDurationSeconds: Double = 0,
        runOptions: DRCCorpusRunOptions = DRCCorpusRunOptions(),
        summary: DRCCorpusSummary? = nil,
        qualificationPolicy: DRCCorpusQualificationPolicy = .strict,
        qualification: DRCCorpusQualificationResult? = nil,
        caseResults: [DRCCorpusCaseResult]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.passed = passed
        self.caseCount = caseCount
        self.matchedCaseCount = matchedCaseCount
        self.budgetExceededCaseCount = budgetExceededCaseCount
        self.totalDurationSeconds = totalDurationSeconds
        self.runOptions = runOptions
        let resolvedSummary = summary ?? DRCCorpusSummary(caseResults: caseResults)
        self.summary = resolvedSummary
        self.qualification = qualification ?? qualificationPolicy.evaluate(
            passed: passed,
            caseCount: caseCount,
            summary: resolvedSummary
        )
        self.caseResults = caseResults
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case generatedAt
        case passed
        case caseCount
        case matchedCaseCount
        case budgetExceededCaseCount
        case totalDurationSeconds
        case runOptions
        case summary
        case qualification
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
        passed = try container.decode(Bool.self, forKey: .passed)
        caseCount = try container.decode(Int.self, forKey: .caseCount)
        matchedCaseCount = try container.decode(Int.self, forKey: .matchedCaseCount)
        budgetExceededCaseCount = try container.decode(Int.self, forKey: .budgetExceededCaseCount)
        totalDurationSeconds = try container.decode(Double.self, forKey: .totalDurationSeconds)
        runOptions = try container.decode(DRCCorpusRunOptions.self, forKey: .runOptions)
        caseResults = try container.decode([DRCCorpusCaseResult].self, forKey: .caseResults)
        summary = try container.decode(DRCCorpusSummary.self, forKey: .summary)
        qualification = try container.decode(DRCCorpusQualificationResult.self, forKey: .qualification)
    }
}
