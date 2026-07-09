import Foundation

extension DRCCorpusCoverageAudit {
    public func validateIntegrity() -> [DRCCorpusCoverageAuditIntegrityIssue] {
        var issues: [DRCCorpusCoverageAuditIntegrityIssue] = []
        appendRequiredFieldIssues(&issues)
        appendSummaryIssues(&issues)
        appendCoverageFamilyIssues(&issues)
        appendMissingRequirementIssues(&issues)
        appendSuggestedActionIssues(&issues)
        return issues
    }

    private func appendRequiredFieldIssues(_ issues: inout [DRCCorpusCoverageAuditIntegrityIssue]) {
        if schemaVersion != Self.currentSchemaVersion {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_schema_version_unsupported",
                fieldPath: "schemaVersion",
                message: "DRC corpus coverage audit schemaVersion \(schemaVersion) is not supported.",
                suggestedActions: ["regenerate_drc_corpus_coverage_audit"]
            ))
        }
        appendNonEmptyIssue(&issues, value: auditID, fieldPath: "auditID")
        appendNonEmptyIssue(&issues, value: policyID, fieldPath: "policyID")
        if let reportPath {
            appendPathIssues(&issues, path: reportPath, fieldPath: "reportPath")
        }
    }

    private func appendSummaryIssues(_ issues: inout [DRCCorpusCoverageAuditIntegrityIssue]) {
        appendNonNegativeIssue(&issues, value: summary.caseCount, fieldPath: "summary.caseCount")
        appendNonNegativeIssue(&issues, value: summary.matchedCaseCount, fieldPath: "summary.matchedCaseCount")
        appendNonNegativeIssue(
            &issues,
            value: summary.durationBudgetPassedCaseCount,
            fieldPath: "summary.durationBudgetPassedCaseCount"
        )
        appendUnitRateIssue(&issues, value: summary.durationBudgetPassRate, fieldPath: "summary.durationBudgetPassRate")
        appendNonNegativeIssue(&issues, value: summary.oracleCaseCount, fieldPath: "summary.oracleCaseCount")
        appendNonNegativeIssue(
            &issues,
            value: summary.oracleAgreementPassedCaseCount,
            fieldPath: "summary.oracleAgreementPassedCaseCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.oracleReadinessBlockedCaseCount,
            fieldPath: "summary.oracleReadinessBlockedCaseCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.oracleExecutionFailedCaseCount,
            fieldPath: "summary.oracleExecutionFailedCaseCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.requiredRequirementCount,
            fieldPath: "summary.requiredRequirementCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.satisfiedRequirementCount,
            fieldPath: "summary.satisfiedRequirementCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.missingRequirementCount,
            fieldPath: "summary.missingRequirementCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.observedCoverageTagCount,
            fieldPath: "summary.observedCoverageTagCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.requiredCoverageTagCount,
            fieldPath: "summary.requiredCoverageTagCount"
        )
        appendNonNegativeIssue(
            &issues,
            value: summary.coveredRequiredCoverageTagCount,
            fieldPath: "summary.coveredRequiredCoverageTagCount"
        )
        if let reportAgeSeconds = summary.reportAgeSeconds, !reportAgeSeconds.isFinite {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_non_finite_report_age_seconds",
                fieldPath: "summary.reportAgeSeconds",
                message: "DRC corpus coverage audit reportAgeSeconds must be finite when present.",
                suggestedActions: ["inspect_drc_corpus_report_timestamps", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        appendCountUpperBoundIssue(
            &issues,
            value: summary.matchedCaseCount,
            upperBound: summary.caseCount,
            fieldPath: "summary.matchedCaseCount",
            upperBoundFieldPath: "summary.caseCount"
        )
        appendCountUpperBoundIssue(
            &issues,
            value: summary.durationBudgetPassedCaseCount,
            upperBound: summary.caseCount,
            fieldPath: "summary.durationBudgetPassedCaseCount",
            upperBoundFieldPath: "summary.caseCount"
        )
        appendCountUpperBoundIssue(
            &issues,
            value: summary.oracleAgreementPassedCaseCount,
            upperBound: summary.oracleCaseCount,
            fieldPath: "summary.oracleAgreementPassedCaseCount",
            upperBoundFieldPath: "summary.oracleCaseCount"
        )
        appendCountUpperBoundIssue(
            &issues,
            value: summary.oracleReadinessBlockedCaseCount,
            upperBound: summary.oracleCaseCount,
            fieldPath: "summary.oracleReadinessBlockedCaseCount",
            upperBoundFieldPath: "summary.oracleCaseCount"
        )
        if summary.satisfiedRequirementCount + summary.missingRequirementCount > summary.requiredRequirementCount {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_requirement_counts_exceed_required",
                fieldPath: "summary.requiredRequirementCount",
                message: "DRC corpus coverage audit satisfied and missing requirement counts exceed requiredRequirementCount.",
                suggestedActions: ["inspect_drc_corpus_coverage_policy", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        let missingRequirementIDs = Set(missingRequirements.map(\.requirementID).filter { !$0.isEmpty })
        if summary.missingRequirementCount != missingRequirementIDs.count {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_missing_requirement_count_mismatch",
                fieldPath: "summary.missingRequirementCount",
                message: "DRC corpus coverage audit missingRequirementCount does not match unique missing requirements.",
                suggestedActions: ["inspect_drc_corpus_coverage_audit", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        if summary.observedCoverageTagCount != observedCoverageTags.count {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_observed_tag_count_mismatch",
                fieldPath: "summary.observedCoverageTagCount",
                message: "DRC corpus coverage audit observedCoverageTagCount does not match observedCoverageTags.",
                suggestedActions: ["inspect_drc_corpus_coverage_tags", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendCoverageFamilyIssues(_ issues: inout [DRCCorpusCoverageAuditIntegrityIssue]) {
        var seenFamilyIDs: Set<String> = []
        for (index, family) in coverageFamilies.enumerated() {
            let prefix = "coverageFamilies[\(index)]"
            appendNonEmptyIssue(&issues, value: family.familyID, fieldPath: "\(prefix).familyID")
            if !family.familyID.isEmpty, !seenFamilyIDs.insert(family.familyID).inserted {
                issues.append(.issue(
                    code: "drc_corpus_coverage_audit_duplicate_family_id",
                    fieldPath: "\(prefix).familyID",
                    message: "DRC corpus coverage audit coverage family \(family.familyID) is duplicated.",
                    suggestedActions: ["inspect_drc_corpus_coverage_families", "regenerate_drc_corpus_coverage_audit"]
                ))
            }
            appendNonNegativeIssue(&issues, value: family.observedCaseCount, fieldPath: "\(prefix).observedCaseCount")
            appendNonNegativeIssue(
                &issues,
                value: family.requiredRequirementCount,
                fieldPath: "\(prefix).requiredRequirementCount"
            )
            appendNonNegativeIssue(
                &issues,
                value: family.satisfiedRequirementCount,
                fieldPath: "\(prefix).satisfiedRequirementCount"
            )
            appendNonNegativeIssue(
                &issues,
                value: family.missingRequirementCount,
                fieldPath: "\(prefix).missingRequirementCount"
            )
            appendUnitRateIssue(&issues, value: family.coveragePassRate, fieldPath: "\(prefix).coveragePassRate")
            if family.satisfiedRequirementCount + family.missingRequirementCount > family.requiredRequirementCount {
                issues.append(.issue(
                    code: "drc_corpus_coverage_audit_family_requirement_counts_exceed_required",
                    fieldPath: "\(prefix).requiredRequirementCount",
                    message: "DRC corpus coverage audit coverage family requirement counts exceed requiredRequirementCount.",
                    suggestedActions: ["inspect_drc_corpus_coverage_families", "regenerate_drc_corpus_coverage_audit"]
                ))
            }
            appendCoverageTagSetIssues(&issues, family: family, prefix: prefix)
        }
    }

    private func appendCoverageTagSetIssues(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        family: CoverageFamilySummary,
        prefix: String
    ) {
        let requiredTags = Set(family.requiredCoverageTags)
        let coveredTags = Set(family.coveredRequiredCoverageTags)
        let missingTags = Set(family.missingRequiredCoverageTags)
        for tag in coveredTags where !requiredTags.contains(tag) {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_covered_tag_not_required",
                fieldPath: "\(prefix).coveredRequiredCoverageTags",
                message: "DRC corpus coverage audit coverage family marks non-required tag \(tag) as covered.",
                suggestedActions: ["inspect_drc_corpus_coverage_families", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        for tag in missingTags where !requiredTags.contains(tag) {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_missing_tag_not_required",
                fieldPath: "\(prefix).missingRequiredCoverageTags",
                message: "DRC corpus coverage audit coverage family marks non-required tag \(tag) as missing.",
                suggestedActions: ["inspect_drc_corpus_coverage_families", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        for tag in coveredTags.intersection(missingTags) {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_tag_both_covered_and_missing",
                fieldPath: "\(prefix).coveredRequiredCoverageTags",
                message: "DRC corpus coverage audit coverage family marks tag \(tag) as both covered and missing.",
                suggestedActions: ["inspect_drc_corpus_coverage_families", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendMissingRequirementIssues(_ issues: inout [DRCCorpusCoverageAuditIntegrityIssue]) {
        var seenRequirementIDs: Set<String> = []
        for (index, requirement) in missingRequirements.enumerated() {
            let prefix = "missingRequirements[\(index)]"
            appendNonEmptyIssue(&issues, value: requirement.requirementID, fieldPath: "\(prefix).requirementID")
            appendNonEmptyIssue(&issues, value: requirement.title, fieldPath: "\(prefix).title")
            appendNonEmptyIssue(&issues, value: requirement.reason, fieldPath: "\(prefix).reason")
            appendNonNegativeIssue(&issues, value: requirement.observedCaseCount, fieldPath: "\(prefix).observedCaseCount")
            appendNonNegativeIssue(&issues, value: requirement.requiredCaseCount, fieldPath: "\(prefix).requiredCaseCount")
            if !requirement.requirementID.isEmpty, !seenRequirementIDs.insert(requirement.requirementID).inserted {
                issues.append(.issue(
                    code: "drc_corpus_coverage_audit_duplicate_missing_requirement_id",
                    fieldPath: "\(prefix).requirementID",
                    message: "DRC corpus coverage audit missing requirement \(requirement.requirementID) is duplicated.",
                    suggestedActions: ["inspect_drc_corpus_coverage_policy", "regenerate_drc_corpus_coverage_audit"]
                ))
            }
        }
    }

    private func appendSuggestedActionIssues(_ issues: inout [DRCCorpusCoverageAuditIntegrityIssue]) {
        let missingRequirementIDs = Set(missingRequirements.map(\.requirementID).filter { !$0.isEmpty })
        var seenActionKeys: Set<String> = []
        for (index, action) in suggestedActions.enumerated() {
            let prefix = "suggestedActions[\(index)]"
            appendNonEmptyIssue(&issues, value: action.actionID, fieldPath: "\(prefix).actionID")
            appendNonEmptyIssue(&issues, value: action.requirementID, fieldPath: "\(prefix).requirementID")
            appendNonEmptyIssue(&issues, value: action.reason, fieldPath: "\(prefix).reason")
            let key = "\(action.actionID):\(action.requirementID)"
            if !action.actionID.isEmpty, !action.requirementID.isEmpty, !seenActionKeys.insert(key).inserted {
                issues.append(.issue(
                    code: "drc_corpus_coverage_audit_duplicate_suggested_action",
                    fieldPath: "\(prefix).actionID",
                    message: "DRC corpus coverage audit suggested action \(key) is duplicated.",
                    suggestedActions: ["inspect_drc_corpus_coverage_actions", "regenerate_drc_corpus_coverage_audit"]
                ))
            }
            if !missingRequirementIDs.isEmpty,
               !action.requirementID.isEmpty,
               !missingRequirementIDs.contains(action.requirementID) {
                issues.append(.issue(
                    code: "drc_corpus_coverage_audit_dangling_suggested_action_requirement",
                    fieldPath: "\(prefix).requirementID",
                    message: "DRC corpus coverage audit suggested action references an unknown missing requirement.",
                    suggestedActions: ["inspect_drc_corpus_coverage_actions", "regenerate_drc_corpus_coverage_audit"]
                ))
            }
        }
    }

    private func appendNonEmptyIssue(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        value: String,
        fieldPath: String
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_required_field_empty",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit field \(fieldPath) must not be empty.",
                suggestedActions: ["inspect_drc_corpus_coverage_audit", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendNonNegativeIssue(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        value: Int,
        fieldPath: String
    ) {
        if value < 0 {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_negative_count",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit count \(fieldPath) cannot be negative.",
                suggestedActions: ["inspect_drc_corpus_coverage_audit_counts", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendCountUpperBoundIssue(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        value: Int,
        upperBound: Int,
        fieldPath: String,
        upperBoundFieldPath: String
    ) {
        if value > upperBound {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_count_exceeds_total",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit count \(fieldPath) exceeds \(upperBoundFieldPath).",
                suggestedActions: ["inspect_drc_corpus_coverage_audit_counts", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendUnitRateIssue(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        value: Double,
        fieldPath: String
    ) {
        if value < 0 || value > 1 || !value.isFinite {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_invalid_unit_rate",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit rate \(fieldPath) must be finite and between 0 and 1.",
                suggestedActions: ["inspect_drc_corpus_coverage_audit_rates", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }

    private func appendPathIssues(
        _ issues: inout [DRCCorpusCoverageAuditIntegrityIssue],
        path: String,
        fieldPath: String
    ) {
        if path.trimmingCharacters(in: .whitespacesAndNewlines) != path {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_path_has_whitespace",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit path \(path) contains leading or trailing whitespace.",
                suggestedActions: ["normalize_drc_corpus_coverage_audit_path", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        if path.contains("://") {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_path_has_url_scheme",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit path \(path) contains a URL scheme.",
                suggestedActions: ["use_local_drc_corpus_report_path", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
        if path.hasPrefix("~") {
            issues.append(.issue(
                code: "drc_corpus_coverage_audit_path_has_home_shortcut",
                fieldPath: fieldPath,
                message: "DRC corpus coverage audit path \(path) starts with a home-directory shortcut.",
                suggestedActions: ["expand_drc_corpus_report_path", "regenerate_drc_corpus_coverage_audit"]
            ))
        }
    }
}
