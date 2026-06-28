public struct DRCCorpusReport: Sendable, Hashable, Codable {
    public let schemaVersion: Int
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
        schemaVersion: Int = 1,
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
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        passed = try container.decode(Bool.self, forKey: .passed)
        caseCount = try container.decode(Int.self, forKey: .caseCount)
        matchedCaseCount = try container.decode(Int.self, forKey: .matchedCaseCount)
        budgetExceededCaseCount = try container.decodeIfPresent(Int.self, forKey: .budgetExceededCaseCount) ?? 0
        totalDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .totalDurationSeconds) ?? 0
        runOptions = try container.decodeIfPresent(DRCCorpusRunOptions.self, forKey: .runOptions)
            ?? DRCCorpusRunOptions()
        caseResults = try container.decode([DRCCorpusCaseResult].self, forKey: .caseResults)
        let resolvedSummary = try container.decodeIfPresent(DRCCorpusSummary.self, forKey: .summary)
            ?? DRCCorpusSummary(caseResults: caseResults)
        summary = resolvedSummary
        qualification = try container.decodeIfPresent(DRCCorpusQualificationResult.self, forKey: .qualification)
            ?? DRCCorpusQualificationPolicy.strict.evaluate(
                passed: passed,
                caseCount: caseCount,
                summary: resolvedSummary
            )
    }
}
