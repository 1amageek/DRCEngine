import Foundation

public struct DRCArtifactIntegrityIssue: Sendable, Hashable, Equatable {
    public let code: String
    public let recordID: String?
    public let path: String?
    public let message: String

    public init(
        code: String,
        recordID: String? = nil,
        path: String? = nil,
        message: String
    ) {
        self.code = code
        self.recordID = recordID
        self.path = path
        self.message = message
    }
}
