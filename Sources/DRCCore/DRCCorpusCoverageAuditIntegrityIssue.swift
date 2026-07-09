public struct DRCCorpusCoverageAuditIntegrityIssue: Sendable, Hashable, Codable {
    public let code: String
    public let fieldPath: String
    public let message: String
    public let suggestedActions: [String]

    public init(
        code: String,
        fieldPath: String,
        message: String,
        suggestedActions: [String] = []
    ) {
        self.code = code
        self.fieldPath = fieldPath
        self.message = message
        self.suggestedActions = suggestedActions
    }

    public static func issue(
        code: String,
        fieldPath: String,
        message: String,
        suggestedActions: [String]
    ) -> DRCCorpusCoverageAuditIntegrityIssue {
        DRCCorpusCoverageAuditIntegrityIssue(
            code: code,
            fieldPath: fieldPath,
            message: message,
            suggestedActions: suggestedActions
        )
    }
}
