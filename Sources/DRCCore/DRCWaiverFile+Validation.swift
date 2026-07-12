import Foundation

public extension DRCWaiverFile {
    static let currentSchemaVersion = 1

    func validate() -> [DRCWaiverValidationIssue] {
        var issues: [DRCWaiverValidationIssue] = []
        if schemaVersion != Self.currentSchemaVersion {
            issues.append(DRCWaiverValidationIssue(
                code: "drc_waiver_schema_version_unsupported",
                waiverID: nil,
                fieldPath: "schemaVersion",
                message: "DRC waiver file schemaVersion \(schemaVersion) is not supported.",
                suggestedActions: ["regenerate_drc_waiver_file"]
            ))
        }

        var seenIDs: Set<String> = []
        for (index, waiver) in waivers.enumerated() {
            let prefix = "waivers[\(index)]"
            let normalizedID = waiver.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedID.isEmpty {
                issues.append(DRCWaiverValidationIssue(
                    code: "drc_waiver_id_empty",
                    waiverID: nil,
                    fieldPath: "\(prefix).id",
                    message: "DRC waiver id must not be empty.",
                    suggestedActions: ["assign_stable_drc_waiver_id"]
                ))
            } else if !seenIDs.insert(normalizedID).inserted {
                issues.append(DRCWaiverValidationIssue(
                    code: "drc_waiver_duplicate_id",
                    waiverID: normalizedID,
                    fieldPath: "\(prefix).id",
                    message: "Waiver IDs must be unique.",
                    suggestedActions: ["deduplicate_drc_waiver_ids"]
                ))
            }
        issues.append(contentsOf: waiver.validationIssues(fieldPathPrefix: prefix))
        }
        return issues
    }
}

public extension DRCWaiver {
    var hasScopeSelector: Bool {
        normalizedSelector(ruleID) != nil
            || normalizedSelector(kind) != nil
            || normalizedSelector(layer) != nil
            || !relatedShapeIDs.isEmpty
            || normalizedSelector(messageContains) != nil
    }

    func validationIssues(fieldPathPrefix: String = "waiver") -> [DRCWaiverValidationIssue] {
        var issues: [DRCWaiverValidationIssue] = []
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(DRCWaiverValidationIssue(
                code: "drc_waiver_reason_empty",
                waiverID: normalizedID.isEmpty ? nil : normalizedID,
                fieldPath: "\(fieldPathPrefix).reason",
                message: "DRC waiver reason must not be empty.",
                suggestedActions: ["document_drc_waiver_reason"]
            ))
        }

        appendEmptyOptionalSelectorIssue(
            &issues,
            value: ruleID,
            fieldPath: "\(fieldPathPrefix).ruleID",
            normalizedID: normalizedID
        )
        appendEmptyOptionalSelectorIssue(
            &issues,
            value: kind,
            fieldPath: "\(fieldPathPrefix).kind",
            normalizedID: normalizedID
        )
        appendEmptyOptionalSelectorIssue(
            &issues,
            value: layer,
            fieldPath: "\(fieldPathPrefix).layer",
            normalizedID: normalizedID
        )
        appendEmptyOptionalSelectorIssue(
            &issues,
            value: messageContains,
            fieldPath: "\(fieldPathPrefix).messageContains",
            normalizedID: normalizedID
        )

        var seenShapeIDs: Set<String> = []
        for (index, shapeID) in relatedShapeIDs.enumerated() {
            let fieldPath = "\(fieldPathPrefix).relatedShapeIDs[\(index)]"
            let normalizedShapeID = shapeID.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedShapeID.isEmpty {
                issues.append(DRCWaiverValidationIssue(
                    code: "drc_waiver_related_shape_id_empty",
                    waiverID: normalizedID.isEmpty ? nil : normalizedID,
                    fieldPath: fieldPath,
                    message: "DRC waiver relatedShapeIDs entries must not be empty.",
                    suggestedActions: ["remove_empty_drc_waiver_shape_selector"]
                ))
            } else if !seenShapeIDs.insert(normalizedShapeID).inserted {
                issues.append(DRCWaiverValidationIssue(
                    code: "drc_waiver_duplicate_related_shape_id",
                    waiverID: normalizedID.isEmpty ? nil : normalizedID,
                    fieldPath: fieldPath,
                    message: "DRC waiver relatedShapeIDs entries must be unique.",
                    suggestedActions: ["deduplicate_drc_waiver_shape_selectors"]
                ))
            }
        }

        if !hasScopeSelector {
            issues.append(DRCWaiverValidationIssue(
                code: "drc_waiver_unscoped",
                waiverID: normalizedID.isEmpty ? nil : normalizedID,
                fieldPath: fieldPathPrefix,
                message: "DRC waiver must include at least one scope selector.",
                suggestedActions: [
                    "add_drc_waiver_rule_selector",
                    "add_drc_waiver_layer_selector",
                    "add_drc_waiver_shape_selector",
                ]
            ))
        }
        if let approval,
           let message = approval.validationMessage() {
            issues.append(DRCWaiverValidationIssue(
                code: "drc_waiver_approval_invalid",
                waiverID: normalizedID.isEmpty ? nil : normalizedID,
                fieldPath: "\(fieldPathPrefix).approval",
                message: message,
                suggestedActions: ["fix_drc_waiver_approval_metadata"]
            ))
        }
        return issues
    }

    private func normalizedSelector(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }

    private func appendEmptyOptionalSelectorIssue(
        _ issues: inout [DRCWaiverValidationIssue],
        value: String?,
        fieldPath: String,
        normalizedID: String
    ) {
        guard let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        issues.append(DRCWaiverValidationIssue(
            code: "drc_waiver_selector_empty",
            waiverID: normalizedID.isEmpty ? nil : normalizedID,
            fieldPath: fieldPath,
            message: "DRC waiver selector \(fieldPath) must not be empty when present.",
            suggestedActions: ["remove_empty_drc_waiver_selector", "replace_with_specific_drc_waiver_selector"]
        ))
    }
}
