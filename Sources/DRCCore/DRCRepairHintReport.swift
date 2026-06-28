import Foundation

public struct DRCRepairHintReport: Codable, Sendable, Hashable {
    public let schemaVersion: Int
    public let status: String
    public let reportURL: URL?
    public let backendID: String
    public let topCell: String
    public let activeDiagnosticCount: Int
    public let hintCount: Int
    public let hints: [DRCRepairHint]
    public let unsupportedDiagnosticIndexes: [Int]

    public init(
        schemaVersion: Int = 1,
        status: String,
        reportURL: URL?,
        backendID: String,
        topCell: String,
        activeDiagnosticCount: Int,
        hintCount: Int,
        hints: [DRCRepairHint],
        unsupportedDiagnosticIndexes: [Int]
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.reportURL = reportURL
        self.backendID = backendID
        self.topCell = topCell
        self.activeDiagnosticCount = activeDiagnosticCount
        self.hintCount = hintCount
        self.hints = hints
        self.unsupportedDiagnosticIndexes = unsupportedDiagnosticIndexes
    }
}
