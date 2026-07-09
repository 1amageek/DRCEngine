public struct DRCRepairHintDiagnostic: Codable, Sendable, Hashable {
    public let severity: String
    public let code: String
    public let message: String
    public let sourceDiagnosticIndex: Int?
    public let source: String?
    public let suggestedActions: [String]

    public init(
        severity: String,
        code: String,
        message: String,
        sourceDiagnosticIndex: Int? = nil,
        source: String? = nil,
        suggestedActions: [String] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.sourceDiagnosticIndex = sourceDiagnosticIndex
        self.source = source
        self.suggestedActions = suggestedActions
    }
}
