import Foundation
import LayoutCore
import LayoutTech
import DRCFoundryImport

extension MagicDRCLayoutTechImporter {
    static func parseDRCRules(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver,
        tempLayerDefinitions: [String: LogicalLine],
        enclosedHoleSeeds: [String: SourceEnclosedHoleSeed],
        materializableTempLayerNames: Set<String>,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> ParsedRuleState {
        var state = ParsedRuleState()
        var inDRC = false
        for line in logicalLines {
            let commandLine = textWithoutQuotedTail(line.text)
            let tokens = splitCommand(commandLine)
            guard let command = tokens.first else { continue }
            if command == "drc" {
                inDRC = true
                continue
            }
            if inDRC && command == "end" {
                inDRC = false
                continue
            }
            guard inDRC, observedRuleFamilies.contains(command) else {
                continue
            }
            guard supportedRuleFamilies.contains(command) else {
                state.skippedFamilyCounts[command, default: 0] += 1
                state.diagnostics.append(MagicDRCImportDiagnostic(
                    code: "unsupported_magic_drc_family",
                    message: "Magic DRC rule family '\(command)' is not representable in the current LayoutTechDatabase seed model yet.",
                    sourceLineNumber: line.lineNumber,
                    sourceLine: line.text
                ))
                continue
            }

            switch command {
            case "width":
                importWidth(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "spacing":
                importSpacing(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "area":
                importArea(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "notch":
                importNotch(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "rect_only":
                importRectOnly(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "surround":
                importSurround(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "widespacing":
                importWideSpacing(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "overhang":
                importOverhang(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "exact_overlap":
                importExactOverlap(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "angles":
                importAngles(tokens: tokens, line: line, resolver: resolver, state: &state)
            case "cifmaxwidth":
                importCIFMaxWidth(
                    tokens: tokens,
                    line: line,
                    tempLayerDefinitions: tempLayerDefinitions,
                    enclosedHoleSeeds: enclosedHoleSeeds,
                    materializableTempLayerNames: materializableTempLayerNames,
                    profile: resolver.profile,
                    state: &state
                )
            case "minimumcut", "minimum_cut", "mincut", "cutcount", "cut_count":
                importMinimumCut(
                    tokens: tokens,
                    line: line,
                    resolver: resolver,
                    sourceContactStacks: sourceContactStacks,
                    state: &state
                )
            default:
                break
            }
        }
        return state
    }

    private static func importWidth(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 3, let value = Double(tokens[2]) else {
            skip(line: line, family: "width", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "width", code: "magic_drc_layer_unresolved", state: &state)
            return
        }
        for layerName in layerNames {
            appendImportedRule(
                family: "width",
                layerName: layerName,
                value: value / 1_000,
                line: line,
                state: &state
            )
        }
    }

    private static func importSpacing(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 4, let value = Double(tokens[3]) else {
            skip(line: line, family: "spacing", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let firstLayerNames = resolver.resolveLayerSet(tokens[1])
        let secondLayerNames = resolver.resolveLayerSet(tokens[2])
        guard !firstLayerNames.isEmpty, !secondLayerNames.isEmpty else {
            skip(line: line, family: "spacing", code: "magic_drc_layer_pair_unresolved", state: &state)
            return
        }
        for layerName in firstLayerNames {
            for secondLayerName in secondLayerNames {
                appendImportedRule(
                    family: "spacing",
                    layerName: layerName,
                    secondaryLayerName: layerName == secondLayerName ? nil : secondLayerName,
                    value: value / 1_000,
                    line: line,
                    state: &state
                )
            }
        }
    }

    private static func importArea(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 3, let value = Double(tokens[2]) else {
            skip(line: line, family: "area", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "area", code: "magic_drc_layer_unresolved", state: &state)
            return
        }
        for layerName in layerNames {
            appendImportedRule(
                family: "area",
                layerName: layerName,
                value: value / 1_000_000,
                line: line,
                state: &state
            )
        }
    }

    private static func importNotch(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 3, let value = Double(tokens[2]) else {
            skip(line: line, family: "notch", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "notch", code: "magic_drc_layer_unresolved", state: &state)
            return
        }
        for layerName in layerNames {
            appendImportedRule(
                family: "notch",
                layerName: layerName,
                value: value / 1_000,
                line: line,
                state: &state
            )
        }
    }

    private static func importSurround(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 4, let value = Double(tokens[3]) else {
            skip(line: line, family: "surround", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let innerLayerNames = resolver.resolveLayerSet(tokens[1])
        let outerLayerNames = resolver.resolveLayerSet(tokens[2])
        guard !innerLayerNames.isEmpty, !outerLayerNames.isEmpty else {
            skip(line: line, family: "surround", code: "magic_drc_layer_pair_unresolved", state: &state)
            return
        }
        for innerLayerName in innerLayerNames {
            for outerLayerName in outerLayerNames {
                appendImportedRule(
                    family: "surround",
                    layerName: outerLayerName,
                    secondaryLayerName: innerLayerName,
                    value: value / 1_000,
                    line: line,
                    state: &state
                )
            }
        }
    }

    private static func importRectOnly(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 2 else {
            skip(line: line, family: "rect_only", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "rect_only", code: "magic_drc_layer_unresolved", state: &state)
            return
        }
        for layerName in layerNames {
            appendImportedRule(
                family: "rect_only",
                layerName: layerName,
                value: 1,
                line: line,
                state: &state
            )
        }
    }

    private static func importWideSpacing(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 4,
              let threshold = Double(tokens[2]) else {
            skip(line: line, family: "widespacing", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "widespacing", code: "magic_drc_layer_unresolved", state: &state)
            return
        }

        let spacingToken: String
        if tokens.count >= 5 {
            let secondaryLayerNames = resolver.resolveLayerSet(tokens[3])
            guard !secondaryLayerNames.isEmpty,
                  secondaryLayerNames == layerNames else {
                skip(line: line, family: "widespacing", code: "magic_drc_layer_pair_unresolved", state: &state)
                return
            }
            spacingToken = tokens[4]
        } else {
            spacingToken = tokens[3]
        }
        guard let spacing = Double(spacingToken) else {
            skip(line: line, family: "widespacing", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }

        for layerName in layerNames {
            appendImportedRule(
                family: "widespacing",
                layerName: layerName,
                thresholdValue: threshold / 1_000,
                value: spacing / 1_000,
                line: line,
                state: &state
            )
        }
    }

    private static func importOverhang(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 4, let value = Double(tokens[3]) else {
            skip(line: line, family: "overhang", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let extendingLayerNames = resolver.resolveLayerSet(tokens[1])
        let enclosedLayerNames = resolver.resolveLayerSet(tokens[2])
        guard !extendingLayerNames.isEmpty, !enclosedLayerNames.isEmpty else {
            skip(line: line, family: "overhang", code: "magic_drc_layer_pair_unresolved", state: &state)
            return
        }
        for extendingLayerName in extendingLayerNames {
            for enclosedLayerName in enclosedLayerNames {
                appendImportedRule(
                    family: "overhang",
                    layerName: extendingLayerName,
                    secondaryLayerName: enclosedLayerName,
                    value: value / 1_000,
                    line: line,
                    state: &state
                )
            }
        }
    }

    private static func importExactOverlap(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 2,
              let pairs = parseExactOverlapExpressions(tokens[1], resolver: resolver) else {
            skip(line: line, family: "exact_overlap", code: "magic_drc_layer_pair_unresolved", state: &state)
            return
        }
        for pair in pairs {
            appendImportedRule(
                family: "exact_overlap",
                layerName: pair.primaryLayerName,
                secondaryLayerName: pair.secondaryLayerNames.first,
                secondaryLayerNames: pair.secondaryLayerNames,
                value: 0,
                line: line,
                state: &state
            )
        }
    }

    private static func importAngles(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 3,
              let step = Double(tokens[2]),
              step.isFinite,
              step > 0,
              step <= 180 else {
            skip(line: line, family: "angles", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        let layerNames = resolver.resolveLayerSet(tokens[1])
        guard !layerNames.isEmpty else {
            skip(line: line, family: "angles", code: "magic_drc_layer_unresolved", state: &state)
            return
        }
        for layerName in layerNames {
            appendImportedRule(
                family: "angles",
                layerName: layerName,
                value: step,
                line: line,
                state: &state
            )
        }
    }

    private static func importCIFMaxWidth(
        tokens: [String],
        line: LogicalLine,
        tempLayerDefinitions: [String: LogicalLine],
        enclosedHoleSeeds: [String: SourceEnclosedHoleSeed],
        materializableTempLayerNames: Set<String>,
        profile: MagicDRCLayoutTechImportProfile,
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 3,
              let maximumWidth = Double(tokens[2]),
              maximumWidth.isFinite else {
            skip(line: line, family: "cifmaxwidth", code: "magic_drc_rule_parse_failed", state: &state)
            return
        }
        guard abs(maximumWidth) < 0.000000001 else {
            skip(
                line: line,
                family: "cifmaxwidth",
                code: "magic_drc_cifmaxwidth_not_zero_marker",
                state: &state
            )
            return
        }
        guard let seed = enclosedHoleSeeds[tokens[1]] else {
            let isMaterialized = materializableTempLayerNames.contains(tokens[1])
            appendSourceForbiddenMarkerRule(
                markerLayerName: tokens[1],
                line: line,
                definitionLine: tempLayerDefinitions[tokens[1]],
                isMaterialized: isMaterialized,
                profile: profile,
                state: &state
            )
            return
        }

        appendImportedRule(
            family: "cifmaxwidth",
            layerName: seed.layerName,
            value: seed.minimumArea,
            line: line,
            state: &state
        )
        let sourceRule = MagicDRCSourceEnclosedHoleRule(
            id: seed.id,
            layerName: seed.layerName,
            holeLayerName: seed.holeLayerName,
            smallHoleLayerName: seed.smallHoleLayerName,
            minimumArea: seed.minimumArea,
            sourceLineNumber: line.lineNumber,
            sourceLine: line.text,
            definitionLineNumber: seed.definitionLineNumber,
            definitionLine: seed.definitionLine
        )
        guard !state.sourceEnclosedHoleRules.contains(where: { $0.id == sourceRule.id }) else {
            return
        }
        state.sourceEnclosedHoleRules.append(sourceRule)
        state.sourceEnclosedHoleRules.sort {
            layerSortKey($0.layerName, $1.layerName, profile: profile)
        }
    }

    private static func importMinimumCut(
        tokens: [String],
        line: LogicalLine,
        resolver: LayerResolver,
        sourceContactStacks: [MagicDRCSourceContactStack],
        state: inout ParsedRuleState
    ) {
        guard tokens.count >= 5,
              let minimumCount = parsePositiveInteger(tokens[4]),
              minimumCount > 0 else {
            skip(line: line, family: "minimum_cut", code: "magic_drc_minimum_cut_parse_failed", state: &state)
            return
        }
        guard let cutLayerName = resolver.resolve(tokens[1]),
              cutLayerNames(profile: resolver.profile).contains(cutLayerName),
              let bottomLayerName = resolver.resolve(tokens[2]),
              let topLayerName = resolver.resolve(tokens[3]) else {
            skip(line: line, family: "minimum_cut", code: "magic_drc_minimum_cut_layers_unresolved", state: &state)
            return
        }

        let connectionID = interconnectID(
            forCutLayer: cutLayerName,
            bottomLayerName: bottomLayerName,
            topLayerName: topLayerName,
            sourceContactStacks: sourceContactStacks,
            profile: resolver.profile
        )
        appendSourceMinimumCutPolicy(
            MagicDRCSourceMinimumCutPolicy(
                id: sourceMinimumCutPolicyID(interconnectID: connectionID),
                interconnectID: connectionID,
                cutLayerName: cutLayerName,
                bottomLayerName: bottomLayerName,
                topLayerName: topLayerName,
                minimumCount: minimumCount,
                sourceLineNumber: line.lineNumber,
                sourceLine: line.text
            ),
            profile: resolver.profile,
            state: &state
        )
        appendImportedRule(
            family: "minimum_cut",
            layerName: cutLayerName,
            secondaryLayerNames: [bottomLayerName, topLayerName],
            value: Double(minimumCount),
            line: line,
            state: &state
        )
    }

    private static func parsePositiveInteger(_ token: String) -> Int? {
        guard let value = Double(token), value.isFinite, value > 0 else {
            return nil
        }
        let rounded = value.rounded()
        guard abs(value - rounded) < 0.000000001 else {
            return nil
        }
        return Int(rounded)
    }

    private static func appendSourceMinimumCutPolicy(
        _ policy: MagicDRCSourceMinimumCutPolicy,
        profile: MagicDRCLayoutTechImportProfile,
        state: inout ParsedRuleState
    ) {
        if let index = state.sourceMinimumCutPolicies.firstIndex(where: {
            $0.interconnectID == policy.interconnectID
        }) {
            let existing = state.sourceMinimumCutPolicies[index]
            guard policy.minimumCount > existing.minimumCount else {
                return
            }
            state.sourceMinimumCutPolicies[index] = policy
        } else {
            state.sourceMinimumCutPolicies.append(policy)
        }
        state.sourceMinimumCutPolicies.sort {
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

    private static func appendSourceForbiddenMarkerRule(
        markerLayerName: String,
        line: LogicalLine,
        definitionLine: LogicalLine?,
        isMaterialized: Bool,
        profile: MagicDRCLayoutTechImportProfile,
        state: inout ParsedRuleState
    ) {
        let rule = MagicDRCSourceForbiddenMarkerRule(
            id: forbiddenMarkerRuleID(markerLayerName: markerLayerName),
            markerLayerName: markerLayerName,
            sourceLineNumber: line.lineNumber,
            sourceLine: line.text,
            definitionLineNumber: definitionLine?.lineNumber,
            definitionLine: definitionLine?.text,
            reason: quotedMessage(from: line.text) ?? "Magic DRC marker layer must be empty."
        )
        if !state.sourceForbiddenMarkerRules.contains(where: { $0.id == rule.id }) {
            state.sourceForbiddenMarkerRules.append(rule)
            state.sourceForbiddenMarkerRules.sort {
                layerSortKey($0.markerLayerName, $1.markerLayerName, profile: profile)
            }
        }
        guard !isMaterialized else {
            return
        }
        state.skippedFamilyCounts["cifmaxwidth", default: 0] += 1
        state.diagnostics.append(MagicDRCImportDiagnostic(
            code: "magic_drc_cifmaxwidth_marker_materialization_deferred",
            message: "The Magic DRC cifmaxwidth marker rule was captured as a forbidden marker, but its source templayer uses geometry operations that are not materialized yet.",
            sourceLineNumber: line.lineNumber,
            sourceLine: line.text
        ))
    }

    private static func quotedMessage(from text: String) -> String? {
        guard let first = text.firstIndex(of: "\""),
              let last = text.lastIndex(of: "\""),
              first < last else {
            return nil
        }
        return String(text[text.index(after: first)..<last])
    }

    private static func forbiddenMarkerRuleID(markerLayerName: String) -> String {
        "forbiddenMarker.\(markerLayerName)"
    }

    static func sourceTempLayerDefinitionID(name: String) -> String {
        "tempLayer.\(name)"
    }

    static func sourceTempLayerMaterializedRuleID(name: String) -> String {
        "magic.templayer.\(name)"
    }

    private static func sourceMinimumCutPolicyID(interconnectID: String) -> String {
        "sourceMinimumCut.\(interconnectID)"
    }

    static func sourceTempLayerStepRuleID(name: String, step: Int) -> String {
        "magic.templayer.\(name).step\(step)"
    }

    static func sourceTempLayerDerivedLayerID(name: String) -> LayoutLayerID {
        LayoutLayerID(name: name, purpose: "derived")
    }

    static func sourceTempLayerStepLayerID(name: String, step: Int) -> LayoutLayerID {
        LayoutLayerID(name: "\(name).step\(step)", purpose: "derived")
    }

    private static func appendImportedRule(
        family: String,
        layerName: String,
        secondaryLayerName: String? = nil,
        secondaryLayerNames: [String] = [],
        thresholdValue: Double? = nil,
        value: Double,
        line: LogicalLine,
        state: inout ParsedRuleState
    ) {
        state.importedFamilyCounts[family, default: 0] += 1
        state.importedRules.append(MagicDRCImportedRule(
            family: family,
            layerName: layerName,
            secondaryLayerName: secondaryLayerName,
            secondaryLayerNames: secondaryLayerNames,
            thresholdValue: thresholdValue,
            value: value,
            sourceLineNumber: line.lineNumber,
            sourceLine: line.text
        ))
    }

    private static func skip(
        line: LogicalLine,
        family: String,
        code: String,
        state: inout ParsedRuleState
    ) {
        state.skippedFamilyCounts[family, default: 0] += 1
        state.diagnostics.append(MagicDRCImportDiagnostic(
            code: code,
            message: "The Magic DRC \(family) rule could not be imported into the current LayoutTech rule model.",
            sourceLineNumber: line.lineNumber,
            sourceLine: line.text
        ))
    }

}
