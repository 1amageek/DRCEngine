import Foundation
import LayoutTech

struct MagicDRCLayoutTechImportProfileValidator {
    let profile: MagicDRCLayoutTechImportProfile

    func issues() -> [MagicDRCLayoutTechImportProfileValidationIssue] {
        var issues: [MagicDRCLayoutTechImportProfileValidationIssue] = []
        if profile.profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(
                .emptyProfileID,
                field: "profileID",
                message: "Profile identifier must not be empty."
            ))
        }
        if profile.schemaVersion != 1 {
            issues.append(issue(
                .unsupportedSchemaVersion,
                field: "schemaVersion",
                message: "Only Magic DRC LayoutTech import profile schemaVersion 1 is supported."
            ))
        }

        let declaredLayerNames = Set(profile.baseLayerNames)
        appendLayerListIssues(profile.layerOrder, field: "layerOrder", issues: &issues)
        appendLayerListIssues(profile.cutLayerNames, field: "cutLayerNames", issues: &issues)
        appendLayerListIssues(profile.baseLayerNames, field: "baseLayerNames", issues: &issues)
        appendStringMapIssues(
            profile.layerPurposes,
            field: "layerPurposes",
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendStringMapIssues(
            profile.layerDisplayNames,
            field: "layerDisplayNames",
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendStringMapIssues(
            profile.layerFillPatterns,
            field: "layerFillPatterns",
            declaredLayerNames: declaredLayerNames,
            allowedValues: Set(LayoutFillPattern.allCases.map(\.rawValue)),
            unsupportedCode: .unsupportedFillPattern,
            issues: &issues
        )
        appendStringMapIssues(
            profile.layerPreferredDirections,
            field: "layerPreferredDirections",
            declaredLayerNames: declaredLayerNames,
            allowedValues: Set(["horizontal", "vertical", "none"]),
            unsupportedCode: .unsupportedPreferredDirection,
            issues: &issues
        )
        appendLayerReferenceMapIssues(
            profile.planeBaseLayerNames,
            field: "planeBaseLayerNames",
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendTypeAliasIssues(
            profile.typeAliasBaseLayerNames,
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendAliasArrayIssues(
            profile.canonicalLayerAliases,
            field: "canonicalLayerAliases",
            declaredLayerNames: declaredLayerNames,
            keysReferenceDeclaredLayers: true,
            valuesReferenceDeclaredLayers: false,
            issues: &issues
        )
        appendAliasArrayIssues(
            profile.layerSetAliases,
            field: "layerSetAliases",
            declaredLayerNames: declaredLayerNames,
            keysReferenceDeclaredLayers: false,
            valuesReferenceDeclaredLayers: true,
            issues: &issues
        )
        appendColorIssues(
            profile.layerColors,
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendDerivedLayerSeedIssues(
            profile.derivedLayerSeeds,
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        appendCutStackConnectionIssues(
            profile.cutStackConnections,
            declaredLayerNames: declaredLayerNames,
            issues: &issues
        )
        return issues
    }

    private func appendLayerListIssues(
        _ layerNames: [String],
        field: String,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (index, name) in layerNames.enumerated()
            where name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(
                .emptyLayerName,
                field: "\(field)[\(index)]",
                message: "Layer names must not be empty."
            ))
        }
        for duplicate in duplicates(in: layerNames) {
            issues.append(issue(
                .duplicateLayerName,
                field: field,
                message: "Layer name '\(duplicate)' appears more than once."
            ))
        }
    }

    private func appendStringMapIssues(
        _ values: [String: String],
        field: String,
        declaredLayerNames: Set<String>,
        allowedValues: Set<String>? = nil,
        unsupportedCode: MagicDRCLayoutTechImportProfileValidationIssue.Code? = nil,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (key, value) in values {
            appendMapKeyIssue(key, field: field, declaredLayerNames: declaredLayerNames, issues: &issues)
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(
                    .emptyMapValue,
                    field: "\(field).\(key)",
                    message: "Map values must not be empty."
                ))
            }
            if let allowedValues,
               let unsupportedCode,
               !allowedValues.contains(value) {
                issues.append(issue(
                    unsupportedCode,
                    field: "\(field).\(key)",
                    message: "Value '\(value)' is not supported."
                ))
            }
        }
    }

    private func appendLayerReferenceMapIssues(
        _ values: [String: String],
        field: String,
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (key, value) in values {
            if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(.emptyMapKey, field: field, message: "Map keys must not be empty."))
            }
            appendLayerReferenceIssue(value, field: "\(field).\(key)", declaredLayerNames: declaredLayerNames, issues: &issues)
        }
    }

    private func appendTypeAliasIssues(
        _ values: [String: [String: String]],
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (plane, aliases) in values {
            if plane.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(.emptyMapKey, field: "typeAliasBaseLayerNames", message: "Plane names must not be empty."))
            }
            for (alias, baseLayerName) in aliases {
                if alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(issue(
                        .emptyMapKey,
                        field: "typeAliasBaseLayerNames.\(plane)",
                        message: "Alias names must not be empty."
                    ))
                }
                appendLayerReferenceIssue(
                    baseLayerName,
                    field: "typeAliasBaseLayerNames.\(plane).\(alias)",
                    declaredLayerNames: declaredLayerNames,
                    issues: &issues
                )
            }
        }
    }

    private func appendAliasArrayIssues(
        _ values: [String: [String]],
        field: String,
        declaredLayerNames: Set<String>,
        keysReferenceDeclaredLayers: Bool,
        valuesReferenceDeclaredLayers: Bool,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (key, aliases) in values {
            if keysReferenceDeclaredLayers {
                appendMapKeyIssue(key, field: field, declaredLayerNames: declaredLayerNames, issues: &issues)
            } else if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(.emptyMapKey, field: field, message: "Alias set names must not be empty."))
            }
            for (index, alias) in aliases.enumerated() {
                if alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(issue(
                        .emptyMapValue,
                        field: "\(field).\(key)[\(index)]",
                        message: "Alias values must not be empty."
                    ))
                }
                if valuesReferenceDeclaredLayers {
                    appendLayerReferenceIssue(
                        alias,
                        field: "\(field).\(key)[\(index)]",
                        declaredLayerNames: declaredLayerNames,
                        issues: &issues
                    )
                }
            }
        }
    }

    private func appendColorIssues(
        _ colors: [String: MagicDRCLayoutTechLayerColor],
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (layerName, color) in colors {
            appendMapKeyIssue(layerName, field: "layerColors", declaredLayerNames: declaredLayerNames, issues: &issues)
            let components = [
                ("red", color.red),
                ("green", color.green),
                ("blue", color.blue),
                ("alpha", color.alpha),
            ]
            for (componentName, value) in components
                where !value.isFinite || value < 0 || value > 1 {
                issues.append(issue(
                    .invalidColorComponent,
                    field: "layerColors.\(layerName).\(componentName)",
                    message: "Color components must be finite values between 0 and 1."
                ))
            }
        }
    }

    private func appendDerivedLayerSeedIssues(
        _ seeds: [MagicDRCLayoutTechDerivedLayerSeed],
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (index, seed) in seeds.enumerated() {
            if seed.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(
                    .emptyDerivedLayerSeedID,
                    field: "derivedLayerSeeds[\(index)].id",
                    message: "Derived layer seed identifiers must not be empty."
                ))
            }
            appendLayerReferenceIssue(
                seed.targetLayerName,
                field: "derivedLayerSeeds[\(index)].targetLayerName",
                declaredLayerNames: declaredLayerNames,
                issues: &issues
            )
            if seed.sourceLayerNames.isEmpty {
                issues.append(issue(
                    .emptyDerivedLayerSeedSourceLayers,
                    field: "derivedLayerSeeds[\(index)].sourceLayerNames",
                    message: "Derived layer seeds must name at least one source layer."
                ))
            }
            for (sourceIndex, sourceLayerName) in seed.sourceLayerNames.enumerated() {
                appendLayerReferenceIssue(
                    sourceLayerName,
                    field: "derivedLayerSeeds[\(index)].sourceLayerNames[\(sourceIndex)]",
                    declaredLayerNames: declaredLayerNames,
                    issues: &issues
                )
            }
            if LayoutDerivedLayerRule.Operation(rawValue: seed.operation) == nil {
                issues.append(issue(
                    .unsupportedDerivedLayerOperation,
                    field: "derivedLayerSeeds[\(index)].operation",
                    message: "Derived layer operation '\(seed.operation)' is not supported."
                ))
            }
        }
    }

    private func appendCutStackConnectionIssues(
        _ connections: [MagicDRCLayoutTechCutStackConnection],
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        for (index, connection) in connections.enumerated() {
            if connection.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(
                    .emptyCutStackConnectionID,
                    field: "cutStackConnections[\(index)].id",
                    message: "Cut stack connection identifiers must not be empty."
                ))
            }
            appendLayerReferenceIssue(
                connection.cutLayerName,
                field: "cutStackConnections[\(index)].cutLayerName",
                declaredLayerNames: declaredLayerNames,
                issues: &issues
            )
            appendLayerReferenceIssue(
                connection.bottomLayerName,
                field: "cutStackConnections[\(index)].bottomLayerName",
                declaredLayerNames: declaredLayerNames,
                issues: &issues
            )
            appendLayerReferenceIssue(
                connection.topLayerName,
                field: "cutStackConnections[\(index)].topLayerName",
                declaredLayerNames: declaredLayerNames,
                issues: &issues
            )
            if !["via", "contact"].contains(connection.kind) {
                issues.append(issue(
                    .unsupportedCutStackKind,
                    field: "cutStackConnections[\(index)].kind",
                    message: "Cut stack kind '\(connection.kind)' is not supported."
                ))
            }
            if let minimumCutCount = connection.minimumCutCount, minimumCutCount <= 0 {
                issues.append(issue(
                    .invalidMinimumCutCount,
                    field: "cutStackConnections[\(index)].minimumCutCount",
                    message: "Minimum cut count must be greater than zero."
                ))
            }
        }
    }

    private func appendMapKeyIssue(
        _ key: String,
        field: String,
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.emptyMapKey, field: field, message: "Map keys must not be empty."))
            return
        }
        appendLayerReferenceIssue(key, field: "\(field).\(key)", declaredLayerNames: declaredLayerNames, issues: &issues)
    }

    private func appendLayerReferenceIssue(
        _ layerName: String,
        field: String,
        declaredLayerNames: Set<String>,
        issues: inout [MagicDRCLayoutTechImportProfileValidationIssue]
    ) {
        if layerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(
                .emptyLayerName,
                field: field,
                message: "Layer references must not be empty."
            ))
            return
        }
        guard !declaredLayerNames.isEmpty else { return }
        if !declaredLayerNames.contains(layerName) {
            issues.append(issue(
                .unknownReferencedLayerName,
                field: field,
                message: "Layer '\(layerName)' is not declared in baseLayerNames."
            ))
        }
    }

    private func duplicates(in values: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for value in values where !seen.insert(value).inserted {
            duplicates.insert(value)
        }
        return duplicates.sorted()
    }

    private func issue(
        _ code: MagicDRCLayoutTechImportProfileValidationIssue.Code,
        field: String,
        message: String
    ) -> MagicDRCLayoutTechImportProfileValidationIssue {
        MagicDRCLayoutTechImportProfileValidationIssue(code: code, field: field, message: message)
    }
}
