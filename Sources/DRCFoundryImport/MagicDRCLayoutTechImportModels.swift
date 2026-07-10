import Foundation
import LayoutTech

public enum MagicDRCLayoutTechImportStatus: String, Codable, Sendable, Hashable {
    case complete
    case partial
    case blocked
}

public struct MagicDRCImportedRule: Codable, Sendable, Hashable {
    public let family: String
    public let layerName: String
    public let secondaryLayerNames: [String]
    public let thresholdValue: Double?
    public let value: Double
    public let sourceLineNumber: Int
    public let sourceLine: String

    public var secondaryLayerName: String? {
        secondaryLayerNames.first
    }

    public init(
        family: String,
        layerName: String,
        secondaryLayerNames: [String] = [],
        thresholdValue: Double? = nil,
        value: Double,
        sourceLineNumber: Int,
        sourceLine: String
    ) {
        self.family = family
        self.layerName = layerName
        self.secondaryLayerNames = secondaryLayerNames
        self.thresholdValue = thresholdValue
        self.value = value
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }

    private enum CodingKeys: String, CodingKey {
        case family
        case layerName
        case secondaryLayerNames
        case thresholdValue
        case value
        case sourceLineNumber
        case sourceLine
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.family = try container.decode(String.self, forKey: .family)
        self.layerName = try container.decode(String.self, forKey: .layerName)
        self.secondaryLayerNames = try container.decode([String].self, forKey: .secondaryLayerNames)
        self.thresholdValue = try container.decodeIfPresent(Double.self, forKey: .thresholdValue)
        self.value = try container.decode(Double.self, forKey: .value)
        self.sourceLineNumber = try container.decode(Int.self, forKey: .sourceLineNumber)
        self.sourceLine = try container.decode(String.self, forKey: .sourceLine)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(family, forKey: .family)
        try container.encode(layerName, forKey: .layerName)
        try container.encode(secondaryLayerNames, forKey: .secondaryLayerNames)
        try container.encodeIfPresent(thresholdValue, forKey: .thresholdValue)
        try container.encode(value, forKey: .value)
        try container.encode(sourceLineNumber, forKey: .sourceLineNumber)
        try container.encode(sourceLine, forKey: .sourceLine)
    }
}

public struct MagicDRCImportDiagnostic: Codable, Sendable, Hashable {
    public let code: String
    public let message: String
    public let sourceLineNumber: Int?
    public let sourceLine: String?

    public init(
        code: String,
        message: String,
        sourceLineNumber: Int? = nil,
        sourceLine: String? = nil
    ) {
        self.code = code
        self.message = message
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }
}

public enum MagicDRCSourceRuleValidationError: Error, Hashable, Sendable, CustomStringConvertible {
    case emptyExactOverlapSecondaryLayers(ruleID: String)

    public var description: String {
        switch self {
        case .emptyExactOverlapSecondaryLayers(let ruleID):
            return "Exact-overlap source rule \(ruleID) requires at least one secondary layer."
        }
    }
}

public struct MagicDRCSourceExactOverlapRule: Codable, Sendable, Hashable {
    public let id: String
    public let primaryLayerName: String
    public let secondaryLayerNames: [String]
    public let sourceLineNumber: Int
    public let sourceLine: String

    public var secondaryLayerName: String {
        secondaryLayerNames[0]
    }

    public init(
        id: String,
        primaryLayerName: String,
        secondaryLayerNames: [String],
        sourceLineNumber: Int,
        sourceLine: String
    ) throws {
        guard !secondaryLayerNames.isEmpty else {
            throw MagicDRCSourceRuleValidationError.emptyExactOverlapSecondaryLayers(ruleID: id)
        }
        self.id = id
        self.primaryLayerName = primaryLayerName
        self.secondaryLayerNames = secondaryLayerNames
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }

    public init(
        validatingID id: String,
        primaryLayerName: String,
        secondaryLayerNames: [String],
        sourceLineNumber: Int,
        sourceLine: String
    ) throws {
        try self.init(
            id: id,
            primaryLayerName: primaryLayerName,
            secondaryLayerNames: secondaryLayerNames,
            sourceLineNumber: sourceLineNumber,
            sourceLine: sourceLine
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case primaryLayerName
        case secondaryLayerNames
        case sourceLineNumber
        case sourceLine
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.primaryLayerName = try container.decode(String.self, forKey: .primaryLayerName)
        let decodedSecondaryLayerNames = try container.decode([String].self, forKey: .secondaryLayerNames)
        guard !decodedSecondaryLayerNames.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .secondaryLayerNames,
                in: container,
                debugDescription: "Exact-overlap source rules require a secondary layer."
            )
        }
        self.secondaryLayerNames = decodedSecondaryLayerNames
        self.sourceLineNumber = try container.decode(Int.self, forKey: .sourceLineNumber)
        self.sourceLine = try container.decode(String.self, forKey: .sourceLine)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(primaryLayerName, forKey: .primaryLayerName)
        try container.encode(secondaryLayerNames, forKey: .secondaryLayerNames)
        try container.encode(sourceLineNumber, forKey: .sourceLineNumber)
        try container.encode(sourceLine, forKey: .sourceLine)
    }
}

public struct MagicDRCSourceEnclosedHoleRule: Codable, Sendable, Hashable {
    public let id: String
    public let layerName: String
    public let holeLayerName: String
    public let smallHoleLayerName: String
    public let minimumArea: Double
    public let sourceLineNumber: Int
    public let sourceLine: String
    public let definitionLineNumber: Int
    public let definitionLine: String

    public init(
        id: String,
        layerName: String,
        holeLayerName: String,
        smallHoleLayerName: String,
        minimumArea: Double,
        sourceLineNumber: Int,
        sourceLine: String,
        definitionLineNumber: Int,
        definitionLine: String
    ) {
        self.id = id
        self.layerName = layerName
        self.holeLayerName = holeLayerName
        self.smallHoleLayerName = smallHoleLayerName
        self.minimumArea = minimumArea
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
        self.definitionLineNumber = definitionLineNumber
        self.definitionLine = definitionLine
    }
}

public struct MagicDRCSourceForbiddenMarkerRule: Codable, Sendable, Hashable {
    public let id: String
    public let markerLayerName: String
    public let sourceLineNumber: Int
    public let sourceLine: String
    public let definitionLineNumber: Int?
    public let definitionLine: String?
    public let reason: String

    public init(
        id: String,
        markerLayerName: String,
        sourceLineNumber: Int,
        sourceLine: String,
        definitionLineNumber: Int? = nil,
        definitionLine: String? = nil,
        reason: String
    ) {
        self.id = id
        self.markerLayerName = markerLayerName
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
        self.definitionLineNumber = definitionLineNumber
        self.definitionLine = definitionLine
        self.reason = reason
    }
}

public struct MagicDRCSourceTempLayerOperation: Codable, Sendable, Hashable {
    public let command: String
    public let arguments: [String]
    public let sourceLineNumber: Int
    public let sourceLine: String

    public init(
        command: String,
        arguments: [String],
        sourceLineNumber: Int,
        sourceLine: String
    ) {
        self.command = command
        self.arguments = arguments
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }
}

public struct MagicDRCSourceTempLayerDefinition: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let sourceLineNumber: Int
    public let sourceLine: String
    public let initialTerms: [String]
    public let operations: [MagicDRCSourceTempLayerOperation]
    public let referencedLayerNames: [String]
    public let referencedTempLayerNames: [String]
    public let unresolvedReferences: [String]
    public let operationNames: [String]

    public init(
        id: String,
        name: String,
        sourceLineNumber: Int,
        sourceLine: String,
        initialTerms: [String],
        operations: [MagicDRCSourceTempLayerOperation],
        referencedLayerNames: [String],
        referencedTempLayerNames: [String],
        unresolvedReferences: [String],
        operationNames: [String]
    ) {
        self.id = id
        self.name = name
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
        self.initialTerms = initialTerms
        self.operations = operations
        self.referencedLayerNames = referencedLayerNames
        self.referencedTempLayerNames = referencedTempLayerNames
        self.unresolvedReferences = unresolvedReferences
        self.operationNames = operationNames
    }
}

public struct MagicDRCSourceContactStack: Codable, Sendable, Hashable {
    public let id: String
    public let cutLayerName: String
    public let bottomLayerName: String
    public let topLayerName: String
    public let sourceLineNumber: Int
    public let sourceLine: String

    public init(
        id: String,
        cutLayerName: String,
        bottomLayerName: String,
        topLayerName: String,
        sourceLineNumber: Int,
        sourceLine: String
    ) {
        self.id = id
        self.cutLayerName = cutLayerName
        self.bottomLayerName = bottomLayerName
        self.topLayerName = topLayerName
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }
}

public struct MagicDRCProfileMinimumCutPolicy: Codable, Sendable, Hashable {
    public let id: String
    public let interconnectID: String
    public let cutLayerName: String
    public let bottomLayerName: String
    public let topLayerName: String
    public let minimumCount: Int

    public init(
        id: String,
        interconnectID: String,
        cutLayerName: String,
        bottomLayerName: String,
        topLayerName: String,
        minimumCount: Int
    ) {
        self.id = id
        self.interconnectID = interconnectID
        self.cutLayerName = cutLayerName
        self.bottomLayerName = bottomLayerName
        self.topLayerName = topLayerName
        self.minimumCount = minimumCount
    }
}

public struct MagicDRCSourceMinimumCutPolicy: Codable, Sendable, Hashable {
    public let id: String
    public let interconnectID: String
    public let cutLayerName: String
    public let bottomLayerName: String
    public let topLayerName: String
    public let minimumCount: Int
    public let sourceLineNumber: Int
    public let sourceLine: String

    public init(
        id: String,
        interconnectID: String,
        cutLayerName: String,
        bottomLayerName: String,
        topLayerName: String,
        minimumCount: Int,
        sourceLineNumber: Int,
        sourceLine: String
    ) {
        self.id = id
        self.interconnectID = interconnectID
        self.cutLayerName = cutLayerName
        self.bottomLayerName = bottomLayerName
        self.topLayerName = topLayerName
        self.minimumCount = minimumCount
        self.sourceLineNumber = sourceLineNumber
        self.sourceLine = sourceLine
    }
}

public struct MagicDRCLayoutTechImportReport: Codable, Sendable, Hashable {
    public static let currentSchemaVersion = 1
    public static let artifactKind = "drc-foundry-rule-import"

    public let schemaVersion: Int
    public let kind: String
    public let generatedAt: String
    public let status: MagicDRCLayoutTechImportStatus
    public let sourcePath: String
    public let supportedRuleFamilies: [String]
    public let importedRuleCount: Int
    public let skippedRuleCount: Int
    public let importedFamilyCounts: [String: Int]
    public let skippedFamilyCounts: [String: Int]
    public let importedLayerNames: [String]
    public let sourceCutLayerNames: [String]
    public let sourceCutAliasCount: Int
    public let sourceContactDefinitionIDs: [String]
    public let sourceContactDefinitionCount: Int
    public let sourceContactStacks: [MagicDRCSourceContactStack]
    public let sourceContactStackIDs: [String]
    public let sourceContactStackCount: Int
    public let sourceExactOverlapRules: [MagicDRCSourceExactOverlapRule]
    public let sourceExactOverlapRuleIDs: [String]
    public let sourceExactOverlapRuleCount: Int
    public let sourceEnclosedHoleRules: [MagicDRCSourceEnclosedHoleRule]
    public let sourceEnclosedHoleRuleIDs: [String]
    public let sourceEnclosedHoleRuleCount: Int
    public let sourceForbiddenMarkerRules: [MagicDRCSourceForbiddenMarkerRule]
    public let sourceForbiddenMarkerRuleIDs: [String]
    public let sourceForbiddenMarkerRuleCount: Int
    public let sourceTempLayerDefinitions: [MagicDRCSourceTempLayerDefinition]
    public let sourceTempLayerDefinitionIDs: [String]
    public let sourceTempLayerDefinitionCount: Int
    public let sourceTempLayerOperationCounts: [String: Int]
    public let sourceTempLayerMaterializedRuleIDs: [String]
    public let sourceTempLayerMaterializedRuleCount: Int
    public let sourceMinimumCutPolicies: [MagicDRCSourceMinimumCutPolicy]
    public let sourceMinimumCutPolicyIDs: [String]
    public let sourceMinimumCutPolicyCount: Int
    public let profileMinimumCutPolicies: [MagicDRCProfileMinimumCutPolicy]
    public let profileMinimumCutPolicyIDs: [String]
    public let profileMinimumCutPolicyCount: Int
    public let derivedViaDefinitionIDs: [String]
    public let derivedContactDefinitionIDs: [String]
    public let derivedMinimumCutRuleIDs: [String]
    public let sourceLayerCount: Int
    public let importedRules: [MagicDRCImportedRule]
    public let diagnostics: [MagicDRCImportDiagnostic]

    public init(
        schemaVersion: Int = MagicDRCLayoutTechImportReport.currentSchemaVersion,
        kind: String = MagicDRCLayoutTechImportReport.artifactKind,
        generatedAt: String,
        status: MagicDRCLayoutTechImportStatus,
        sourcePath: String,
        supportedRuleFamilies: [String],
        importedRuleCount: Int,
        skippedRuleCount: Int,
        importedFamilyCounts: [String: Int],
        skippedFamilyCounts: [String: Int],
        importedLayerNames: [String],
        sourceCutLayerNames: [String] = [],
        sourceCutAliasCount: Int = 0,
        sourceContactDefinitionIDs: [String] = [],
        sourceContactDefinitionCount: Int = 0,
        sourceContactStacks: [MagicDRCSourceContactStack] = [],
        sourceContactStackIDs: [String]? = nil,
        sourceContactStackCount: Int? = nil,
        sourceExactOverlapRules: [MagicDRCSourceExactOverlapRule] = [],
        sourceExactOverlapRuleIDs: [String] = [],
        sourceExactOverlapRuleCount: Int = 0,
        sourceEnclosedHoleRules: [MagicDRCSourceEnclosedHoleRule] = [],
        sourceEnclosedHoleRuleIDs: [String] = [],
        sourceEnclosedHoleRuleCount: Int = 0,
        sourceForbiddenMarkerRules: [MagicDRCSourceForbiddenMarkerRule] = [],
        sourceForbiddenMarkerRuleIDs: [String] = [],
        sourceForbiddenMarkerRuleCount: Int = 0,
        sourceTempLayerDefinitions: [MagicDRCSourceTempLayerDefinition] = [],
        sourceTempLayerDefinitionIDs: [String] = [],
        sourceTempLayerDefinitionCount: Int = 0,
        sourceTempLayerOperationCounts: [String: Int] = [:],
        sourceTempLayerMaterializedRuleIDs: [String] = [],
        sourceTempLayerMaterializedRuleCount: Int = 0,
        sourceMinimumCutPolicies: [MagicDRCSourceMinimumCutPolicy] = [],
        sourceMinimumCutPolicyIDs: [String]? = nil,
        sourceMinimumCutPolicyCount: Int? = nil,
        profileMinimumCutPolicies: [MagicDRCProfileMinimumCutPolicy] = [],
        profileMinimumCutPolicyIDs: [String]? = nil,
        profileMinimumCutPolicyCount: Int? = nil,
        derivedViaDefinitionIDs: [String] = [],
        derivedContactDefinitionIDs: [String] = [],
        derivedMinimumCutRuleIDs: [String] = [],
        sourceLayerCount: Int,
        importedRules: [MagicDRCImportedRule],
        diagnostics: [MagicDRCImportDiagnostic]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.generatedAt = generatedAt
        self.status = status
        self.sourcePath = sourcePath
        self.supportedRuleFamilies = supportedRuleFamilies
        self.importedRuleCount = importedRuleCount
        self.skippedRuleCount = skippedRuleCount
        self.importedFamilyCounts = importedFamilyCounts
        self.skippedFamilyCounts = skippedFamilyCounts
        self.importedLayerNames = importedLayerNames
        self.sourceCutLayerNames = sourceCutLayerNames
        self.sourceCutAliasCount = sourceCutAliasCount
        self.sourceContactDefinitionIDs = sourceContactDefinitionIDs
        self.sourceContactDefinitionCount = sourceContactDefinitionCount
        self.sourceContactStacks = sourceContactStacks
        self.sourceContactStackIDs = sourceContactStackIDs ?? sourceContactStacks.map(\.id)
        self.sourceContactStackCount = sourceContactStackCount ?? sourceContactStacks.count
        self.sourceExactOverlapRules = sourceExactOverlapRules
        self.sourceExactOverlapRuleIDs = sourceExactOverlapRuleIDs
        self.sourceExactOverlapRuleCount = sourceExactOverlapRuleCount
        self.sourceEnclosedHoleRules = sourceEnclosedHoleRules
        self.sourceEnclosedHoleRuleIDs = sourceEnclosedHoleRuleIDs
        self.sourceEnclosedHoleRuleCount = sourceEnclosedHoleRuleCount
        self.sourceForbiddenMarkerRules = sourceForbiddenMarkerRules
        self.sourceForbiddenMarkerRuleIDs = sourceForbiddenMarkerRuleIDs
        self.sourceForbiddenMarkerRuleCount = sourceForbiddenMarkerRuleCount
        self.sourceTempLayerDefinitions = sourceTempLayerDefinitions
        self.sourceTempLayerDefinitionIDs = sourceTempLayerDefinitionIDs
        self.sourceTempLayerDefinitionCount = sourceTempLayerDefinitionCount
        self.sourceTempLayerOperationCounts = sourceTempLayerOperationCounts
        self.sourceTempLayerMaterializedRuleIDs = sourceTempLayerMaterializedRuleIDs
        self.sourceTempLayerMaterializedRuleCount = sourceTempLayerMaterializedRuleCount
        self.sourceMinimumCutPolicies = sourceMinimumCutPolicies
        self.sourceMinimumCutPolicyIDs = sourceMinimumCutPolicyIDs ?? sourceMinimumCutPolicies.map(\.id)
        self.sourceMinimumCutPolicyCount = sourceMinimumCutPolicyCount ?? sourceMinimumCutPolicies.count
        self.profileMinimumCutPolicies = profileMinimumCutPolicies
        self.profileMinimumCutPolicyIDs = profileMinimumCutPolicyIDs ?? profileMinimumCutPolicies.map(\.id)
        self.profileMinimumCutPolicyCount = profileMinimumCutPolicyCount ?? profileMinimumCutPolicies.count
        self.derivedViaDefinitionIDs = derivedViaDefinitionIDs
        self.derivedContactDefinitionIDs = derivedContactDefinitionIDs
        self.derivedMinimumCutRuleIDs = derivedMinimumCutRuleIDs
        self.sourceLayerCount = sourceLayerCount
        self.importedRules = importedRules
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case generatedAt
        case status
        case sourcePath
        case supportedRuleFamilies
        case importedRuleCount
        case skippedRuleCount
        case importedFamilyCounts
        case skippedFamilyCounts
        case importedLayerNames
        case sourceCutLayerNames
        case sourceCutAliasCount
        case sourceContactDefinitionIDs
        case sourceContactDefinitionCount
        case sourceContactStacks
        case sourceContactStackIDs
        case sourceContactStackCount
        case sourceExactOverlapRules
        case sourceExactOverlapRuleIDs
        case sourceExactOverlapRuleCount
        case sourceEnclosedHoleRules
        case sourceEnclosedHoleRuleIDs
        case sourceEnclosedHoleRuleCount
        case sourceForbiddenMarkerRules
        case sourceForbiddenMarkerRuleIDs
        case sourceForbiddenMarkerRuleCount
        case sourceTempLayerDefinitions
        case sourceTempLayerDefinitionIDs
        case sourceTempLayerDefinitionCount
        case sourceTempLayerOperationCounts
        case sourceTempLayerMaterializedRuleIDs
        case sourceTempLayerMaterializedRuleCount
        case sourceMinimumCutPolicies
        case sourceMinimumCutPolicyIDs
        case sourceMinimumCutPolicyCount
        case profileMinimumCutPolicies
        case profileMinimumCutPolicyIDs
        case profileMinimumCutPolicyCount
        case derivedViaDefinitionIDs
        case derivedContactDefinitionIDs
        case derivedMinimumCutRuleIDs
        case sourceLayerCount
        case importedRules
        case diagnostics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Magic DRC import report schema version: \(schemaVersion)."
            )
        }
        kind = try container.decode(String.self, forKey: .kind)
        guard kind == Self.artifactKind else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unsupported Magic DRC import report kind: \(kind)."
            )
        }
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        status = try container.decode(MagicDRCLayoutTechImportStatus.self, forKey: .status)
        sourcePath = try container.decode(String.self, forKey: .sourcePath)
        supportedRuleFamilies = try container.decode([String].self, forKey: .supportedRuleFamilies)
        importedRuleCount = try container.decode(Int.self, forKey: .importedRuleCount)
        skippedRuleCount = try container.decode(Int.self, forKey: .skippedRuleCount)
        importedFamilyCounts = try container.decode([String: Int].self, forKey: .importedFamilyCounts)
        skippedFamilyCounts = try container.decode([String: Int].self, forKey: .skippedFamilyCounts)
        importedLayerNames = try container.decode([String].self, forKey: .importedLayerNames)
        sourceCutLayerNames = try container.decode([String].self, forKey: .sourceCutLayerNames)
        sourceCutAliasCount = try container.decode(Int.self, forKey: .sourceCutAliasCount)
        sourceContactDefinitionIDs = try container.decode([String].self, forKey: .sourceContactDefinitionIDs)
        sourceContactDefinitionCount = try container.decode(Int.self, forKey: .sourceContactDefinitionCount)
        sourceContactStacks = try container.decode([MagicDRCSourceContactStack].self, forKey: .sourceContactStacks)
        sourceContactStackIDs = try container.decode([String].self, forKey: .sourceContactStackIDs)
        sourceContactStackCount = try container.decode(Int.self, forKey: .sourceContactStackCount)
        sourceExactOverlapRules = try container.decode(
            [MagicDRCSourceExactOverlapRule].self,
            forKey: .sourceExactOverlapRules
        )
        sourceExactOverlapRuleIDs = try container.decode([String].self, forKey: .sourceExactOverlapRuleIDs)
        sourceExactOverlapRuleCount = try container.decode(Int.self, forKey: .sourceExactOverlapRuleCount)
        sourceEnclosedHoleRules = try container.decode(
            [MagicDRCSourceEnclosedHoleRule].self,
            forKey: .sourceEnclosedHoleRules
        )
        sourceEnclosedHoleRuleIDs = try container.decode([String].self, forKey: .sourceEnclosedHoleRuleIDs)
        sourceEnclosedHoleRuleCount = try container.decode(Int.self, forKey: .sourceEnclosedHoleRuleCount)
        sourceForbiddenMarkerRules = try container.decode(
            [MagicDRCSourceForbiddenMarkerRule].self,
            forKey: .sourceForbiddenMarkerRules
        )
        sourceForbiddenMarkerRuleIDs = try container.decode([String].self, forKey: .sourceForbiddenMarkerRuleIDs)
        sourceForbiddenMarkerRuleCount = try container.decode(Int.self, forKey: .sourceForbiddenMarkerRuleCount)
        sourceTempLayerDefinitions = try container.decode(
            [MagicDRCSourceTempLayerDefinition].self,
            forKey: .sourceTempLayerDefinitions
        )
        sourceTempLayerDefinitionIDs = try container.decode([String].self, forKey: .sourceTempLayerDefinitionIDs)
        sourceTempLayerDefinitionCount = try container.decode(Int.self, forKey: .sourceTempLayerDefinitionCount)
        sourceTempLayerOperationCounts = try container.decode([String: Int].self, forKey: .sourceTempLayerOperationCounts)
        sourceTempLayerMaterializedRuleIDs = try container.decode(
            [String].self,
            forKey: .sourceTempLayerMaterializedRuleIDs
        )
        sourceTempLayerMaterializedRuleCount = try container.decode(
            Int.self,
            forKey: .sourceTempLayerMaterializedRuleCount
        )
        sourceMinimumCutPolicies = try container.decode(
            [MagicDRCSourceMinimumCutPolicy].self,
            forKey: .sourceMinimumCutPolicies
        )
        sourceMinimumCutPolicyIDs = try container.decode([String].self, forKey: .sourceMinimumCutPolicyIDs)
        sourceMinimumCutPolicyCount = try container.decode(Int.self, forKey: .sourceMinimumCutPolicyCount)
        profileMinimumCutPolicies = try container.decode(
            [MagicDRCProfileMinimumCutPolicy].self,
            forKey: .profileMinimumCutPolicies
        )
        profileMinimumCutPolicyIDs = try container.decode([String].self, forKey: .profileMinimumCutPolicyIDs)
        profileMinimumCutPolicyCount = try container.decode(Int.self, forKey: .profileMinimumCutPolicyCount)
        derivedViaDefinitionIDs = try container.decode([String].self, forKey: .derivedViaDefinitionIDs)
        derivedContactDefinitionIDs = try container.decode([String].self, forKey: .derivedContactDefinitionIDs)
        derivedMinimumCutRuleIDs = try container.decode([String].self, forKey: .derivedMinimumCutRuleIDs)
        sourceLayerCount = try container.decode(Int.self, forKey: .sourceLayerCount)
        importedRules = try container.decode([MagicDRCImportedRule].self, forKey: .importedRules)
        diagnostics = try container.decode([MagicDRCImportDiagnostic].self, forKey: .diagnostics)
    }
}

public struct MagicDRCLayoutTechImport: Sendable, Hashable {
    public let technology: LayoutTechDatabase
    public let report: MagicDRCLayoutTechImportReport

    public init(
        technology: LayoutTechDatabase,
        report: MagicDRCLayoutTechImportReport
    ) {
        self.technology = technology
        self.report = report
    }
}
