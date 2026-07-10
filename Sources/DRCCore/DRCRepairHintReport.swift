import Foundation

public struct DRCRepairHintReport: Codable, Sendable, Hashable {
    public static let currentSchemaVersion = 1

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
        schemaVersion: Int = DRCRepairHintReport.currentSchemaVersion,
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
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported DRC repair hint report schema version: \(schemaVersion)."
            )
        }
        self.init(
            schemaVersion: schemaVersion,
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
            diagnostics: try container.decode([DRCRepairHintDiagnostic].self, forKey: .diagnostics)
        )
    }
}
