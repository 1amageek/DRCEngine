public enum DRCCorpusEvidenceKind: String, Sendable, Hashable, Codable {
    case regression
    case independentCorrelation = "independent-correlation"
    case independentRuleCorrelation = "independent-rule-correlation"

    public var requiresIndependentOracle: Bool {
        self != .regression
    }

    public var requiresMarkerCorrelation: Bool {
        self == .independentCorrelation
    }
}
