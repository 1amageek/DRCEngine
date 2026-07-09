public struct DRCWaiverValidationIssue: Sendable, Hashable, Codable {
    public let code: String
    public let waiverID: String?
    public let fieldPath: String
    public let message: String
    public let suggestedActions: [String]

    public init(
        code: String,
        waiverID: String?,
        fieldPath: String,
        message: String,
        suggestedActions: [String]
    ) {
        self.code = code
        self.waiverID = waiverID
        self.fieldPath = fieldPath
        self.message = message
        self.suggestedActions = suggestedActions
    }
}
