import Foundation
import LayoutCore
import LayoutTech
import DRCFoundryImport

extension MagicDRCLayoutTechImporter {
    static func aggregateLayerRules(
        _ importedRules: [MagicDRCImportedRule]
    ) -> [String: LayerRuleState] {
        var states: [String: LayerRuleState] = [:]
        for rule in importedRules {
            var state = states[rule.layerName] ?? LayerRuleState()
            switch rule.family {
            case "width":
                state.minWidth = max(state.minWidth ?? 0, rule.value)
            case "spacing":
                if rule.secondaryLayerName == nil || rule.secondaryLayerName == rule.layerName {
                    state.minSpacing = max(state.minSpacing ?? 0, rule.value)
                }
            case "area":
                state.minArea = max(state.minArea ?? 0, rule.value)
            case "notch":
                state.minNotch = max(state.minNotch ?? 0, rule.value)
            case "rect_only":
                state.requiresRectangular = true
            case "widespacing":
                guard let thresholdValue = rule.thresholdValue else {
                    break
                }
                state.wideWidthThreshold = min(state.wideWidthThreshold ?? thresholdValue, thresholdValue)
                state.wideSpacing = max(state.wideSpacing ?? 0, rule.value)
            case "exact_overlap":
                for secondaryLayerName in rule.secondaryLayerNames {
                    states[secondaryLayerName] = states[secondaryLayerName] ?? LayerRuleState()
                }
            case "angles":
                state.allowedAngleStepDegrees = max(state.allowedAngleStepDegrees ?? 0, rule.value)
            case "cifmaxwidth":
                state.minEnclosedArea = max(state.minEnclosedArea ?? 0, rule.value)
            default:
                break
            }
            states[rule.layerName] = state
            for secondaryLayerName in rule.secondaryLayerNames {
                states[secondaryLayerName] = states[secondaryLayerName] ?? LayerRuleState()
            }
        }
        return states
    }

    private struct EnclosureRuleKey: Hashable {
        var outerLayerName: String
        var innerLayerName: String
    }

    private struct SpacingRuleKey: Hashable {
        var firstLayerName: String
        var secondLayerName: String
    }

    static func aggregateSpacingRules(
        _ importedRules: [MagicDRCImportedRule],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutSpacingRule] {
        var minimumSpacingByKey: [SpacingRuleKey: Double] = [:]
        for rule in importedRules where rule.family == "spacing" {
            guard let secondaryLayerName = rule.secondaryLayerName,
                  secondaryLayerName != rule.layerName else {
                continue
            }
            let key = canonicalSpacingRuleKey(rule.layerName, secondaryLayerName, profile: profile)
            minimumSpacingByKey[key] = max(minimumSpacingByKey[key] ?? 0, rule.value)
        }
        return minimumSpacingByKey
            .map { entry in
                LayoutSpacingRule(
                    id: "magicSpacing.\(entry.key.firstLayerName).\(entry.key.secondLayerName)",
                    primaryLayer: layerID(for: entry.key.firstLayerName, profile: profile),
                    secondaryLayer: layerID(for: entry.key.secondLayerName, profile: profile),
                    minSpacing: entry.value
                )
            }
            .sorted {
                if $0.primaryLayer.name == $1.primaryLayer.name {
                    return layerSortKey($0.secondaryLayer.name, $1.secondaryLayer.name, profile: profile)
                }
                return layerSortKey($0.primaryLayer.name, $1.primaryLayer.name, profile: profile)
            }
    }

    private static func canonicalSpacingRuleKey(
        _ first: String,
        _ second: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> SpacingRuleKey {
        if first == second || layerSortKey(first, second, profile: profile) {
            return SpacingRuleKey(firstLayerName: first, secondLayerName: second)
        }
        return SpacingRuleKey(firstLayerName: second, secondLayerName: first)
    }

    static func aggregateDerivedLayerRules(
        layerStates: [String: LayerRuleState],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutDerivedLayerRule] {
        profile.derivedLayerSeeds
            .filter { layerStates[$0.targetLayerName] != nil }
            .compactMap { seed in
                guard let operation = LayoutDerivedLayerRule.Operation(rawValue: seed.operation) else {
                    return nil
                }
                return LayoutDerivedLayerRule(
                    id: seed.id,
                    targetLayer: layerID(for: seed.targetLayerName, profile: profile),
                    sourceLayers: seed.sourceLayerNames.map { layerID(for: $0, profile: profile) },
                    operation: operation
                )
            }
    }

    static func aggregateEnclosureRules(
        _ importedRules: [MagicDRCImportedRule],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutEnclosureRule] {
        var minimumEnclosureByKey: [EnclosureRuleKey: Double] = [:]
        for rule in importedRules where rule.family == "surround" {
            guard let innerLayerName = rule.secondaryLayerName else {
                continue
            }
            let key = EnclosureRuleKey(
                outerLayerName: rule.layerName,
                innerLayerName: innerLayerName
            )
            minimumEnclosureByKey[key] = max(minimumEnclosureByKey[key] ?? 0, rule.value)
        }
        return minimumEnclosureByKey
            .map { entry in
                LayoutEnclosureRule(
                    outerLayer: layerID(for: entry.key.outerLayerName, profile: profile),
                    innerLayer: layerID(for: entry.key.innerLayerName, profile: profile),
                    minEnclosure: entry.value
                )
            }
            .sorted {
                if $0.outerLayer.name == $1.outerLayer.name {
                    return layerSortKey($0.innerLayer.name, $1.innerLayer.name, profile: profile)
                }
                return layerSortKey($0.outerLayer.name, $1.outerLayer.name, profile: profile)
            }
    }

    private enum InterconnectKind: String, Sendable, Hashable {
        case via
        case contact
    }

    private struct CutStackConnection: Sendable, Hashable {
        var id: String
        var cutLayerName: String
        var bottomLayerName: String
        var topLayerName: String
        var kind: InterconnectKind
        var minimumCutCount: Int?
    }

    struct InterconnectDefinitions: Sendable, Hashable {
        var vias: [LayoutViaDefinition]
        var contacts: [LayoutContactDefinition]
    }

    static func aggregateInterconnectDefinitions(
        layerStates: [String: LayerRuleState],
        enclosureRules: [LayoutEnclosureRule],
        sourceContactDefinitions: [SourceContactDefinition],
        sourceContactStacks: [MagicDRCSourceContactStack],
        availableLayerNames: Set<String>,
        profile: MagicDRCLayoutTechImportProfile
    ) -> InterconnectDefinitions {
        var vias: [LayoutViaDefinition] = []
        var contacts: [LayoutContactDefinition] = []
        let sourceContactByID = Dictionary(uniqueKeysWithValues: sourceContactDefinitions.map { ($0.id, $0) })

        for connection in cutStackConnections(profile: profile, sourceContactStacks: sourceContactStacks) {
            guard availableLayerNames.contains(connection.cutLayerName),
                  availableLayerNames.contains(connection.bottomLayerName),
                  availableLayerNames.contains(connection.topLayerName) else {
                continue
            }
            let sourceContact = matchingSourceContact(
                for: connection,
                in: sourceContactByID
            )
            guard let cutWidth = sourceContact?.cutSize ?? layerStates[connection.cutLayerName]?.minWidth else {
                continue
            }
            let cutSpacing = layerStates[connection.cutLayerName]?.minSpacing ?? 0
            guard let bottomEnclosure = sourceContact?.bottomEnclosure ?? enclosureValue(
                outerLayerName: connection.bottomLayerName,
                innerLayerName: connection.cutLayerName,
                enclosureRules: enclosureRules
            ),
                  let topEnclosure = sourceContact?.topEnclosure ?? enclosureValue(
                      outerLayerName: connection.topLayerName,
                      innerLayerName: connection.cutLayerName,
                      enclosureRules: enclosureRules
                  ) else {
                continue
            }

            let cutLayer = layerID(for: connection.cutLayerName, profile: profile)
            let bottomLayer = layerID(for: connection.bottomLayerName, profile: profile)
            let topLayer = layerID(for: connection.topLayerName, profile: profile)
            let cutSize = LayoutSize(width: cutWidth, height: cutWidth)
            let enclosure = LayoutViaEnclosure(top: topEnclosure, bottom: bottomEnclosure)

            switch connection.kind {
            case .via:
                vias.append(LayoutViaDefinition(
                    id: connection.id,
                    cutLayer: cutLayer,
                    topLayer: topLayer,
                    bottomLayer: bottomLayer,
                    cutSize: cutSize,
                    enclosure: enclosure,
                    cutSpacing: cutSpacing
                ))
            case .contact:
                contacts.append(LayoutContactDefinition(
                    id: connection.id,
                    cutLayer: cutLayer,
                    bottomLayer: bottomLayer,
                    topLayer: topLayer,
                    cutSize: cutSize,
                    enclosure: enclosure,
                    cutSpacing: cutSpacing
                ))
            }
        }

        return InterconnectDefinitions(vias: vias, contacts: contacts)
    }

    private static func cutStackConnections(
        profile: MagicDRCLayoutTechImportProfile
    ) -> [CutStackConnection] {
        return profile.cutStackConnections.compactMap { connection in
            guard let kind = InterconnectKind(rawValue: connection.kind) else {
                return nil
            }
            return CutStackConnection(
                id: connection.id,
                cutLayerName: connection.cutLayerName,
                bottomLayerName: connection.bottomLayerName,
                topLayerName: connection.topLayerName,
                kind: kind,
                minimumCutCount: connection.minimumCutCount
            )
        }
    }

    private static func cutStackConnections(
        profile: MagicDRCLayoutTechImportProfile,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> [CutStackConnection] {
        var connections = cutStackConnections(profile: profile)
        var seenKeys = Set(connections.map {
            "\($0.cutLayerName)|\($0.bottomLayerName)|\($0.topLayerName)"
        })

        for stack in sourceContactStacks {
            let key = "\(stack.cutLayerName)|\(stack.bottomLayerName)|\(stack.topLayerName)"
            guard seenKeys.insert(key).inserted else {
                continue
            }
            let matchingProfileConnection = connections.first {
                $0.id == stack.id || $0.cutLayerName == stack.cutLayerName
            }
            connections.append(CutStackConnection(
                id: stack.id,
                cutLayerName: stack.cutLayerName,
                bottomLayerName: stack.bottomLayerName,
                topLayerName: stack.topLayerName,
                kind: matchingProfileConnection?.kind ?? .via,
                minimumCutCount: matchingProfileConnection?.minimumCutCount
            ))
        }

        return connections.sorted {
            if $0.cutLayerName == $1.cutLayerName {
                if $0.bottomLayerName == $1.bottomLayerName {
                    if $0.topLayerName == $1.topLayerName {
                        return $0.id < $1.id
                    }
                    return layerSortKey($0.topLayerName, $1.topLayerName, profile: profile)
                }
                return layerSortKey($0.bottomLayerName, $1.bottomLayerName, profile: profile)
            }
            return layerSortKey($0.cutLayerName, $1.cutLayerName, profile: profile)
        }
    }

    static func profileMinimumCutPolicies(
        profile: MagicDRCLayoutTechImportProfile
    ) -> [MagicDRCProfileMinimumCutPolicy] {
        cutStackConnections(profile: profile)
            .compactMap { connection in
                guard let minimumCutCount = connection.minimumCutCount,
                      minimumCutCount > 1 else {
                    return nil
                }
                return MagicDRCProfileMinimumCutPolicy(
                    id: "profileMinimumCut.\(connection.id)",
                    interconnectID: connection.id,
                    cutLayerName: connection.cutLayerName,
                    bottomLayerName: connection.bottomLayerName,
                    topLayerName: connection.topLayerName,
                    minimumCount: minimumCutCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.cutLayerName == rhs.cutLayerName {
                    if lhs.bottomLayerName == rhs.bottomLayerName {
                        if lhs.topLayerName == rhs.topLayerName {
                            return lhs.id < rhs.id
                        }
                        return layerSortKey(lhs.topLayerName, rhs.topLayerName, profile: profile)
                    }
                    return layerSortKey(lhs.bottomLayerName, rhs.bottomLayerName, profile: profile)
                }
                return layerSortKey(lhs.cutLayerName, rhs.cutLayerName, profile: profile)
            }
    }

    private static func matchingSourceContact(
        for connection: CutStackConnection,
        in definitions: [String: SourceContactDefinition]
    ) -> SourceContactDefinition? {
        guard let definition = definitions[connection.id],
              definition.cutLayerName == connection.cutLayerName,
              definition.bottomLayerName == connection.bottomLayerName,
              definition.topLayerName == connection.topLayerName else {
            return nil
        }
        return definition
    }

    static func interconnectID(
        forCutLayer cutLayerName: String,
        bottomLayerName: String,
        topLayerName: String? = nil,
        sourceContactStacks: [MagicDRCSourceContactStack] = [],
        profile: MagicDRCLayoutTechImportProfile
    ) -> String {
        if let stack = sourceContactStacks.first(where: {
            $0.cutLayerName == cutLayerName
                && $0.bottomLayerName == bottomLayerName
                && (topLayerName == nil || $0.topLayerName == topLayerName)
        }) {
            return stack.id
        }
        if let connection = cutStackConnections(profile: profile).first(where: {
            $0.cutLayerName == cutLayerName
                && $0.bottomLayerName == bottomLayerName
                && (topLayerName == nil || $0.topLayerName == topLayerName)
        }) {
            return connection.id
        }
        return cutLayerNames(profile: profile).contains(cutLayerName) ? cutLayerName : "\(cutLayerName)_\(bottomLayerName)"
    }

    private static func enclosureValue(
        outerLayerName: String,
        innerLayerName: String,
        enclosureRules: [LayoutEnclosureRule]
    ) -> Double? {
        enclosureRules.first {
            $0.outerLayer.name == outerLayerName && $0.innerLayer.name == innerLayerName
        }?.minEnclosure
    }

    static func aggregateMinimumCutRules(
        _ definitions: InterconnectDefinitions,
        sourceMinimumCutPolicies: [MagicDRCSourceMinimumCutPolicy],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutMinimumCutRule] {
        let viaRules = definitions.vias.map { definition in
            LayoutMinimumCutRule(
                id: "mincut.\(definition.id)",
                cutLayer: definition.cutLayer,
                bottomLayer: definition.bottomLayer,
                topLayer: definition.topLayer,
                minimumCount: minimumCutCount(
                    forInterconnectID: definition.id,
                    sourceMinimumCutPolicies: sourceMinimumCutPolicies,
                    profile: profile
                )
            )
        }
        let contactRules = definitions.contacts.map { definition in
            LayoutMinimumCutRule(
                id: "mincut.\(definition.id)",
                cutLayer: definition.cutLayer,
                bottomLayer: definition.bottomLayer,
                topLayer: definition.topLayer,
                minimumCount: minimumCutCount(
                    forInterconnectID: definition.id,
                    sourceMinimumCutPolicies: sourceMinimumCutPolicies,
                    profile: profile
                )
            )
        }
        return (viaRules + contactRules).sorted { lhs, rhs in
            if lhs.cutLayer.name == rhs.cutLayer.name {
                if lhs.bottomLayer.name == rhs.bottomLayer.name {
                    if lhs.topLayer.name == rhs.topLayer.name {
                        return lhs.id < rhs.id
                    }
                    return layerSortKey(lhs.topLayer.name, rhs.topLayer.name, profile: profile)
                }
                return layerSortKey(lhs.bottomLayer.name, rhs.bottomLayer.name, profile: profile)
            }
            return layerSortKey(lhs.cutLayer.name, rhs.cutLayer.name, profile: profile)
        }
    }

    private static func minimumCutCount(
        forInterconnectID id: String,
        sourceMinimumCutPolicies: [MagicDRCSourceMinimumCutPolicy],
        profile: MagicDRCLayoutTechImportProfile
    ) -> Int {
        let sourceCount = sourceMinimumCutPolicies
            .first { $0.interconnectID == id }?
            .minimumCount
        if let sourceCount, sourceCount > 0 {
            return sourceCount
        }
        let explicitCount = cutStackConnections(profile: profile)
            .first { $0.id == id }?
            .minimumCutCount
        guard let explicitCount, explicitCount > 1 else {
            return 1
        }
        return explicitCount
    }

    static func aggregateExactOverlapRules(
        _ sourceRules: [MagicDRCSourceExactOverlapRule],
        availableLayerNames: Set<String>,
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutExactOverlapRule] {
        sourceRules.compactMap { sourceRule in
            guard availableLayerNames.contains(sourceRule.primaryLayerName),
                  sourceRule.secondaryLayerNames.allSatisfy({ availableLayerNames.contains($0) }) else {
                return nil
            }
            return LayoutExactOverlapRule(
                id: sourceRule.id,
                primaryLayer: layerID(for: sourceRule.primaryLayerName, profile: profile),
                secondaryLayers: sourceRule.secondaryLayerNames.map { layerID(for: $0, profile: profile) }
            )
        }
    }

    static func aggregateForbiddenLayerRules(
        _ sourceRules: [MagicDRCSourceForbiddenMarkerRule]
    ) -> [LayoutForbiddenLayerRule] {
        sourceRules.map { sourceRule in
            LayoutForbiddenLayerRule(
                id: sourceRule.id,
                layer: markerLayerID(for: sourceRule.markerLayerName),
                reason: sourceRule.reason
            )
        }
    }

    private struct ExtensionRuleKey: Hashable {
        var extendingLayerName: String
        var enclosedLayerName: String
        var direction: LayoutExtensionRule.Direction
    }

    static func aggregateExtensionRules(
        _ importedRules: [MagicDRCImportedRule],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [LayoutExtensionRule] {
        var minimumExtensionByKey: [ExtensionRuleKey: Double] = [:]
        for rule in importedRules where rule.family == "overhang" {
            guard let enclosedLayerName = rule.secondaryLayerName else {
                continue
            }
            for direction in [LayoutExtensionRule.Direction.horizontal, .vertical] {
                let key = ExtensionRuleKey(
                    extendingLayerName: rule.layerName,
                    enclosedLayerName: enclosedLayerName,
                    direction: direction
                )
                minimumExtensionByKey[key] = max(minimumExtensionByKey[key] ?? 0, rule.value)
            }
        }
        return minimumExtensionByKey
            .map { entry in
                LayoutExtensionRule(
                    extendingLayer: layerID(for: entry.key.extendingLayerName, profile: profile),
                    enclosedLayer: layerID(for: entry.key.enclosedLayerName, profile: profile),
                    minExtension: entry.value,
                    direction: entry.key.direction
                )
            }
            .sorted {
                if $0.extendingLayer.name == $1.extendingLayer.name {
                    if $0.enclosedLayer.name == $1.enclosedLayer.name {
                        return $0.direction.rawValue < $1.direction.rawValue
                    }
                    return layerSortKey($0.enclosedLayer.name, $1.enclosedLayer.name, profile: profile)
                }
                return layerSortKey($0.extendingLayer.name, $1.extendingLayer.name, profile: profile)
            }
    }

}
