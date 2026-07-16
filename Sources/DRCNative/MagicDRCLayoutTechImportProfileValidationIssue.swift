import Foundation

public struct MagicDRCLayoutTechImportProfileValidationIssue: Codable, Sendable, Hashable {
    public enum Code: String, Codable, Sendable, Hashable {
        case emptyProfileID
        case emptyLayerName
        case duplicateLayerName
        case emptyMapKey
        case emptyMapValue
        case unknownReferencedLayerName
        case unsupportedFillPattern
        case unsupportedPreferredDirection
        case invalidColorComponent
        case emptyDerivedLayerSeedID
        case emptyDerivedLayerSeedSourceLayers
        case unsupportedDerivedLayerOperation
        case emptyCutStackConnectionID
        case unsupportedCutStackKind
        case invalidMinimumCutCount
    }

    public let code: Code
    public let field: String
    public let message: String

    public init(code: Code, field: String, message: String) {
        self.code = code
        self.field = field
        self.message = message
    }
}
