import Foundation
import LayoutCore
import LayoutTech
@_exported import DRCFoundryImport

extension MagicDRCLayoutTechImporter {
    static let sourceTempLayerOperationCommands: Set<String> = [
        "and",
        "and-not",
        "or",
        "grow",
        "grow-min",
        "shrink",
        "bloat-all",
        "bridge",
        "boundary",
        "mask-hints",
        "close",
    ]

    struct SourceTempLayerDefinitionDraft: Sendable, Hashable {
        let name: String
        let sourceLineNumber: Int
        let sourceLine: String
        let initialTerms: [String]
        var operations: [MagicDRCSourceTempLayerOperation]
    }

    struct SourceTempLayerMaterialization: Sendable, Hashable {
        var rules: [LayoutDerivedLayerRule]
        var finalLayer: LayoutLayerID
        var finalRuleID: String
    }

    struct SourceTempLayerDerivedLayerAggregation: Sendable, Hashable {
        var rules: [LayoutDerivedLayerRule]
        var materializedRuleIDs: [String]
    }

    static func parseSourceTempLayerDefinitions(
        from logicalLines: [LogicalLine]
    ) -> [String: LogicalLine] {
        var definitions: [String: LogicalLine] = [:]
        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard tokens.first == "templayer", tokens.count >= 2 else {
                continue
            }
            definitions[tokens[1]] = line
        }
        return definitions
    }

    static func parseSourceTempLayerDefinitionArtifacts(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver
    ) -> [MagicDRCSourceTempLayerDefinition] {
        var orderedNames: [String] = []
        var drafts: [String: SourceTempLayerDefinitionDraft] = [:]
        var activeName: String?

        for line in logicalLines {
            let commandLine = textWithoutQuotedTail(line.text)
            let tokens = splitCommand(commandLine)
            guard let command = tokens.first else {
                continue
            }
            if command == "templayer", tokens.count >= 2 {
                let name = tokens[1]
                if drafts[name] == nil {
                    orderedNames.append(name)
                }
                drafts[name] = SourceTempLayerDefinitionDraft(
                    name: name,
                    sourceLineNumber: line.lineNumber,
                    sourceLine: line.text,
                    initialTerms: tokens.dropFirst(2).flatMap { splitExpressionTerms($0) },
                    operations: []
                )
                activeName = name
                continue
            }

            guard let currentName = activeName else {
                continue
            }
            guard sourceTempLayerOperationCommands.contains(command) else {
                activeName = nil
                continue
            }
            let operation = MagicDRCSourceTempLayerOperation(
                command: command,
                arguments: Array(tokens.dropFirst()),
                sourceLineNumber: line.lineNumber,
                sourceLine: line.text
            )
            drafts[currentName]?.operations.append(operation)
        }

        var definitionNameByToken: [String: String] = [:]
        for name in orderedNames {
            definitionNameByToken[normalizedToken(name)] = name
        }

        return orderedNames.compactMap { name in
            guard let draft = drafts[name] else {
                return nil
            }
            let references = sourceTempLayerReferences(
                initialTerms: draft.initialTerms,
                operations: draft.operations,
                definitionNameByToken: definitionNameByToken,
                resolver: resolver
            )
            return MagicDRCSourceTempLayerDefinition(
                id: sourceTempLayerDefinitionID(name: draft.name),
                name: draft.name,
                sourceLineNumber: draft.sourceLineNumber,
                sourceLine: draft.sourceLine,
                initialTerms: draft.initialTerms,
                operations: draft.operations,
                referencedLayerNames: references.layerNames,
                referencedTempLayerNames: references.tempLayerNames,
                unresolvedReferences: references.unresolvedReferences,
                operationNames: Array(Set(draft.operations.map(\.command))).sorted()
            )
        }
    }

    static func sourceTempLayerReferences(
        initialTerms: [String],
        operations: [MagicDRCSourceTempLayerOperation],
        definitionNameByToken: [String: String],
        resolver: LayerResolver
    ) -> (layerNames: [String], tempLayerNames: [String], unresolvedReferences: [String]) {
        var layerNames: Set<String> = []
        var tempLayerNames: Set<String> = []
        var unresolvedReferences: Set<String> = []
        var terms = initialTerms

        for operation in operations {
            switch operation.command {
            case "and", "and-not", "or", "mask-hints", "bloat-all":
                terms.append(contentsOf: operation.arguments.flatMap { splitExpressionTerms($0) })
            default:
                continue
            }
        }

        for term in terms where !isNumericTerm(term) {
            let token = normalizedToken(term)
            if let tempLayerName = definitionNameByToken[token] {
                tempLayerNames.insert(tempLayerName)
                continue
            }
            let resolvedLayerNames = resolver.resolveAll(term)
            if resolvedLayerNames.isEmpty {
                unresolvedReferences.insert(term)
            } else {
                layerNames.formUnion(resolvedLayerNames)
            }
        }

        return (
            layerNames: layerNames.sorted { layerSortKey($0, $1, profile: resolver.profile) },
            tempLayerNames: tempLayerNames.sorted(),
            unresolvedReferences: unresolvedReferences.sorted()
        )
    }

    static func sourceTempLayerOperationCounts(
        _ definitions: [MagicDRCSourceTempLayerDefinition]
    ) -> [String: Int] {
        var counts: [String: Int] = [:]
        for definition in definitions {
            for operation in definition.operations {
                counts[operation.command, default: 0] += 1
            }
        }
        return counts
    }

    static func aggregateSourceTempLayerDerivedLayerRules(
        definitions: [MagicDRCSourceTempLayerDefinition],
        forbiddenMarkerRules: [MagicDRCSourceForbiddenMarkerRule],
        definitionsByName: [String: MagicDRCSourceTempLayerDefinition],
        resolver: LayerResolver
    ) -> SourceTempLayerDerivedLayerAggregation {
        let markerNames = Set(forbiddenMarkerRules.map(\.markerLayerName))
        var rules: [LayoutDerivedLayerRule] = []
        var materializedRuleIDs: [String] = []
        var seenRuleIDs: Set<String> = []
        for definition in definitions {
            guard markerNames.contains(definition.name) else {
                continue
            }
            guard let materialization = materializedSourceTempLayerRules(
                for: definition,
                definitionsByName: definitionsByName,
                resolver: resolver,
                targetLayer: markerLayerID(for: definition.name)
            ) else {
                continue
            }
            for rule in materialization.rules where seenRuleIDs.insert(rule.id).inserted {
                rules.append(rule)
            }
            materializedRuleIDs.append(materialization.finalRuleID)
        }
        return SourceTempLayerDerivedLayerAggregation(
            rules: rules,
            materializedRuleIDs: materializedRuleIDs.sorted()
        )
    }

    static func materializedSourceTempLayerRules(
        for definition: MagicDRCSourceTempLayerDefinition,
        definitionsByName: [String: MagicDRCSourceTempLayerDefinition],
        resolver: LayerResolver,
        targetLayer: LayoutLayerID
    ) -> SourceTempLayerMaterialization? {
        var cache: [String: SourceTempLayerMaterialization] = [:]
        var visiting: Set<String> = []
        return materializedSourceTempLayerRules(
            for: definition,
            definitionsByName: definitionsByName,
            resolver: resolver,
            targetLayer: targetLayer,
            cache: &cache,
            visiting: &visiting
        )
    }

    static func materializedSourceTempLayerRules(
        for definition: MagicDRCSourceTempLayerDefinition,
        definitionsByName: [String: MagicDRCSourceTempLayerDefinition],
        resolver: LayerResolver,
        targetLayer: LayoutLayerID,
        cache: inout [String: SourceTempLayerMaterialization],
        visiting: inout Set<String>
    ) -> SourceTempLayerMaterialization? {
        guard definition.unresolvedReferences.isEmpty,
              visiting.insert(definition.name).inserted else {
            return nil
        }
        defer { visiting.remove(definition.name) }

        var rules: [LayoutDerivedLayerRule] = []
        let currentLayers = sourceTempLayerOperandLayers(
            from: definition.initialTerms,
            definitionsByName: definitionsByName,
            resolver: resolver,
            cache: &cache,
            visiting: &visiting,
            dependencyRules: &rules
        )

        var stepIndex = 0
        var currentLayer: LayoutLayerID?
        func nextStep() -> (layer: LayoutLayerID, ruleID: String) {
            stepIndex += 1
            return (
                layer: sourceTempLayerStepLayerID(name: definition.name, step: stepIndex),
                ruleID: sourceTempLayerStepRuleID(name: definition.name, step: stepIndex)
            )
        }
        func nextTarget(isLast: Bool) -> (layer: LayoutLayerID, ruleID: String) {
            if isLast {
                return (
                    layer: targetLayer,
                    ruleID: sourceTempLayerMaterializedRuleID(name: definition.name)
                )
            }
            return nextStep()
        }

        if currentLayers.count == 1 {
            currentLayer = currentLayers[0]
        } else if currentLayers.count > 1 {
            let target = nextStep()
            currentLayer = target.layer
            rules.append(LayoutDerivedLayerRule(
                id: target.ruleID,
                targetLayer: target.layer,
                sourceLayers: currentLayers,
                operation: .union
            ))
        }

        guard currentLayer != nil || !definition.operations.isEmpty else {
            return nil
        }

        if definition.operations.isEmpty, let currentLayer, currentLayer != targetLayer {
            let ruleID = sourceTempLayerMaterializedRuleID(name: definition.name)
            rules.append(LayoutDerivedLayerRule(
                id: ruleID,
                targetLayer: targetLayer,
                sourceLayers: [currentLayer],
                operation: .union
            ))
            return SourceTempLayerMaterialization(
                rules: rules,
                finalLayer: targetLayer,
                finalRuleID: ruleID
            )
        }

        for (operationIndex, operation) in definition.operations.enumerated() {
            let isLast = operationIndex == definition.operations.indices.last

            switch operation.command {
            case "grow", "shrink":
                guard let baseLayer = currentLayer,
                      operation.arguments.count == 1,
                      let rawDistance = Double(operation.arguments[0]),
                      rawDistance.isFinite,
                      rawDistance >= 0 else {
                    return nil
                }
                let target = nextTarget(isLast: isLast)
                rules.append(LayoutDerivedLayerRule(
                    id: target.ruleID,
                    targetLayer: target.layer,
                    sourceLayers: [baseLayer],
                    operation: operation.command == "grow" ? .grow : .shrink,
                    operationDistance: rawDistance / 1_000
                ))
                currentLayer = target.layer
            case "and", "or", "and-not":
                guard let baseLayer = currentLayer else {
                    return nil
                }
                let operandLayers = sourceTempLayerOperandLayers(
                    from: operation.arguments,
                    definitionsByName: definitionsByName,
                    resolver: resolver,
                    cache: &cache,
                    visiting: &visiting,
                    dependencyRules: &rules
                )
                guard !operandLayers.isEmpty else {
                    return nil
                }
                let derivedOperation: LayoutDerivedLayerRule.Operation
                switch operation.command {
                case "and":
                    derivedOperation = .intersection
                case "or":
                    derivedOperation = .union
                default:
                    derivedOperation = .difference
                }
                let target = nextTarget(isLast: isLast)
                rules.append(LayoutDerivedLayerRule(
                    id: target.ruleID,
                    targetLayer: target.layer,
                    sourceLayers: [baseLayer] + operandLayers,
                    operation: derivedOperation
                ))
                currentLayer = target.layer
            case "bloat-all":
                guard operation.arguments.count == 2 else {
                    return nil
                }
                let seedLayers = sourceTempLayerOperandLayers(
                    from: [operation.arguments[0]],
                    definitionsByName: definitionsByName,
                    resolver: resolver,
                    cache: &cache,
                    visiting: &visiting,
                    dependencyRules: &rules
                )
                let guideLayers = sourceTempLayerOperandLayers(
                    from: [operation.arguments[1]],
                    definitionsByName: definitionsByName,
                    resolver: resolver,
                    cache: &cache,
                    visiting: &visiting,
                    dependencyRules: &rules
                )
                guard !seedLayers.isEmpty, !guideLayers.isEmpty else {
                    return nil
                }
                if let baseLayer = currentLayer {
                    let bloatTarget = nextStep()
                    rules.append(LayoutDerivedLayerRule(
                        id: "\(bloatTarget.ruleID).bloatAll",
                        targetLayer: bloatTarget.layer,
                        sourceLayers: seedLayers + guideLayers,
                        operation: .bloatAll,
                        primarySourceLayerCount: seedLayers.count
                    ))
                    let target = nextTarget(isLast: isLast)
                    rules.append(LayoutDerivedLayerRule(
                        id: target.ruleID,
                        targetLayer: target.layer,
                        sourceLayers: [baseLayer, bloatTarget.layer],
                        operation: .union
                    ))
                    currentLayer = target.layer
                } else {
                    let target = nextTarget(isLast: isLast)
                    rules.append(LayoutDerivedLayerRule(
                        id: target.ruleID,
                        targetLayer: target.layer,
                        sourceLayers: seedLayers + guideLayers,
                        operation: .bloatAll,
                        primarySourceLayerCount: seedLayers.count
                    ))
                    currentLayer = target.layer
                }
            case "mask-hints":
                if let baseLayer = currentLayer {
                    guard isLast, baseLayer != targetLayer else {
                        continue
                    }
                    let ruleID = sourceTempLayerMaterializedRuleID(name: definition.name)
                    rules.append(LayoutDerivedLayerRule(
                        id: ruleID,
                        targetLayer: targetLayer,
                        sourceLayers: [baseLayer],
                        operation: .union
                    ))
                    currentLayer = targetLayer
                } else {
                    let hintLayers = sourceTempLayerOperandLayers(
                        from: operation.arguments,
                        definitionsByName: definitionsByName,
                        resolver: resolver,
                        cache: &cache,
                        visiting: &visiting,
                        dependencyRules: &rules
                    )
                    guard !hintLayers.isEmpty else {
                        return nil
                    }
                    let target = nextTarget(isLast: isLast)
                    rules.append(LayoutDerivedLayerRule(
                        id: target.ruleID,
                        targetLayer: target.layer,
                        sourceLayers: hintLayers,
                        operation: .union
                    ))
                    currentLayer = target.layer
                }
            case "boundary":
                guard operation.arguments.isEmpty else {
                    return nil
                }
                if let baseLayer = currentLayer {
                    let boundaryTarget = nextStep()
                    rules.append(LayoutDerivedLayerRule(
                        id: "\(boundaryTarget.ruleID).boundary",
                        targetLayer: boundaryTarget.layer,
                        sourceLayers: [],
                        operation: .cellBoundary
                    ))
                    let target = nextTarget(isLast: isLast)
                    rules.append(LayoutDerivedLayerRule(
                        id: target.ruleID,
                        targetLayer: target.layer,
                        sourceLayers: [baseLayer, boundaryTarget.layer],
                        operation: .union
                    ))
                    currentLayer = target.layer
                } else {
                    let target = nextTarget(isLast: isLast)
                    rules.append(LayoutDerivedLayerRule(
                        id: target.ruleID,
                        targetLayer: target.layer,
                        sourceLayers: [],
                        operation: .cellBoundary
                    ))
                    currentLayer = target.layer
                }
            default:
                return nil
            }
        }

        return SourceTempLayerMaterialization(
            rules: rules,
            finalLayer: targetLayer,
            finalRuleID: sourceTempLayerMaterializedRuleID(name: definition.name)
        )
    }

    static func sourceTempLayerOperandLayers(
        from expressions: [String],
        definitionsByName: [String: MagicDRCSourceTempLayerDefinition],
        resolver: LayerResolver,
        cache: inout [String: SourceTempLayerMaterialization],
        visiting: inout Set<String>,
        dependencyRules: inout [LayoutDerivedLayerRule]
    ) -> [LayoutLayerID] {
        var layers: [LayoutLayerID] = []
        var seen: Set<LayoutLayerID> = []
        for expression in expressions {
            for term in splitExpressionTerms(expression) {
                if let definition = definitionsByName[term] {
                    let materialization: SourceTempLayerMaterialization?
                    if let cached = cache[definition.name] {
                        materialization = cached
                    } else {
                        materialization = materializedSourceTempLayerRules(
                            for: definition,
                            definitionsByName: definitionsByName,
                            resolver: resolver,
                            targetLayer: sourceTempLayerDerivedLayerID(name: definition.name),
                            cache: &cache,
                            visiting: &visiting
                        )
                        if let materialization {
                            cache[definition.name] = materialization
                        }
                    }
                    guard let materialization else {
                        return []
                    }
                    dependencyRules.append(contentsOf: materialization.rules)
                    if seen.insert(materialization.finalLayer).inserted {
                        layers.append(materialization.finalLayer)
                    }
                    continue
                }
                for layerName in resolver.resolveLayerSet(term) {
                    let id = layerID(for: layerName, profile: resolver.profile)
                    if seen.insert(id).inserted {
                        layers.append(id)
                    }
                }
            }
        }
        return layers
    }

    static func resolvedLayerNames(
        from expressions: [String],
        resolver: LayerResolver
    ) -> [String] {
        var names: [String] = []
        var seen: Set<String> = []
        for expression in expressions {
            for term in splitExpressionTerms(expression) {
                for name in resolver.resolveLayerSet(term) where seen.insert(name).inserted {
                    names.append(name)
                }
            }
        }
        return names.sorted { layerSortKey($0, $1, profile: resolver.profile) }
    }

    static func isNumericTerm(_ term: String) -> Bool {
        Double(term) != nil
    }

}
