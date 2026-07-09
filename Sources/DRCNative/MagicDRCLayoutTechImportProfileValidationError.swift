import Foundation

public struct MagicDRCLayoutTechImportProfileValidationError: Error, LocalizedError, Sendable, Hashable {
    public let profileID: String
    public let issues: [MagicDRCLayoutTechImportProfileValidationIssue]

    public init(profileID: String, issues: [MagicDRCLayoutTechImportProfileValidationIssue]) {
        self.profileID = profileID
        self.issues = issues
    }

    public var errorDescription: String? {
        let issueSummary = issues
            .map { "\($0.code.rawValue) at \($0.field)" }
            .joined(separator: ", ")
        return "Invalid Magic DRC LayoutTech import profile \(profileID): \(issueSummary)"
    }
}
