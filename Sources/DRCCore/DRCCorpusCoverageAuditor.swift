public struct DRCCorpusCoverageAuditor: Sendable {
    public init() {}

    public func audit(
        report: DRCCorpusReport,
        reportPath: String? = nil,
        policy: DRCCorpusCoverageAuditPolicy = .magicFoundryExpansion,
        auditID: String? = nil
    ) -> DRCCorpusCoverageAudit {
        let observedTags = Set(report.summary.coverageTagCounts.keys)
        let requiredTags = Set(policy.requirements.flatMap(\.requiredCoverageTags))
        var missingRequirements = missingPolicyRequirements(
            report: report,
            policy: policy,
            observedTags: observedTags
        )

        if policy.requireQualifiedCorpus, !report.qualification.qualified {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "qualified-corpus",
                title: "Qualified corpus",
                missingCoverageTags: [],
                observedCaseCount: report.matchedCaseCount,
                requiredCaseCount: report.caseCount,
                reason: "The corpus qualification did not pass.",
                suggestedActions: ["inspect_drc_corpus_failures", "fix_or_mark_blocked_drc_oracle_cases"]
            ))
        }
        if policy.requireOracleAgreement, report.summary.oracleCaseCount == 0 {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "oracle-agreement",
                title: "Oracle agreement",
                missingCoverageTags: [],
                observedCaseCount: 0,
                requiredCaseCount: max(1, report.caseCount),
                reason: "No oracle comparison cases are present.",
                suggestedActions: ["run_drc_corpus_with_magic_oracle"]
            ))
        } else if policy.requireOracleAgreement,
                  report.summary.oracleAgreementPassedCaseCount < report.summary.oracleCaseCount {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "oracle-agreement",
                title: "Oracle agreement",
                missingCoverageTags: [],
                observedCaseCount: report.summary.oracleAgreementPassedCaseCount,
                requiredCaseCount: report.summary.oracleCaseCount,
                reason: "One or more oracle comparison cases disagree or are blocked.",
                suggestedActions: ["inspect_drc_oracle_comparison", "classify_drc_oracle_disagreement"]
            ))
        }
        if policy.requireOracleReadiness, report.summary.oracleReadinessBlockedCaseCount > 0 {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "oracle-readiness",
                title: "Oracle readiness",
                missingCoverageTags: [],
                observedCaseCount: report.summary.oracleCaseCount - report.summary.oracleReadinessBlockedCaseCount,
                requiredCaseCount: report.summary.oracleCaseCount,
                reason: "One or more oracle cases are blocked before benchmark comparison.",
                suggestedActions: ["inspect_drc_oracle_readiness", "fix_drc_magic_input_technology_mapping"]
            ))
        }
        if policy.requireDurationBudget, report.summary.durationBudgetPassedCaseCount < report.caseCount {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "duration-budget",
                title: "Duration budget",
                missingCoverageTags: [],
                observedCaseCount: report.summary.durationBudgetPassedCaseCount,
                requiredCaseCount: report.caseCount,
                reason: "One or more corpus cases exceeded their duration budget.",
                suggestedActions: ["inspect_drc_duration_budget", "split_or_optimize_slow_drc_cases"]
            ))
        }
        if report.caseCount < policy.minimumCaseCount {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "minimum-case-count",
                title: "Minimum case count",
                missingCoverageTags: [],
                observedCaseCount: report.caseCount,
                requiredCaseCount: policy.minimumCaseCount,
                reason: "The corpus has fewer cases than the policy requires.",
                suggestedActions: ["add_drc_oracle_corpus_cases"]
            ))
        }

        let missingRequirementIDs = Set(missingRequirements.map(\.requirementID))
        let suggestedActions = missingRequirements.flatMap { requirement in
            requirement.suggestedActions.map { action in
                DRCCorpusCoverageAudit.SuggestedAction(
                    actionID: action,
                    requirementID: requirement.requirementID,
                    reason: requirement.reason
                )
            }
        }
        let status: DRCCorpusCoverageAuditStatus = missingRequirements.isEmpty ? .satisfied : .incomplete
        let coveredRequiredTags = requiredTags.intersection(observedTags)
        let requiredRequirementCount = policy.requirements.count
            + (policy.requireQualifiedCorpus ? 1 : 0)
            + (policy.requireOracleAgreement ? 1 : 0)
            + (policy.requireOracleReadiness ? 1 : 0)
            + (policy.requireDurationBudget ? 1 : 0)
            + (policy.minimumCaseCount > 0 ? 1 : 0)
        let durationBudgetPassRate = report.caseCount == 0
            ? 1
            : Double(report.summary.durationBudgetPassedCaseCount) / Double(report.caseCount)

        return DRCCorpusCoverageAudit(
            auditID: auditID ?? defaultAuditID(reportPath: reportPath, policyID: policy.policyID),
            status: status,
            policyID: policy.policyID,
            reportPath: reportPath,
            summary: DRCCorpusCoverageAudit.Summary(
                caseCount: report.caseCount,
                matchedCaseCount: report.matchedCaseCount,
                qualified: report.qualification.qualified,
                durationBudgetPassedCaseCount: report.summary.durationBudgetPassedCaseCount,
                durationBudgetPassRate: durationBudgetPassRate,
                oracleCaseCount: report.summary.oracleCaseCount,
                oracleAgreementPassedCaseCount: report.summary.oracleAgreementPassedCaseCount,
                oracleReadinessBlockedCaseCount: report.summary.oracleReadinessBlockedCaseCount,
                oracleExecutionFailedCaseCount: report.summary.oracleExecutionFailedCaseCount,
                requiredRequirementCount: requiredRequirementCount,
                satisfiedRequirementCount: max(0, requiredRequirementCount - missingRequirementIDs.count),
                missingRequirementCount: missingRequirementIDs.count,
                observedCoverageTagCount: observedTags.count,
                requiredCoverageTagCount: requiredTags.count,
                coveredRequiredCoverageTagCount: coveredRequiredTags.count
            ),
            observedCoverageTags: observedTags.sorted(),
            missingRequirements: missingRequirements,
            suggestedActions: uniqueSuggestedActions(suggestedActions)
        )
    }

    private func missingPolicyRequirements(
        report: DRCCorpusReport,
        policy: DRCCorpusCoverageAuditPolicy,
        observedTags: Set<String>
    ) -> [DRCCorpusCoverageAudit.MissingRequirement] {
        policy.requirements.compactMap { requirement in
            let requiredTags = Set(requirement.requiredCoverageTags)
            let missingTags = requiredTags.subtracting(observedTags).sorted()
            let observedCaseCount = report.caseResults.filter { result in
                let resultTags = Set(result.coverageTags)
                return requiredTags.isEmpty || requiredTags.isSubset(of: resultTags)
            }.count
            guard !missingTags.isEmpty || observedCaseCount < requirement.minimumCaseCount else {
                return nil
            }
            return DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: requirement.requirementID,
                title: requirement.title,
                missingCoverageTags: missingTags,
                observedCaseCount: observedCaseCount,
                requiredCaseCount: requirement.minimumCaseCount,
                reason: missingTags.isEmpty
                    ? "The required coverage tags exist, but too few cases contain them together."
                    : "Required coverage tags are missing from the corpus report.",
                suggestedActions: requirement.suggestedActions
            )
        }
    }

    private func uniqueSuggestedActions(
        _ actions: [DRCCorpusCoverageAudit.SuggestedAction]
    ) -> [DRCCorpusCoverageAudit.SuggestedAction] {
        var seen: Set<String> = []
        var result: [DRCCorpusCoverageAudit.SuggestedAction] = []
        for action in actions.sorted(by: { $0.actionID < $1.actionID }) {
            let key = "\(action.actionID):\(action.requirementID)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(action)
        }
        return result
    }

    private func defaultAuditID(reportPath: String?, policyID: String) -> String {
        guard let reportPath, !reportPath.isEmpty else {
            return "drc-corpus-coverage-audit:\(policyID)"
        }
        return "drc-corpus-coverage-audit:\(policyID):\(reportPath)"
    }
}
