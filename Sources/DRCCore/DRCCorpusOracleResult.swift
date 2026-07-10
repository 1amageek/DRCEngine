public struct DRCCorpusOracleResult: Sendable, Hashable, Codable {
    public let backendID: String
    public let passed: Bool
    public let activeErrorRuleIDs: [String]
    public let diagnosticSummary: DRCDiagnosticSummary
    public let durationSeconds: Double
    public let agreementPassed: Bool
    public let readinessStatus: DRCCorpusOracleReadinessStatus
    public let readinessDiagnostics: [String]
    public let failureReasons: [String]
    public let executionError: String?
    public let reportPath: String?
    public let manifestPath: String?
    public let provenance: DRCCorpusCaseProvenance?

    private enum CodingKeys: String, CodingKey {
        case backendID
        case passed
        case activeErrorRuleIDs
        case diagnosticSummary
        case durationSeconds
        case agreementPassed
        case readinessStatus
        case readinessDiagnostics
        case failureReasons
        case executionError
        case reportPath
        case manifestPath
        case provenance
    }

    public init(
        backendID: String,
        passed: Bool,
        activeErrorRuleIDs: [String],
        diagnosticSummary: DRCDiagnosticSummary,
        durationSeconds: Double,
        agreementPassed: Bool,
        readinessStatus: DRCCorpusOracleReadinessStatus = .ready,
        readinessDiagnostics: [String] = [],
        failureReasons: [String],
        executionError: String? = nil,
        reportPath: String?,
        manifestPath: String?,
        provenance: DRCCorpusCaseProvenance? = nil
    ) {
        self.backendID = backendID
        self.passed = passed
        self.activeErrorRuleIDs = activeErrorRuleIDs
        self.diagnosticSummary = diagnosticSummary
        self.durationSeconds = durationSeconds
        self.agreementPassed = agreementPassed
        self.readinessStatus = readinessStatus
        self.readinessDiagnostics = readinessDiagnostics
        self.failureReasons = failureReasons
        self.executionError = executionError
        self.reportPath = reportPath
        self.manifestPath = manifestPath
        self.provenance = provenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backendID = try container.decode(String.self, forKey: .backendID)
        passed = try container.decode(Bool.self, forKey: .passed)
        activeErrorRuleIDs = try container.decode([String].self, forKey: .activeErrorRuleIDs)
        diagnosticSummary = try container.decode(DRCDiagnosticSummary.self, forKey: .diagnosticSummary)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        agreementPassed = try container.decode(Bool.self, forKey: .agreementPassed)
        failureReasons = try container.decode([String].self, forKey: .failureReasons)
        executionError = try container.decodeIfPresent(String.self, forKey: .executionError)
        reportPath = try container.decodeIfPresent(String.self, forKey: .reportPath)
        manifestPath = try container.decodeIfPresent(String.self, forKey: .manifestPath)
        provenance = try container.decodeIfPresent(DRCCorpusCaseProvenance.self, forKey: .provenance)
        readinessStatus = try container.decode(DRCCorpusOracleReadinessStatus.self, forKey: .readinessStatus)
        readinessDiagnostics = try container.decode([String].self, forKey: .readinessDiagnostics)
    }
}
