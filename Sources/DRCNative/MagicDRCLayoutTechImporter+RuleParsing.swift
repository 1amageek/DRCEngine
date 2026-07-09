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
            guard let rawCommand = tokens.first else { continue }
            let command = rawCommand.lowercased()
            if command == "drc" {
                inDRC = true
                continue
            }
            if inDRC && command == "end" {
                inDRC = false
                continue
            }
            guard inDRC else {
                continue
            }
            guard observedRuleFamilies.contains(command) else {
                skip(
                    line: line,
                    family: command,
                    code: "unsupported_magic_drc_family",
                    state: &state
                )
                continue
            }
            guard supportedRuleFamilies.contains(command) else {
                skip(
                    line: line,
                    family: command,
                    code: "unsupported_magic_drc_family",
                    state: &state
                )
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
        let parseResult = parseMinimumCutArguments(
            tokens: tokens,
            resolver: resolver,
            sourceContactStacks: sourceContactStacks
        )
        let arguments: [MinimumCutArguments]
        switch parseResult {
        case .parsed(let parsedArguments):
            arguments = parsedArguments
        case .failed(let code):
            skip(line: line, family: "minimum_cut", code: code, state: &state)
            return
        }
        for argument in arguments {
            let connectionID = interconnectID(
                forCutLayer: argument.cutLayerName,
                bottomLayerName: argument.bottomLayerName,
                topLayerName: argument.topLayerName,
                sourceContactStacks: sourceContactStacks,
                profile: resolver.profile
            )
            appendSourceMinimumCutPolicy(
                MagicDRCSourceMinimumCutPolicy(
                    id: sourceMinimumCutPolicyID(interconnectID: connectionID),
                    interconnectID: connectionID,
                    cutLayerName: argument.cutLayerName,
                    bottomLayerName: argument.bottomLayerName,
                    topLayerName: argument.topLayerName,
                    minimumCount: argument.minimumCount,
                    sourceLineNumber: line.lineNumber,
                    sourceLine: line.text
                ),
                profile: resolver.profile,
                state: &state
            )
            appendImportedRule(
                family: "minimum_cut",
                layerName: argument.cutLayerName,
                secondaryLayerNames: [argument.bottomLayerName, argument.topLayerName],
                value: Double(argument.minimumCount),
                line: line,
                state: &state
            )
        }
    }

    private struct MinimumCutArguments: Sendable, Hashable {
        let cutLayerName: String
        let bottomLayerName: String
        let topLayerName: String
        let minimumCount: Int
    }

    private enum MinimumCutParseResult: Sendable, Hashable {
        case parsed([MinimumCutArguments])
        case failed(String)
    }

    private enum MinimumCutElement: Sendable, Hashable {
        case layer(String)
        case count(Int)
    }

    private static func parseMinimumCutArguments(
        tokens: [String],
        resolver: LayerResolver,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> MinimumCutParseResult {
        let ignoredTokens: Set<String> = [
            "at_least",
            "atleast",
            "between",
            "count",
            "cuts",
            "minimum",
            "min",
            "on",
            "require",
            "requires",
            "with",
        ]
        var elements: [MinimumCutElement] = []
        for token in tokens.dropFirst() {
            if let count = parsePositiveInteger(token) {
                elements.append(.count(count))
                continue
            }
            if ignoredTokens.contains(normalizedToken(token)) {
                continue
            }
            guard let layerName = resolver.resolve(token) else {
                return .failed("magic_drc_minimum_cut_layers_unresolved")
            }
            elements.append(.layer(layerName))
        }

        let cutLayerNameSet = cutLayerNames(profile: resolver.profile)
        if let explicitArguments = parseExplicitMinimumCutGroups(
            elements: elements,
            cutLayerNames: cutLayerNameSet
        ) {
            return .parsed(explicitArguments)
        }

        let countCandidates = elements.compactMap { element -> Int? in
            if case .count(let count) = element {
                return count
            }
            return nil
        }
        guard countCandidates.count == 1,
              let minimumCount = countCandidates.first else {
            return .failed("magic_drc_minimum_cut_count_ambiguous")
        }

        let resolvedLayerNames = elements.compactMap { element -> String? in
            if case .layer(let layerName) = element {
                return layerName
            }
            return nil
        }
        let cutLayerCandidates = resolvedLayerNames.filter { cutLayerNameSet.contains($0) }
        guard cutLayerCandidates.count == 1,
              let cutLayerName = cutLayerCandidates.first else {
            return .failed("magic_drc_minimum_cut_layers_unresolved")
        }
        let conductorLayerNames = resolvedLayerNames.filter { $0 != cutLayerName }
        if conductorLayerNames.count >= 2 {
            return .parsed([MinimumCutArguments(
                cutLayerName: cutLayerName,
                bottomLayerName: conductorLayerNames[0],
                topLayerName: conductorLayerNames[1],
                minimumCount: minimumCount
            )])
        }
        guard let inferred = inferMinimumCutConnection(
            cutLayerName: cutLayerName,
            conductorLayerNames: conductorLayerNames,
            profile: resolver.profile,
            sourceContactStacks: sourceContactStacks
        ) else {
            return .failed("magic_drc_minimum_cut_stack_ambiguous")
        }
        return .parsed([MinimumCutArguments(
            cutLayerName: cutLayerName,
            bottomLayerName: inferred.bottomLayerName,
            topLayerName: inferred.topLayerName,
            minimumCount: minimumCount
        )])
    }

    private static func parseExplicitMinimumCutGroups(
        elements: [MinimumCutElement],
        cutLayerNames: Set<String>
    ) -> [MinimumCutArguments]? {
        guard !elements.isEmpty else { return nil }
        var index = 0
        var defaultCutLayerName: String?
        if case .layer(let firstLayerName) = elements[0], cutLayerNames.contains(firstLayerName) {
            defaultCutLayerName = firstLayerName
            index = 1
        }

        var arguments: [MinimumCutArguments] = []
        while index < elements.count {
            var cutLayerName = defaultCutLayerName
            if case .layer(let layerName) = elements[index], cutLayerNames.contains(layerName) {
                cutLayerName = layerName
                index += 1
            }
            guard let cutLayerName else {
                return nil
            }

            if let group = parseMinimumCutGroup(
                elements: elements,
                index: index,
                cutLayerName: cutLayerName,
                cutLayerNames: cutLayerNames
            ) {
                arguments.append(group.argument)
                index = group.nextIndex
            } else {
                return nil
            }
        }
        return arguments.isEmpty ? nil : arguments
    }

    private static func parseMinimumCutGroup(
        elements: [MinimumCutElement],
        index: Int,
        cutLayerName: String,
        cutLayerNames: Set<String>
    ) -> (argument: MinimumCutArguments, nextIndex: Int)? {
        if let firstLayerName = layerName(at: index, in: elements),
           let secondLayerName = layerName(at: index + 1, in: elements),
           let minimumCount = count(at: index + 2, in: elements),
           !cutLayerNames.contains(firstLayerName),
           !cutLayerNames.contains(secondLayerName) {
            return (
                MinimumCutArguments(
                    cutLayerName: cutLayerName,
                    bottomLayerName: firstLayerName,
                    topLayerName: secondLayerName,
                    minimumCount: minimumCount
                ),
                index + 3
            )
        }

        if let minimumCount = count(at: index, in: elements),
           let firstLayerName = layerName(at: index + 1, in: elements),
           let secondLayerName = layerName(at: index + 2, in: elements),
           !cutLayerNames.contains(firstLayerName),
           !cutLayerNames.contains(secondLayerName) {
            return (
                MinimumCutArguments(
                    cutLayerName: cutLayerName,
                    bottomLayerName: firstLayerName,
                    topLayerName: secondLayerName,
                    minimumCount: minimumCount
                ),
                index + 3
            )
        }
        return nil
    }

    private static func layerName(at index: Int, in elements: [MinimumCutElement]) -> String? {
        guard elements.indices.contains(index),
              case .layer(let layerName) = elements[index] else {
            return nil
        }
        return layerName
    }

    private static func count(at index: Int, in elements: [MinimumCutElement]) -> Int? {
        guard elements.indices.contains(index),
              case .count(let count) = elements[index] else {
            return nil
        }
        return count
    }

    private static func inferMinimumCutConnection(
        cutLayerName: String,
        conductorLayerNames: [String],
        profile: MagicDRCLayoutTechImportProfile,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> (bottomLayerName: String, topLayerName: String)? {
        let profileMatches = profile.cutStackConnections.compactMap { connection -> (String, String)? in
            guard connection.cutLayerName == cutLayerName else { return nil }
            return (connection.bottomLayerName, connection.topLayerName)
        }
        let sourceMatches = sourceContactStacks.compactMap { stack -> (String, String)? in
            guard stack.cutLayerName == cutLayerName else { return nil }
            return (stack.bottomLayerName, stack.topLayerName)
        }
        let matches = uniqueMinimumCutConnections(profileMatches + sourceMatches)
        let filtered = conductorLayerNames.isEmpty
            ? matches
            : matches.filter { match in
                conductorLayerNames.allSatisfy {
                    $0 == match.bottomLayerName || $0 == match.topLayerName
                }
            }
        guard filtered.count == 1 else {
            return nil
        }
        return filtered[0]
    }

    private static func uniqueMinimumCutConnections(
        _ connections: [(bottomLayerName: String, topLayerName: String)]
    ) -> [(bottomLayerName: String, topLayerName: String)] {
        var seen: Set<String> = []
        var result: [(bottomLayerName: String, topLayerName: String)] = []
        for connection in connections {
            let key = "\(connection.bottomLayerName)|\(connection.topLayerName)"
            guard seen.insert(key).inserted else {
                continue
            }
            result.append(connection)
        }
        return result
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
