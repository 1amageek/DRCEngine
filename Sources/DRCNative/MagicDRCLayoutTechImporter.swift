import Foundation
import LayoutCore
import LayoutTech
@_exported import DRCFoundryImport
public enum MagicDRCLayoutTechImporter {
    public static func importTechnology(
        from magicTechURL: URL,
        profile: MagicDRCLayoutTechImportProfile,
        generatedAt: String? = nil
    ) throws -> MagicDRCLayoutTechImport {
        let text = try String(contentsOf: magicTechURL, encoding: .utf8)
        return importTechnology(
            text: text,
            sourcePath: magicTechURL.path(percentEncoded: false),
            profile: profile,
            generatedAt: generatedAt
        )
    }

    public static func importTechnology(
        text: String,
        sourcePath: String,
        profile: MagicDRCLayoutTechImportProfile,
        generatedAt: String? = nil
    ) -> MagicDRCLayoutTechImport {
        importTechnologyForCompatibility(
            text: text,
            sourcePath: sourcePath,
            generatedAt: generatedAt,
            profile: profile
        )
    }

    static func importTechnologyForCompatibility(
        text: String,
        sourcePath: String,
        generatedAt: String? = nil,
        profile: MagicDRCLayoutTechImportProfile
    ) -> MagicDRCLayoutTechImport {
        do {
            try profile.validateForImport()
        } catch {
            return blockedImport(
                sourcePath: sourcePath,
                generatedAt: generatedAt,
                sourceLayers: [],
                sourceCutAliases: [],
                profile: profile,
                diagnostic: profileValidationDiagnostic(error)
            )
        }
        let logicalLines = makeLogicalLines(from: text)
        let sourceLayers = parseSourceLayers(from: logicalLines, profile: profile)
        let sourceCutAliases = parseSourceCutAliases(from: logicalLines, profile: profile)
        let sourceTempLayerDefinitions = parseSourceTempLayerDefinitions(from: logicalLines)
        let resolver = LayerResolver(
            sourceLayers: sourceLayers,
            sourceCutAliases: sourceCutAliases,
            logicalLines: logicalLines,
            profile: profile
        )
        let sourceTempLayerDefinitionArtifacts = parseSourceTempLayerDefinitionArtifacts(
            from: logicalLines,
            resolver: resolver
        )
        let sourceTempLayerDefinitionsByName = Dictionary(
            uniqueKeysWithValues: sourceTempLayerDefinitionArtifacts.map { ($0.name, $0) }
        )
        let sourceContactStacks = parseSourceContactStacks(
            from: logicalLines,
            resolver: resolver
        )
        let sourceContactDefinitions = parseSourceContactDefinitions(
            from: logicalLines,
            resolver: resolver,
            sourceContactStacks: sourceContactStacks
        )
        let sourceExactOverlapRules: [MagicDRCSourceExactOverlapRule]
        do {
            sourceExactOverlapRules = try parseSourceExactOverlapRules(
                from: logicalLines,
                resolver: resolver
            )
        } catch {
            return blockedImport(
                sourcePath: sourcePath,
                generatedAt: generatedAt,
                sourceLayers: sourceLayers,
                sourceCutAliases: sourceCutAliases,
                profile: profile,
                diagnostic: MagicDRCImportDiagnostic(
                    code: "magic_drc_source_rule_validation_failed",
                    message: "Magic DRC source rule validation failed: \(error)"
                )
            )
        }
        let sourceEnclosedHoleSeeds = parseSourceEnclosedHoleSeeds(
            from: logicalLines,
            resolver: resolver
        )
        let materializableTempLayerNames = Set(
            sourceTempLayerDefinitionArtifacts.compactMap {
                materializedSourceTempLayerRules(
                    for: $0,
                    definitionsByName: sourceTempLayerDefinitionsByName,
                    resolver: resolver,
                    targetLayer: markerLayerID(for: $0.name)
                )?.finalLayer.name
            }
        )
        let parsed = parseDRCRules(
            from: logicalLines,
            resolver: resolver,
            tempLayerDefinitions: sourceTempLayerDefinitions,
            enclosedHoleSeeds: sourceEnclosedHoleSeeds,
            materializableTempLayerNames: materializableTempLayerNames,
            sourceContactStacks: sourceContactStacks
        )
        let layerStates = aggregateLayerRules(parsed.importedRules)
        let sortedLayerNames = layerStates.keys.sorted { layerSortKey($0, $1, profile: profile) }
        let sourceTempLayerDerivedLayerAggregation = aggregateSourceTempLayerDerivedLayerRules(
            definitions: sourceTempLayerDefinitionArtifacts,
            forbiddenMarkerRules: parsed.sourceForbiddenMarkerRules,
            definitionsByName: sourceTempLayerDefinitionsByName,
            resolver: resolver
        )
        let derivedLayerRules = aggregateDerivedLayerRules(layerStates: layerStates, profile: profile)
            + sourceTempLayerDerivedLayerAggregation.rules
        let derivedLayerNames = Set(derivedLayerRules.map(\.targetLayer.name))

        var layerDefinitions: [LayoutLayerDefinition] = []
        var layerRules: [LayoutLayerRuleSet] = []
        var diagnostics = parsed.diagnostics

        for layerName in sortedLayerNames {
            guard let state = layerStates[layerName] else { continue }
            let layerID = layerID(for: layerName, profile: profile)
            if let sourceLayer = resolver.sourceLayer(for: layerName) {
                layerDefinitions.append(LayoutLayerDefinition(
                    id: layerID,
                    displayName: displayName(for: layerName, profile: profile),
                    gdsLayer: sourceLayer.gdsLayer,
                    gdsDatatype: sourceLayer.gdsDatatype,
                    color: color(for: layerName, profile: profile),
                    fillPattern: fillPattern(for: layerName, profile: profile),
                    preferredDirection: preferredDirection(for: layerName, profile: profile)
                ))
            } else if !derivedLayerNames.contains(layerName) {
                diagnostics.append(MagicDRCImportDiagnostic(
                    code: "gds_layer_mapping_missing",
                    message: "No Magic GDSII calma mapping was found for imported layer '\(layerName)'."
                ))
                continue
            }
            layerRules.append(LayoutLayerRuleSet(
                layerID: layerID,
                minWidth: state.minWidth ?? 0,
                minSpacing: state.minSpacing ?? 0,
                minArea: state.minArea ?? 0,
                minDensity: 0,
                maxDensity: 1,
                minNotch: state.minNotch,
                wideWidthThreshold: state.wideWidthThreshold,
                wideSpacing: state.wideSpacing,
                minEnclosedArea: state.minEnclosedArea,
                requiresRectangular: state.requiresRectangular,
                allowedAngleStepDegrees: state.allowedAngleStepDegrees
            ))
        }

        var ruledLayerIDs = Set(layerRules.map(\.layerID))
        let derivedTargetLayerIDs = Array(Set(derivedLayerRules.map(\.targetLayer))).sorted {
            if $0.name == $1.name {
                return $0.purpose < $1.purpose
            }
            return layerSortKey($0.name, $1.name, profile: profile)
        }
        for layerID in derivedTargetLayerIDs where ruledLayerIDs.insert(layerID).inserted {
            layerRules.append(LayoutLayerRuleSet(
                layerID: layerID,
                minWidth: 0,
                minSpacing: 0,
                minArea: 0,
                minDensity: 0,
                maxDensity: 1
            ))
        }

        let availableLayerNames = Set(layerDefinitions.map(\.id.name)).union(derivedLayerNames)
        let spacingRules = aggregateSpacingRules(parsed.importedRules, profile: profile)
        let enclosureRules = aggregateEnclosureRules(parsed.importedRules, profile: profile)
        let extensionRules = aggregateExtensionRules(parsed.importedRules, profile: profile)
        let interconnectDefinitions = aggregateInterconnectDefinitions(
            layerStates: layerStates,
            enclosureRules: enclosureRules,
            sourceContactDefinitions: sourceContactDefinitions,
            sourceContactStacks: sourceContactStacks,
            availableLayerNames: availableLayerNames,
            profile: profile
        )
        let profileMinimumCutPolicies = profileMinimumCutPolicies(profile: profile)
        let minimumCutRules = aggregateMinimumCutRules(
            interconnectDefinitions,
            sourceMinimumCutPolicies: parsed.sourceMinimumCutPolicies,
            profile: profile
        )
        let exactOverlapRules = aggregateExactOverlapRules(
            sourceExactOverlapRules,
            availableLayerNames: availableLayerNames,
            profile: profile
        )
        let forbiddenLayerRules = aggregateForbiddenLayerRules(parsed.sourceForbiddenMarkerRules)

        let importedLayerNames = layerRules.map { $0.layerID.name }
        let status: MagicDRCLayoutTechImportStatus
        if parsed.importedRules.isEmpty || importedLayerNames.isEmpty {
            status = .blocked
        } else if parsed.skippedFamilyCounts.isEmpty && diagnostics.isEmpty {
            status = .complete
        } else {
            status = .partial
        }

        let report = MagicDRCLayoutTechImportReport(
            generatedAt: generatedAt ?? utcTimestamp(),
            status: status,
            sourcePath: sourcePath,
            supportedRuleFamilies: supportedRuleFamilies,
            importedRuleCount: parsed.importedRules.count,
            skippedRuleCount: parsed.skippedFamilyCounts.values.reduce(0, +),
            importedFamilyCounts: parsed.importedFamilyCounts,
            skippedFamilyCounts: parsed.skippedFamilyCounts,
            importedLayerNames: importedLayerNames,
            sourceCutLayerNames: sourceCutLayerNames(from: sourceCutAliases, profile: profile),
            sourceCutAliasCount: sourceCutAliases.count,
            sourceContactDefinitionIDs: sourceContactDefinitions.map(\.id),
            sourceContactDefinitionCount: sourceContactDefinitions.count,
            sourceContactStacks: sourceContactStacks,
            sourceExactOverlapRules: sourceExactOverlapRules,
            sourceExactOverlapRuleIDs: sourceExactOverlapRules.map(\.id),
            sourceExactOverlapRuleCount: sourceExactOverlapRules.count,
            sourceEnclosedHoleRules: parsed.sourceEnclosedHoleRules,
            sourceEnclosedHoleRuleIDs: parsed.sourceEnclosedHoleRules.map(\.id),
            sourceEnclosedHoleRuleCount: parsed.sourceEnclosedHoleRules.count,
            sourceForbiddenMarkerRules: parsed.sourceForbiddenMarkerRules,
            sourceForbiddenMarkerRuleIDs: parsed.sourceForbiddenMarkerRules.map(\.id),
            sourceForbiddenMarkerRuleCount: parsed.sourceForbiddenMarkerRules.count,
            sourceTempLayerDefinitions: sourceTempLayerDefinitionArtifacts,
            sourceTempLayerDefinitionIDs: sourceTempLayerDefinitionArtifacts.map(\.id),
            sourceTempLayerDefinitionCount: sourceTempLayerDefinitionArtifacts.count,
            sourceTempLayerOperationCounts: sourceTempLayerOperationCounts(sourceTempLayerDefinitionArtifacts),
            sourceTempLayerMaterializedRuleIDs: sourceTempLayerDerivedLayerAggregation.materializedRuleIDs,
            sourceTempLayerMaterializedRuleCount: sourceTempLayerDerivedLayerAggregation.materializedRuleIDs.count,
            sourceMinimumCutPolicies: parsed.sourceMinimumCutPolicies,
            profileMinimumCutPolicies: profileMinimumCutPolicies,
            derivedViaDefinitionIDs: interconnectDefinitions.vias.map(\.id),
            derivedContactDefinitionIDs: interconnectDefinitions.contacts.map(\.id),
            derivedMinimumCutRuleIDs: minimumCutRules.map(\.id),
            sourceLayerCount: sourceLayers.count,
            importedRules: parsed.importedRules,
            diagnostics: diagnostics
        )
        let technology = LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.001,
            layers: layerDefinitions,
            vias: interconnectDefinitions.vias,
            layerRules: layerRules,
            derivedLayerRules: derivedLayerRules,
            spacingRules: spacingRules,
            enclosureRules: enclosureRules,
            extensionRules: extensionRules,
            minimumCutRules: minimumCutRules,
            exactOverlapRules: exactOverlapRules,
            forbiddenLayerRules: forbiddenLayerRules,
            contacts: interconnectDefinitions.contacts
        )
        return MagicDRCLayoutTechImport(technology: technology, report: report)
    }

    private static func profileValidationDiagnostic(_ error: Error) -> MagicDRCImportDiagnostic {
        if let validationError = error as? MagicDRCLayoutTechImportProfileValidationError {
            let issueList = validationError.issues
                .map { "\($0.code.rawValue)@\($0.field)" }
                .joined(separator: ", ")
            return MagicDRCImportDiagnostic(
                code: "magic_drc_layouttech_profile_validation_failed",
                message: "Magic DRC LayoutTech import profile validation failed for '\(validationError.profileID)': \(issueList)"
            )
        }
        return MagicDRCImportDiagnostic(
            code: "magic_drc_layouttech_profile_validation_failed",
            message: "Magic DRC LayoutTech import profile validation failed: \(error)"
        )
    }

    private static func blockedImport(
        sourcePath: String,
        generatedAt: String?,
        sourceLayers: [SourceLayer],
        sourceCutAliases: [SourceCutAlias],
        profile: MagicDRCLayoutTechImportProfile,
        diagnostic: MagicDRCImportDiagnostic
    ) -> MagicDRCLayoutTechImport {
        let report = MagicDRCLayoutTechImportReport(
            generatedAt: generatedAt ?? utcTimestamp(),
            status: .blocked,
            sourcePath: sourcePath,
            supportedRuleFamilies: supportedRuleFamilies,
            importedRuleCount: 0,
            skippedRuleCount: 0,
            importedFamilyCounts: [:],
            skippedFamilyCounts: [:],
            importedLayerNames: [],
            sourceCutLayerNames: sourceCutLayerNames(from: sourceCutAliases, profile: profile),
            sourceCutAliasCount: sourceCutAliases.count,
            sourceLayerCount: sourceLayers.count,
            importedRules: [],
            diagnostics: [diagnostic]
        )
        let technology = LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.001,
            layers: [],
            vias: [],
            layerRules: []
        )
        return MagicDRCLayoutTechImport(technology: technology, report: report)
    }

    static let supportedRuleFamilies = [
        "width",
        "spacing",
        "area",
        "notch",
        "rect_only",
        "surround",
        "widespacing",
        "overhang",
        "exact_overlap",
        "angles",
        "cifmaxwidth",
        "minimumcut",
        "minimum_cut",
        "mincut",
        "cutcount",
        "cut_count",
    ]
    static let observedRuleFamilies = [
        "width",
        "spacing",
        "area",
        "notch",
        "surround",
        "overhang",
        "rect_only",
        "widespacing",
        "angles",
        "exact_overlap",
        "cifmaxwidth",
        "minimumcut",
        "minimum_cut",
        "mincut",
        "cutcount",
        "cut_count",
        "edge4way",
        "cifspacing",
        "extend",
        "cifwidth",
    ]
    struct LogicalLine: Sendable, Hashable {
        let lineNumber: Int
        let text: String
    }

    struct SourceLayer: Sendable, Hashable {
        let name: String
        let baseName: String
        let expressionTerms: [String]
        let gdsLayer: Int
        let gdsDatatype: Int
    }

    struct SourceCutAlias: Sendable, Hashable {
        let alias: String
        let baseName: String
    }

    struct SourceContactDefinition: Sendable, Hashable {
        let id: String
        let cutLayerName: String
        let bottomLayerName: String
        let topLayerName: String
        let cutSize: Double
        let bottomEnclosure: Double
        let topEnclosure: Double
    }

    struct SourceEnclosedHoleSeed: Sendable, Hashable {
        let id: String
        let layerName: String
        let holeLayerName: String
        let smallHoleLayerName: String
        let minimumArea: Double
        let definitionLineNumber: Int
        let definitionLine: String
    }

    struct ParsedRuleState: Sendable, Hashable {
        var importedRules: [MagicDRCImportedRule] = []
        var diagnostics: [MagicDRCImportDiagnostic] = []
        var importedFamilyCounts: [String: Int] = [:]
        var skippedFamilyCounts: [String: Int] = [:]
        var sourceEnclosedHoleRules: [MagicDRCSourceEnclosedHoleRule] = []
        var sourceForbiddenMarkerRules: [MagicDRCSourceForbiddenMarkerRule] = []
        var sourceMinimumCutPolicies: [MagicDRCSourceMinimumCutPolicy] = []
    }

    struct LayerRuleState: Sendable, Hashable {
        var minWidth: Double?
        var minSpacing: Double?
        var minArea: Double?
        var minNotch: Double?
        var requiresRectangular = false
        var wideWidthThreshold: Double?
        var wideSpacing: Double?
        var minEnclosedArea: Double?
        var allowedAngleStepDegrees: Double?
    }

    struct LayerResolver: Sendable {
        let sourceLayers: [SourceLayer]
        let profile: MagicDRCLayoutTechImportProfile
        let explicitTokenToBaseLayer: [String: String]
        let tokenToBaseLayer: [String: String]
        let tokenToBaseLayers: [String: Set<String>]
        let baseLayerSources: [String: SourceLayer]

        init(
            sourceLayers: [SourceLayer],
            sourceCutAliases: [SourceCutAlias],
            logicalLines: [LogicalLine],
            profile: MagicDRCLayoutTechImportProfile
        ) {
            self.sourceLayers = sourceLayers
            self.profile = profile

            var tokenMap: [String: String] = [:]
            var explicitMap: [String: String] = [:]
            var tokenSetMap: [String: Set<String>] = [:]
            var lockedAliasTokens: Set<String> = []
            var sourceMap: [String: SourceLayer] = [:]
            func record(
                _ token: String,
                baseName: String,
                overwrite: Bool,
                lock: Bool = false,
                replace: Bool = false
            ) {
                let normalized = normalizedToken(token)
                if !lock && !replace && lockedAliasTokens.contains(normalized) {
                    return
                }
                if overwrite || tokenMap[normalized] == nil {
                    tokenMap[normalized] = baseName
                }
                if replace {
                    tokenSetMap[normalized] = [baseName]
                } else {
                    var bases = tokenSetMap[normalized] ?? []
                    bases.insert(baseName)
                    tokenSetMap[normalized] = bases
                }
                if lock {
                    lockedAliasTokens.insert(normalized)
                }
            }
            func recordSet(_ token: String, baseNames: Set<String>, lock: Bool = false) {
                let normalized = normalizedToken(token)
                guard !normalized.isEmpty, !baseNames.isEmpty else {
                    return
                }
                let oldBases = tokenSetMap[normalized] ?? []
                let mergedBases = oldBases.union(baseNames)
                tokenSetMap[normalized] = mergedBases
                if mergedBases.count == 1, let onlyBase = mergedBases.first {
                    tokenMap[normalized] = onlyBase
                }
                if lock {
                    lockedAliasTokens.insert(normalized)
                }
            }
            for sourceLayer in sourceLayers {
                sourceMap[sourceLayer.baseName] = sourceMap[sourceLayer.baseName] ?? sourceLayer
                explicitMap[normalizedToken(sourceLayer.name)] = sourceLayer.baseName
                explicitMap[normalizedToken(sourceLayer.baseName)] = sourceLayer.baseName
                record(sourceLayer.name, baseName: sourceLayer.baseName, overwrite: true, lock: true)
                record(sourceLayer.baseName, baseName: sourceLayer.baseName, overwrite: true, lock: true)
                for term in sourceLayer.expressionTerms {
                    explicitMap[normalizedToken(term)] = sourceLayer.baseName
                    record(term, baseName: sourceLayer.baseName, overwrite: true, lock: true)
                }
            }
            for (alias, baseNames) in profile.layerSetAliases {
                recordSet(alias, baseNames: Set(baseNames))
            }
            for alias in parseTypeAliases(from: logicalLines, profile: profile) {
                record(alias.alias, baseName: alias.baseName, overwrite: true)
            }
            for sourceLayer in sourceLayers {
                for alias in canonicalLayerAliases(for: sourceLayer.baseName, profile: profile) {
                    record(alias, baseName: sourceLayer.baseName, overwrite: true, lock: true, replace: true)
                }
            }
            for alias in sourceCutAliases {
                record(alias.alias, baseName: alias.baseName, overwrite: true, lock: true, replace: true)
            }
            let layerAliases = parseLayerAliases(from: logicalLines)
            var changed = true
            while changed {
                changed = false
                for (alias, terms) in layerAliases {
                    let aliasToken = normalizedToken(alias)
                    guard !lockedAliasTokens.contains(aliasToken) else {
                        continue
                    }
                    var resolvedBases: Set<String> = []
                    for term in terms {
                        let termToken = normalizedToken(term)
                        guard let bases = tokenSetMap[termToken], !bases.isEmpty else {
                            resolvedBases = []
                            break
                        }
                        resolvedBases.formUnion(bases)
                    }
                    guard !resolvedBases.isEmpty else {
                        continue
                    }
                    let oldBases = tokenSetMap[aliasToken] ?? []
                    let mergedBases = oldBases.union(resolvedBases)
                    guard mergedBases != oldBases else {
                        continue
                    }
                    tokenSetMap[aliasToken] = mergedBases
                    if mergedBases.count == 1, let onlyBase = mergedBases.first {
                        tokenMap[aliasToken] = onlyBase
                    }
                    changed = true
                }
            }
            self.explicitTokenToBaseLayer = explicitMap
            self.tokenToBaseLayer = tokenMap
            self.tokenToBaseLayers = tokenSetMap
            self.baseLayerSources = sourceMap
        }

        func sourceLayer(for baseName: String) -> SourceLayer? {
            baseLayerSources[baseName]
        }

        func resolve(_ expression: String) -> String? {
            let parts = expression
                .split(separator: ",")
                .map(String.init)
                .map(Self.cleanExpressionTerm)
                .filter { !$0.isEmpty }
            guard !parts.isEmpty else { return nil }
            var resolved: Set<String> = []
            for part in parts {
                guard let bases = tokenToBaseLayers[normalizedToken(part)] else {
                    return nil
                }
                resolved.formUnion(bases)
            }
            return resolved.count == 1 ? resolved.first : nil
        }

        func resolveAll(_ expression: String) -> [String] {
            let parts = expression
                .split(separator: ",")
                .map(String.init)
                .map(Self.cleanExpressionTerm)
                .filter { !$0.isEmpty }
            guard !parts.isEmpty else { return [] }
            var resolved: Set<String> = []
            for part in parts {
                let token = normalizedToken(part)
                if let base = explicitTokenToBaseLayer[token] {
                    resolved.insert(base)
                    continue
                }
                guard let bases = tokenToBaseLayers[token] else {
                    return []
                }
                resolved.formUnion(bases)
            }
            return resolved.sorted { layerSortKey($0, $1, profile: profile) }
        }

        func resolveLayerSet(_ expression: String) -> [String] {
            let parts = expression
                .split(separator: ",")
                .map(String.init)
                .map(Self.cleanExpressionTerm)
                .filter { !$0.isEmpty }
            guard !parts.isEmpty else { return [] }
            var resolved: Set<String> = []
            for part in parts {
                guard let bases = tokenToBaseLayers[normalizedToken(part)] else {
                    return []
                }
                resolved.formUnion(bases)
            }
            return resolved.sorted { layerSortKey($0, $1, profile: profile) }
        }

        private static func cleanExpressionTerm(_ term: String) -> String {
            var value = term.trimmingCharacters(in: .whitespacesAndNewlines)
            while let first = value.first, first == "*" || first == "-" || first == "!" {
                value.removeFirst()
            }
            if let slashIndex = value.firstIndex(of: "/") {
                value = String(value[..<slashIndex])
            }
            while value.hasPrefix("("), value.hasSuffix(")"), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func makeLogicalLines(from text: String) -> [LogicalLine] {
        var logicalLines: [LogicalLine] = []
        var buffer = ""
        var startLine = 1
        for (offset, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = offset + 1
            var line = normalizedLine(String(rawLine))
            if line.isEmpty {
                continue
            }
            let continues = line.hasSuffix("\\")
            if continues {
                line.removeLast()
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if buffer.isEmpty {
                startLine = lineNumber
                buffer = line
            } else {
                buffer += " " + line
            }
            if !continues {
                logicalLines.append(LogicalLine(lineNumber: startLine, text: buffer))
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            logicalLines.append(LogicalLine(lineNumber: startLine, text: buffer))
        }
        return logicalLines
    }

    private static func parseSourceLayers(
        from logicalLines: [LogicalLine],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [SourceLayer] {
        var sourceLayers: [SourceLayer] = []
        var pendingLayerName: String?
        var pendingTerms: [String] = []

        for line in logicalLines {
            let tokens = splitCommand(line.text)
            guard let command = tokens.first else { continue }
            if command == "layer", tokens.count >= 2 {
                pendingLayerName = tokens[1]
                pendingTerms = tokens.dropFirst(2).flatMap { splitExpressionTerms($0) }
                continue
            }
            if command == "calma",
               tokens.count >= 3,
               let name = pendingLayerName,
               let baseName = baseLayerName(for: name, profile: profile),
               let gdsLayer = Int(tokens[1]),
               let gdsDatatype = Int(tokens[2]) {
                sourceLayers.append(SourceLayer(
                    name: name,
                    baseName: baseName,
                    expressionTerms: pendingTerms,
                    gdsLayer: gdsLayer,
                    gdsDatatype: gdsDatatype
                ))
                pendingLayerName = nil
                pendingTerms = []
            }
        }
        return sourceLayers
    }

    private static func parseSourceCutAliases(
        from logicalLines: [LogicalLine],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [SourceCutAlias] {
        var aliases: [SourceCutAlias] = []
        var seen: Set<SourceCutAlias> = []
        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard tokens.first == "cut", tokens.count >= 3 else {
                continue
            }
            let rawAliases = tokens.dropFirst().flatMap(splitExpressionTerms)
            guard let baseName = rawAliases.compactMap({ baseLayerName(for: $0, profile: profile) }).first else {
                continue
            }
            for alias in rawAliases {
                let entry = SourceCutAlias(alias: alias, baseName: baseName)
                guard !seen.contains(entry) else {
                    continue
                }
                aliases.append(entry)
                seen.insert(entry)
            }
        }
        return aliases
    }

    private static func canonicalLayerAliases(
        for baseName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> [String] {
        if let aliases = profile.canonicalLayerAliases[baseName], !aliases.isEmpty {
            return aliases
        }
        return []
    }

    private static func sourceCutLayerNames(
        from aliases: [SourceCutAlias],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [String] {
        Array(Set(aliases.map(\.baseName))).sorted { layerSortKey($0, $1, profile: profile) }
    }

    private static func parseSourceContactStacks(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver
    ) -> [MagicDRCSourceContactStack] {
        var stacks: [MagicDRCSourceContactStack] = []
        var seen: Set<String> = []
        var inContact = false
        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard let command = tokens.first else {
                continue
            }
            if command == "contact", tokens.count == 1 {
                inContact = true
                continue
            }
            if inContact && command == "end" {
                inContact = false
                continue
            }
            guard inContact, command != "stackable", tokens.count >= 3 else {
                continue
            }
            guard let cutLayerName = resolver.resolve(tokens[0]),
                  cutLayerNames(profile: resolver.profile).contains(cutLayerName),
                  let bottomLayerName = resolver.resolve(tokens[1]),
                  let topLayerName = resolver.resolve(tokens[2]) else {
                continue
            }
            let id = interconnectID(
                forCutLayer: cutLayerName,
                bottomLayerName: bottomLayerName,
                topLayerName: topLayerName,
                sourceContactStacks: [],
                profile: resolver.profile
            )
            guard seen.insert(id).inserted else {
                continue
            }
            stacks.append(MagicDRCSourceContactStack(
                id: id,
                cutLayerName: cutLayerName,
                bottomLayerName: bottomLayerName,
                topLayerName: topLayerName,
                sourceLineNumber: line.lineNumber,
                sourceLine: line.text
            ))
        }
        return stacks.sorted {
            if $0.cutLayerName == $1.cutLayerName {
                if $0.bottomLayerName == $1.bottomLayerName {
                    if $0.topLayerName == $1.topLayerName {
                        return $0.id < $1.id
                    }
                    return layerSortKey($0.topLayerName, $1.topLayerName, profile: resolver.profile)
                }
                return layerSortKey($0.bottomLayerName, $1.bottomLayerName, profile: resolver.profile)
            }
            return layerSortKey($0.cutLayerName, $1.cutLayerName, profile: resolver.profile)
        }
    }

    private static func parseSourceContactDefinitions(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> [SourceContactDefinition] {
        var definitions: [SourceContactDefinition] = []
        var seen: Set<String> = []
        var inWiring = false
        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard let command = tokens.first else {
                continue
            }
            if command == "wiring" {
                inWiring = true
                continue
            }
            if inWiring && command == "end" {
                inWiring = false
                continue
            }
            guard inWiring, command == "contact" else {
                continue
            }
            guard let definition = parseWiringContact(
                tokens: tokens,
                resolver: resolver,
                sourceContactStacks: sourceContactStacks
            ),
                  seen.insert(definition.id).inserted else {
                continue
            }
            definitions.append(definition)
        }
        return definitions.sorted {
            if $0.cutLayerName == $1.cutLayerName {
                return $0.id < $1.id
            }
            return layerSortKey($0.cutLayerName, $1.cutLayerName, profile: resolver.profile)
        }
    }

    private static func parseWiringContact(
        tokens: [String],
        resolver: LayerResolver,
        sourceContactStacks: [MagicDRCSourceContactStack]
    ) -> SourceContactDefinition? {
        guard tokens.count >= 7,
              let size = Double(tokens[2]),
              size.isFinite,
              size > 0,
              let cutLayerName = resolver.resolve(tokens[1]),
              let bottomLayerName = resolver.resolve(tokens[3]) else {
            return nil
        }

        let topLayerIndex = tokens[4...].firstIndex { token in
            Double(token) == nil && resolver.resolve(token) != nil
        }
        guard let topLayerIndex,
              topLayerIndex > 4,
              let topLayerName = resolver.resolve(tokens[topLayerIndex]) else {
            return nil
        }
        let bottomValues = tokens[4..<topLayerIndex].compactMap(Double.init)
        let topValues = tokens.dropFirst(topLayerIndex + 1).compactMap(Double.init)
        guard !bottomValues.isEmpty, !topValues.isEmpty else {
            return nil
        }
        return SourceContactDefinition(
            id: interconnectID(
                forCutLayer: cutLayerName,
                bottomLayerName: bottomLayerName,
                topLayerName: topLayerName,
                sourceContactStacks: sourceContactStacks,
                profile: resolver.profile
            ),
            cutLayerName: cutLayerName,
            bottomLayerName: bottomLayerName,
            topLayerName: topLayerName,
            cutSize: size / 1_000,
            bottomEnclosure: (bottomValues.max() ?? 0) / 1_000,
            topEnclosure: (topValues.max() ?? 0) / 1_000
        )
    }

    private static func parseSourceExactOverlapRules(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver
    ) throws -> [MagicDRCSourceExactOverlapRule] {
        var rules: [MagicDRCSourceExactOverlapRule] = []
        var seen: Set<String> = []
        var inDRC = false
        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard let command = tokens.first else {
                continue
            }
            if command == "drc" {
                inDRC = true
                continue
            }
            if inDRC && command == "end" {
                inDRC = false
                continue
            }
            guard inDRC, command == "exact_overlap", tokens.count >= 2 else {
                continue
            }
            guard let pairs = parseExactOverlapExpressions(tokens[1], resolver: resolver) else {
                continue
            }
            for pair in pairs {
                let id = exactOverlapRuleID(
                    primaryLayerName: pair.primaryLayerName,
                    secondaryLayerNames: pair.secondaryLayerNames
                )
                guard seen.insert(id).inserted else {
                    continue
                }
                rules.append(try MagicDRCSourceExactOverlapRule(
                    id: id,
                    primaryLayerName: pair.primaryLayerName,
                    secondaryLayerNames: pair.secondaryLayerNames,
                    sourceLineNumber: line.lineNumber,
                    sourceLine: line.text
                ))
            }
        }
        return rules.sorted {
            if $0.primaryLayerName == $1.primaryLayerName {
                return $0.secondaryLayerNames.joined(separator: ".") < $1.secondaryLayerNames.joined(separator: ".")
            }
            return layerSortKey($0.primaryLayerName, $1.primaryLayerName, profile: resolver.profile)
        }
    }

    static func parseExactOverlapExpressions(
        _ expression: String,
        resolver: LayerResolver
    ) -> [(primaryLayerName: String, secondaryLayerNames: [String])]? {
        let parts = expression.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            return nil
        }
        let primaryLayerNames = resolver.resolveLayerSet(String(parts[0]))
        let secondaryLayerNames = resolver.resolveLayerSet(String(parts[1]))
        guard !primaryLayerNames.isEmpty, !secondaryLayerNames.isEmpty else {
            return nil
        }
        return primaryLayerNames.map {
            (primaryLayerName: $0, secondaryLayerNames: secondaryLayerNames)
        }
    }

    private static func exactOverlapRuleID(
        primaryLayerName: String,
        secondaryLayerName: String
    ) -> String {
        "exactOverlap.\(primaryLayerName).\(secondaryLayerName)"
    }

    private static func exactOverlapRuleID(
        primaryLayerName: String,
        secondaryLayerNames: [String]
    ) -> String {
        if secondaryLayerNames.count == 1, let secondaryLayerName = secondaryLayerNames.first {
            return exactOverlapRuleID(primaryLayerName: primaryLayerName, secondaryLayerName: secondaryLayerName)
        }
        return "exactOverlap.\(primaryLayerName).oneOf.\(secondaryLayerNames.joined(separator: "."))"
    }

    private static func parseSourceEnclosedHoleSeeds(
        from logicalLines: [LogicalLine],
        resolver: LayerResolver
    ) -> [String: SourceEnclosedHoleSeed] {
        var smallHoleSources: [String: SourceEnclosedHoleSeed] = [:]
        var holeLayerReferences: [String: String] = [:]
        var activeTempLayerName: String?

        for line in logicalLines {
            let tokens = splitCommand(textWithoutQuotedTail(line.text))
            guard let command = tokens.first else {
                continue
            }
            if command == "templayer", tokens.count >= 2 {
                activeTempLayerName = tokens[1]
                if tokens[1].hasSuffix("_hole_empty"), tokens.count >= 3 {
                    holeLayerReferences[tokens[1]] = tokens[2]
                }
                continue
            }
            guard command == "close",
                  tokens.count >= 2,
                  let tempLayerName = activeTempLayerName,
                  tempLayerName.hasSuffix("_small_hole"),
                  let rawArea = Double(tokens[1]),
                  rawArea.isFinite,
                  rawArea > 0 else {
                continue
            }
            let aliasLength = tempLayerName.count - "_small_hole".count
            guard aliasLength > 0 else {
                continue
            }
            let alias = String(tempLayerName.prefix(aliasLength))
            guard let layerName = resolver.resolve(alias) else {
                continue
            }
            smallHoleSources[tempLayerName] = SourceEnclosedHoleSeed(
                id: enclosedHoleRuleID(layerName: layerName),
                layerName: layerName,
                holeLayerName: "",
                smallHoleLayerName: tempLayerName,
                minimumArea: rawArea / 1_000_000,
                definitionLineNumber: line.lineNumber,
                definitionLine: line.text
            )
            activeTempLayerName = nil
        }

        var seeds: [String: SourceEnclosedHoleSeed] = [:]
        for (holeLayerName, smallHoleLayerName) in holeLayerReferences {
            guard var seed = smallHoleSources[smallHoleLayerName] else {
                continue
            }
            seed = SourceEnclosedHoleSeed(
                id: seed.id,
                layerName: seed.layerName,
                holeLayerName: holeLayerName,
                smallHoleLayerName: seed.smallHoleLayerName,
                minimumArea: seed.minimumArea,
                definitionLineNumber: seed.definitionLineNumber,
                definitionLine: seed.definitionLine
            )
            seeds[holeLayerName] = seed
        }
        return seeds
    }

    private static func enclosedHoleRuleID(layerName: String) -> String {
        "enclosedHole.\(layerName)"
    }

    private static func parseTypeAliases(
        from logicalLines: [LogicalLine],
        profile: MagicDRCLayoutTechImportProfile
    ) -> [(alias: String, baseName: String)] {
        var aliases: [(alias: String, baseName: String)] = []
        var inTypes = false
        for line in logicalLines {
            let tokens = splitCommand(line.text)
            guard let command = tokens.first else { continue }
            if command == "types" {
                inTypes = true
                continue
            }
            if inTypes && command == "end" {
                break
            }
            guard inTypes, tokens.count >= 2 else {
                continue
            }
            let plane = command.hasPrefix("-") ? String(command.dropFirst()) : command
            if let planeBaseName = planeBaseLayerName(plane, profile: profile) {
                aliases.append((alias: plane, baseName: planeBaseName))
            }
            for term in tokens.dropFirst().flatMap(splitExpressionTerms) {
                guard let baseName = typeAliasBaseLayerName(plane: plane, alias: term, profile: profile) else {
                    continue
                }
                aliases.append((alias: term, baseName: baseName))
            }
        }
        return aliases
    }

    private static func parseLayerAliases(from logicalLines: [LogicalLine]) -> [String: [String]] {
        var aliases: [String: [String]] = [:]
        var inAliases = false
        for line in logicalLines {
            let tokens = splitCommand(line.text)
            guard let command = tokens.first else { continue }
            if command == "aliases" {
                inAliases = true
                continue
            }
            if inAliases && command == "end" {
                break
            }
            guard inAliases, tokens.count >= 2 else {
                continue
            }
            let terms = tokens.dropFirst().flatMap(splitExpressionTerms)
            if !terms.isEmpty {
                aliases[command] = terms
            }
        }
        return aliases
    }

    static func splitExpressionTerms(_ expression: String) -> [String] {
        expression
            .split(separator: ",")
            .map(String.init)
            .map { term in
                var value = term.trimmingCharacters(in: .whitespacesAndNewlines)
                while let first = value.first, first == "*" || first == "-" || first == "!" {
                    value.removeFirst()
                }
                if let slashIndex = value.firstIndex(of: "/") {
                    value = String(value[..<slashIndex])
                }
                while value.hasPrefix("("), value.hasSuffix(")"), value.count >= 2 {
                    value.removeFirst()
                    value.removeLast()
                    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return value
            }
            .filter { !$0.isEmpty }
    }

    private static func baseLayerName(
        for sourceLayerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> String? {
        var name = sourceLayerName.uppercased()
        for suffix in ["TXT", "PIN", "FILL", "RES"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
            break
        }
        if Set(profile.baseLayerNames.map { $0.uppercased() }).contains(name) {
            return name
        }
        return nil
    }

    private static func planeBaseLayerName(
        _ plane: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> String? {
        if let baseName = profile.planeBaseLayerNames[plane.lowercased()] {
            return baseName
        }
        return nil
    }

    private static func typeAliasBaseLayerName(
        plane: String,
        alias: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> String? {
        let cleanedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if let baseName = baseLayerName(for: cleanedAlias, profile: profile) {
            return baseName
        }
        if let profileBaseName = profile.typeAliasBaseLayerNames[plane.lowercased()]?[cleanedAlias.lowercased()] {
            return profileBaseName
        }
        return planeBaseLayerName(plane, profile: profile)
    }

    static func splitCommand(_ line: String) -> [String] {
        line.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func normalizedLine(_ rawLine: String) -> String {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let commentIndex = trimmed.firstIndex(of: "#") else {
            return trimmed
        }
        return String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedToken(_ token: String) -> String {
        token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func textWithoutQuotedTail(_ text: String) -> String {
        guard let quoteIndex = text.firstIndex(of: "\"") else {
            return text
        }
        return String(text[..<quoteIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func layerSortKey(
        _ lhs: String,
        _ rhs: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> Bool {
        let layerOrder = profile.layerOrder
        let lhsIndex = layerOrder.firstIndex(of: lhs) ?? Int.max
        let rhsIndex = layerOrder.firstIndex(of: rhs) ?? Int.max
        if lhsIndex == rhsIndex {
            return lhs < rhs
        }
        return lhsIndex < rhsIndex
    }

    static func layerID(
        for layerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> LayoutLayerID {
        if let purpose = profile.layerPurposes[layerName] {
            return LayoutLayerID(name: layerName, purpose: purpose)
        }
        return LayoutLayerID(
            name: layerName,
            purpose: cutLayerNames(profile: profile).contains(layerName) ? "cut" : "drawing"
        )
    }

    static func cutLayerNames(profile: MagicDRCLayoutTechImportProfile) -> Set<String> {
        return Set(profile.cutLayerNames)
    }

    static func markerLayerID(for layerName: String) -> LayoutLayerID {
        LayoutLayerID(name: layerName, purpose: "marker")
    }

    private static func displayName(
        for layerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> String {
        if let displayName = profile.layerDisplayNames[layerName] {
            return displayName
        }
        return layerName
    }

    private static func color(
        for layerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> LayoutColor {
        if let color = profile.layerColors[layerName] {
            return LayoutColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        }
        return LayoutColor(red: 0.5, green: 0.5, blue: 0.5)
    }

    private static func fillPattern(
        for layerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> LayoutFillPattern {
        if let value = profile.layerFillPatterns[layerName],
           let pattern = LayoutFillPattern(rawValue: value) {
            return pattern
        }
        if cutLayerNames(profile: profile).contains(layerName) {
            return .crosshatch
        }
        return .solid
    }

    private static func preferredDirection(
        for layerName: String,
        profile: MagicDRCLayoutTechImportProfile
    ) -> LayoutPreferredDirection {
        if let value = profile.layerPreferredDirections[layerName],
           let direction = LayoutPreferredDirection(rawValue: value) {
            return direction
        }
        return .none
    }

    private static func utcTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
