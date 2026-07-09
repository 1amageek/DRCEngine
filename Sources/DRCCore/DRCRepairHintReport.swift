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
    public let diagnostics: [DRCRepairHintDiagnostic]

    public init(
        schemaVersion: Int = 1,
        status: String,
        reportURL: URL?,
        backendID: String,
        topCell: String,
        activeDiagnosticCount: Int,
        hintCount: Int,
        hints: [DRCRepairHint],
        unsupportedDiagnosticIndexes: [Int],
        diagnostics: [DRCRepairHintDiagnostic] = []
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
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case status
        case reportURL
        case backendID
        case topCell
        case activeDiagnosticCount
        case hintCount
        case hints
        case unsupportedDiagnosticIndexes
        case diagnostics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1,
            status: try container.decode(String.self, forKey: .status),
            reportURL: try container.decodeIfPresent(URL.self, forKey: .reportURL),
            backendID: try container.decode(String.self, forKey: .backendID),
            topCell: try container.decode(String.self, forKey: .topCell),
            activeDiagnosticCount: try container.decode(Int.self, forKey: .activeDiagnosticCount),
            hintCount: try container.decode(Int.self, forKey: .hintCount),
            hints: try container.decode([DRCRepairHint].self, forKey: .hints),
            unsupportedDiagnosticIndexes: try container.decode(
                [Int].self,
                forKey: .unsupportedDiagnosticIndexes
            ),
            diagnostics: try container.decodeIfPresent(
                [DRCRepairHintDiagnostic].self,
                forKey: .diagnostics
            ) ?? []
        )
    }
}
