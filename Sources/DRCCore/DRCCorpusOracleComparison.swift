public struct DRCCorpusOracleComparison: Sendable, Hashable, Codable {
    public let primaryBackendID: String
    public let oracleBackendID: String
    public let passedMatched: Bool
    public let activeErrorRuleIDsMatched: Bool
    public let diagnosticSummaryMatched: Bool
    public let primaryPassed: Bool
    public let oraclePassed: Bool
    public let primaryActiveErrorRuleIDs: [String]
    public let oracleActiveErrorRuleIDs: [String]
    public let primaryDiagnosticSummary: DRCDiagnosticSummary
    public let oracleDiagnosticSummary: DRCDiagnosticSummary
    public let mismatchReasons: [String]

    public init(
        primaryBackendID: String,
        oracleBackendID: String,
        passedMatched: Bool,
        activeErrorRuleIDsMatched: Bool,
        diagnosticSummaryMatched: Bool,
        primaryPassed: Bool,
        oraclePassed: Bool,
        primaryActiveErrorRuleIDs: [String],
        oracleActiveErrorRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        oracleDiagnosticSummary: DRCDiagnosticSummary,
        mismatchReasons: [String]
    ) {
        self.primaryBackendID = primaryBackendID
        self.oracleBackendID = oracleBackendID
        self.passedMatched = passedMatched
        self.activeErrorRuleIDsMatched = activeErrorRuleIDsMatched
        self.diagnosticSummaryMatched = diagnosticSummaryMatched
        self.primaryPassed = primaryPassed
        self.oraclePassed = oraclePassed
        self.primaryActiveErrorRuleIDs = primaryActiveErrorRuleIDs
        self.oracleActiveErrorRuleIDs = oracleActiveErrorRuleIDs
        self.primaryDiagnosticSummary = primaryDiagnosticSummary
        self.oracleDiagnosticSummary = oracleDiagnosticSummary
        self.mismatchReasons = mismatchReasons
    }

    public var agreementPassed: Bool {
        passedMatched && activeErrorRuleIDsMatched
    }
}
