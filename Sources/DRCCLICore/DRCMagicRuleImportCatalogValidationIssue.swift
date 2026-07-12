import Foundation

public struct DRCMagicRuleImportCatalogValidationIssue: Sendable, Hashable, Equatable {
    public let code: String
    public let message: String
    public let field: String?

    public init(code: String, message: String, field: String? = nil) {
        self.code = code
        self.message = message
        self.field = field
    }
}
