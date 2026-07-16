import Foundation
import DRCFoundryImport

/// Lowers parsed Magic antenna source evidence into executable NativeDRC rules.
///
/// The factory requires process metadata that a Magic source declaration does
/// not contain by itself, notably sidewall thickness. Missing metadata is a
/// typed construction error; the factory never silently emits a weaker rule.
public enum NativeDRCAntennaRuleFactory {
    public enum ConstructionError: Error, LocalizedError, Sendable, Hashable {
        case emptySourceRules
        case missingModel(sourceRuleID: String)
        case modelMismatch(sourceRuleID: String)
        case invalidRatio(sourceRuleID: String)
        case duplicateLayer(layer: String)
        case missingProcessOrder
        case emptyProcessLayerOrder(index: Int)
        case duplicateProcessLayerOrder(layer: String)
        case layerMissingFromProcessOrder(layer: String)
        case missingThickness(layer: String)
        case invalidThickness(layer: String)
        case invalidCorrection(sourceRuleID: String)
        case invalidCutConnection
        case duplicateCutConnection

        public var errorDescription: String? {
            switch self {
            case .emptySourceRules:
                return "At least one source antenna rule is required."
            case .missingModel(let sourceRuleID):
                return "Source antenna rule \(sourceRuleID) has no partial/cumulative model."
            case .modelMismatch(let sourceRuleID):
                return "Source antenna rule \(sourceRuleID) uses a different antenna model."
            case .invalidRatio(let sourceRuleID):
                return "Source antenna rule \(sourceRuleID) has an invalid maximum ratio."
            case .duplicateLayer(let layer):
                return "Antenna layer \(layer) appears more than once in the source deck."
            case .missingProcessOrder:
                return "Cumulative antenna rules require an explicit process layer order."
            case .emptyProcessLayerOrder(let index):
                return "Process layer order contains an empty layer at index \(index)."
            case .duplicateProcessLayerOrder(let layer):
                return "Process layer order contains duplicate layer \(layer)."
            case .layerMissingFromProcessOrder(let layer):
                return "Antenna layer \(layer) is missing from the process layer order."
            case .missingThickness(let layer):
                return "Sidewall antenna layer \(layer) requires a process thickness."
            case .invalidThickness(let layer):
                return "Antenna layer \(layer) has an invalid process thickness."
            case .invalidCorrection(let sourceRuleID):
                return "Source antenna rule \(sourceRuleID) has invalid diffusion correction parameters."
            case .invalidCutConnection:
                return "Antenna cut connectivity contains an empty layer or identical lower/upper layers."
            case .duplicateCutConnection:
                return "Antenna cut connectivity contains a duplicate connection."
            }
        }
    }

    /// Builds one executable rule for every process stage represented by the
    /// source deck. `sourceRules` must be supplied in process order.
    public static func makeRules(
        from sourceRules: [MagicDRCSourceAntennaRule],
        model requestedModel: NativeDRCRule.AntennaModel? = nil,
        thicknessByLayer: [String: Double] = [:],
        processLayerOrder: [String]? = nil,
        gateLayer: String? = nil,
        processStepByLayer: [String: String] = [:],
        antennaCutConnections: [NativeDRCAntennaCutConnection]? = nil
    ) throws -> [NativeDRCRule] {
        guard !sourceRules.isEmpty else {
            throw ConstructionError.emptySourceRules
        }

        let model = try resolvedModel(sourceRules: sourceRules, requestedModel: requestedModel)
        if let antennaCutConnections {
            var seenConnections = Set<NativeDRCAntennaCutConnection>()
            for connection in antennaCutConnections {
                guard !connection.layer.isEmpty,
                      !connection.lowerLayer.isEmpty,
                      !connection.upperLayer.isEmpty,
                      connection.lowerLayer != connection.upperLayer else {
                    throw ConstructionError.invalidCutConnection
                }
                guard seenConnections.insert(connection).inserted else {
                    throw ConstructionError.duplicateCutConnection
                }
            }
        }
        var seenLayers = Set<String>()
        var stages: [(layer: String, source: MagicDRCSourceAntennaRule)] = []
        for sourceRule in sourceRules {
            guard sourceRule.maxRatio.isFinite, sourceRule.maxRatio > 0 else {
                throw ConstructionError.invalidRatio(sourceRuleID: sourceRule.id)
            }
            guard sourceRule.correctionParameters.count <= 2,
                  sourceRule.diffusionRatioConstant == sourceRule.correctionParameters.first,
                  sourceRule.diffusionRatioPerArea == sourceRule.correctionParameters.dropFirst().first else {
                throw ConstructionError.invalidCorrection(sourceRuleID: sourceRule.id)
            }
            for layer in sourceRule.layerNames {
                guard !layer.isEmpty, seenLayers.insert(layer).inserted else {
                    throw ConstructionError.duplicateLayer(layer: layer)
                }
                if sourceRule.measurement == .sidewall {
                    guard let thickness = thicknessByLayer[layer] else {
                        throw ConstructionError.missingThickness(layer: layer)
                    }
                    guard thickness.isFinite, thickness > 0 else {
                        throw ConstructionError.invalidThickness(layer: layer)
                    }
                }
                stages.append((layer: layer, source: sourceRule))
            }
        }

        if model == .cumulative {
            guard let processLayerOrder, !processLayerOrder.isEmpty else {
                throw ConstructionError.missingProcessOrder
            }
            var orderByLayer: [String: Int] = [:]
            for (index, layer) in processLayerOrder.enumerated() {
                guard !layer.isEmpty else {
                    throw ConstructionError.emptyProcessLayerOrder(index: index)
                }
                guard orderByLayer[layer] == nil else {
                    throw ConstructionError.duplicateProcessLayerOrder(layer: layer)
                }
                orderByLayer[layer] = index
            }
            for stage in stages where orderByLayer[stage.layer] == nil {
                throw ConstructionError.layerMissingFromProcessOrder(layer: stage.layer)
            }
            stages.sort { lhs, rhs in
                orderByLayer[lhs.layer, default: .max] < orderByLayer[rhs.layer, default: .max]
            }
        }

        var rules: [NativeDRCRule] = []
        for index in stages.indices {
            let stage = stages[index]
            let activeStages: ArraySlice<(layer: String, source: MagicDRCSourceAntennaRule)>
            switch model {
            case .partial:
                activeStages = stages[index...index]
            case .cumulative:
                activeStages = stages[...index]
            }
            let antennaLayers = activeStages.map { stage in
                let source = stage.source
                return NativeDRCAntennaLayer(
                    layer: stage.layer,
                    measurement: source.measurement == .surface ? .surface : .sidewall,
                    ratioGate: source.maxRatio,
                    thickness: source.measurement == .sidewall ? thicknessByLayer[stage.layer] : nil,
                    diffusionCorrection: source.diffusionCorrection == .some(.none) ? .none : .finite,
                    diffusionRatioConstant: source.diffusionRatioConstant,
                    diffusionRatioPerArea: source.diffusionRatioPerArea
                )
            }
            rules.append(NativeDRCRule(
                id: "antenna.\(stage.source.id).\(stage.layer)",
                kind: .maximumAntennaRatio,
                layer: stage.layer,
                value: stage.source.maxRatio,
                gateLayer: gateLayer,
                processStep: processStepByLayer[stage.layer],
                antennaCutConnections: antennaCutConnections,
                antennaModel: model,
                antennaLayers: antennaLayers
            ))
        }
        return rules
    }

    /// Convenience overload that preserves the parser's resolved source
    /// evidence and process thickness artifact.
    public static func makeRules(
        from report: MagicDRCLayoutTechImportReport,
        model requestedModel: NativeDRCRule.AntennaModel? = nil,
        gateLayer: String? = nil,
        processStepByLayer: [String: String] = [:],
        antennaCutConnections: [NativeDRCAntennaCutConnection]? = nil
    ) throws -> [NativeDRCRule] {
        try makeRules(
            from: report.sourceAntennaRules,
            model: requestedModel,
            thicknessByLayer: report.sourceAntennaThicknesses,
            processLayerOrder: report.profileLayerOrder,
            gateLayer: gateLayer,
            processStepByLayer: processStepByLayer,
            antennaCutConnections: antennaCutConnections ?? report.sourceContactStacks.map {
                NativeDRCAntennaCutConnection(
                    layer: $0.cutLayerName,
                    lowerLayer: $0.bottomLayerName,
                    upperLayer: $0.topLayerName
                )
            }
        )
    }

    private static func resolvedModel(
        sourceRules: [MagicDRCSourceAntennaRule],
        requestedModel: NativeDRCRule.AntennaModel?
    ) throws -> NativeDRCRule.AntennaModel {
        var resolved = requestedModel
        for sourceRule in sourceRules {
            guard let sourceModel = sourceRule.model else {
                guard resolved != nil else {
                    throw ConstructionError.missingModel(sourceRuleID: sourceRule.id)
                }
                continue
            }
            let candidate: NativeDRCRule.AntennaModel = sourceModel == .partial ? .partial : .cumulative
            if let resolved, resolved != candidate {
                throw ConstructionError.modelMismatch(sourceRuleID: sourceRule.id)
            }
            resolved = candidate
        }
        guard let resolved else {
            throw ConstructionError.missingModel(sourceRuleID: sourceRules[0].id)
        }
        return resolved
    }
}
