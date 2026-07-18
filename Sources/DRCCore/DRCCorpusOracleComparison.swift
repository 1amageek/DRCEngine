public struct DRCCorpusOracleComparison: Sendable, Hashable, Codable {
    public let primaryBackendID: String
    public let oracleBackendID: String
    public let passedMatched: Bool
    public let activeErrorRuleIDsMatched: Bool
    public let ruleAssertionsMatched: Bool
    public let diagnosticSummaryMatched: Bool
    public let primaryPassed: Bool
    public let oraclePassed: Bool
    public let primaryActiveErrorRuleIDs: [String]
    public let oracleActiveErrorRuleIDs: [String]
    public let primaryDiagnosticSummary: DRCDiagnosticSummary
    public let oracleDiagnosticSummary: DRCDiagnosticSummary
    public let mismatchReasons: [String]
    public let agreementPassed: Bool
    public let primaryMarkerFingerprints: [String]
    public let oracleMarkerFingerprints: [String]
    public let markerSetMatched: Bool
    public let markerCorrelationRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case primaryBackendID
        case oracleBackendID
        case passedMatched
        case activeErrorRuleIDsMatched
        case ruleAssertionsMatched
        case diagnosticSummaryMatched
        case primaryPassed
        case oraclePassed
        case primaryActiveErrorRuleIDs
        case oracleActiveErrorRuleIDs
        case primaryDiagnosticSummary
        case oracleDiagnosticSummary
        case mismatchReasons
        case agreementPassed
        case primaryMarkerFingerprints
        case oracleMarkerFingerprints
        case markerSetMatched
        case markerCorrelationRequired
    }

    public init(
        primaryBackendID: String,
        oracleBackendID: String,
        passedMatched: Bool,
        activeErrorRuleIDsMatched: Bool,
        ruleAssertionsMatched: Bool,
        diagnosticSummaryMatched: Bool,
        primaryPassed: Bool,
        oraclePassed: Bool,
        primaryActiveErrorRuleIDs: [String],
        oracleActiveErrorRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        oracleDiagnosticSummary: DRCDiagnosticSummary,
        mismatchReasons: [String],
        agreementPassed: Bool? = nil,
        primaryMarkerFingerprints: [String] = [],
        oracleMarkerFingerprints: [String] = [],
        markerSetMatched: Bool? = nil,
        markerCorrelationRequired: Bool = false
    ) {
        self.primaryBackendID = primaryBackendID
        self.oracleBackendID = oracleBackendID
        self.passedMatched = passedMatched
        self.activeErrorRuleIDsMatched = activeErrorRuleIDsMatched
        self.ruleAssertionsMatched = ruleAssertionsMatched
        self.diagnosticSummaryMatched = diagnosticSummaryMatched
        self.primaryPassed = primaryPassed
        self.oraclePassed = oraclePassed
        self.primaryActiveErrorRuleIDs = primaryActiveErrorRuleIDs
        self.oracleActiveErrorRuleIDs = oracleActiveErrorRuleIDs
        self.primaryDiagnosticSummary = primaryDiagnosticSummary
        self.oracleDiagnosticSummary = oracleDiagnosticSummary
        self.mismatchReasons = mismatchReasons
        self.primaryMarkerFingerprints = primaryMarkerFingerprints.sorted()
        self.oracleMarkerFingerprints = oracleMarkerFingerprints.sorted()
        self.markerSetMatched = markerSetMatched
            ?? (self.primaryMarkerFingerprints == self.oracleMarkerFingerprints)
        self.markerCorrelationRequired = markerCorrelationRequired
        if let agreementPassed {
            self.agreementPassed = agreementPassed
        } else {
            self.agreementPassed = passedMatched
                && self.ruleAssertionsMatched
                && (!markerCorrelationRequired || self.markerSetMatched)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryBackendID = try container.decode(String.self, forKey: .primaryBackendID)
        oracleBackendID = try container.decode(String.self, forKey: .oracleBackendID)
        passedMatched = try container.decode(Bool.self, forKey: .passedMatched)
        activeErrorRuleIDsMatched = try container.decode(Bool.self, forKey: .activeErrorRuleIDsMatched)
        ruleAssertionsMatched = try container.decode(Bool.self, forKey: .ruleAssertionsMatched)
        diagnosticSummaryMatched = try container.decode(Bool.self, forKey: .diagnosticSummaryMatched)
        primaryPassed = try container.decode(Bool.self, forKey: .primaryPassed)
        oraclePassed = try container.decode(Bool.self, forKey: .oraclePassed)
        primaryActiveErrorRuleIDs = try container.decode([String].self, forKey: .primaryActiveErrorRuleIDs)
        oracleActiveErrorRuleIDs = try container.decode([String].self, forKey: .oracleActiveErrorRuleIDs)
        primaryDiagnosticSummary = try container.decode(DRCDiagnosticSummary.self, forKey: .primaryDiagnosticSummary)
        oracleDiagnosticSummary = try container.decode(DRCDiagnosticSummary.self, forKey: .oracleDiagnosticSummary)
        mismatchReasons = try container.decode([String].self, forKey: .mismatchReasons)
        markerCorrelationRequired = try container.decodeIfPresent(
            Bool.self,
            forKey: .markerCorrelationRequired
        ) ?? false
        primaryMarkerFingerprints = try container.decodeIfPresent(
            [String].self,
            forKey: .primaryMarkerFingerprints
        ) ?? []
        oracleMarkerFingerprints = try container.decodeIfPresent(
            [String].self,
            forKey: .oracleMarkerFingerprints
        ) ?? []
        markerSetMatched = try container.decodeIfPresent(Bool.self, forKey: .markerSetMatched)
            ?? (primaryMarkerFingerprints == oracleMarkerFingerprints)
        agreementPassed = try container.decodeIfPresent(Bool.self, forKey: .agreementPassed)
            ?? (passedMatched && ruleAssertionsMatched
                && (!markerCorrelationRequired || markerSetMatched))
    }
}
