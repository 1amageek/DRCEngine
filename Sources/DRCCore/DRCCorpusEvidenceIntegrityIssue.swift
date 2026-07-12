import Foundation

public struct DRCCorpusEvidenceIntegrityIssue: Sendable, Hashable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
