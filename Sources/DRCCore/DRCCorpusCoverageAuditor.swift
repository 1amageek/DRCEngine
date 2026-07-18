import Foundation

public struct DRCCorpusCoverageAuditor: Sendable {
    public init() {}

    public func audit(
        report: DRCCorpusReport,
        reportPath: String? = nil,
        policy: DRCCorpusCoverageAuditPolicy = .magicFoundryExpansion,
        auditID: String? = nil,
        checkedAt: Date? = nil
    ) -> DRCCorpusCoverageAudit {
        let observedTags = Set(report.summary.coverageTagCounts.keys)
        let requiredTags = Set(policy.requirements.flatMap(\.requiredCoverageTags))
        var missingRequirements = missingPolicyRequirements(
            report: report,
            policy: policy,
            observedTags: observedTags
        )
        let policyValidationErrors = policy.validationErrors
        missingRequirements.append(contentsOf: policyValidationErrors.enumerated().map { index, error in
            DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "coverage-policy-invalid-\(index + 1)",
                title: "Valid coverage policy",
                missingCoverageTags: [],
                observedCaseCount: 0,
                requiredCaseCount: 1,
                reason: error.message,
                suggestedActions: ["fix_drc_corpus_coverage_policy"]
            )
        })
        let freshness = reportFreshness(
            report: report,
            policy: policy,
            checkedAt: checkedAt
        )
        if let missingRequirement = freshness.missingRequirement {
            missingRequirements.append(missingRequirement)
        }

        if policy.requirePassingAssessment, !report.assessment.meetsCriteria {
            missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                requirementID: "passing-corpus-assessment",
                title: "Passing corpus assessment",
                missingCoverageTags: [],
                observedCaseCount: report.matchedCaseCount,
                requiredCaseCount: report.caseCount,
                reason: "The corpus assessment did not meet its criteria.",
                suggestedActions: ["inspect_drc_corpus_failures", "fix_or_mark_blocked_drc_oracle_cases"]
            ))
        }
        if policy.requireIndependentOracle {
            let nonIndependentCases = report.caseResults.compactMap { caseResult -> String? in
                guard let oracleResult = caseResult.oracleResult else {
                    return nil
                }
                let primaryBackendID = caseResult.primaryProvenance?.backendID
                    ?? caseResult.oracleComparison?.primaryBackendID
                guard let primaryBackendID else {
                    return "\(caseResult.caseID):reference_independence_unproven"
                }
                let primaryIdentity = caseResult.primaryProvenance?.backendIdentity
                    ?? DRCBackendIdentity(backendID: primaryBackendID)
                let oracleIdentity = oracleResult.backendIdentity
                    ?? DRCBackendIdentity(backendID: oracleResult.backendID)
                guard let failureCode = primaryIdentity.independenceFailureCode(comparedTo: oracleIdentity) else {
                    return nil
                }
                return "\(caseResult.caseID):\(failureCode)"
            }
            let missingOracleCaseCount = max(0, report.caseCount - report.summary.oracleCaseCount)
            if !nonIndependentCases.isEmpty || missingOracleCaseCount > 0 {
                missingRequirements.append(DRCCorpusCoverageAudit.MissingRequirement(
                    requirementID: "independent-oracle",
                    title: "Independent oracle",
                    missingCoverageTags: [],
                    observedCaseCount: max(
                        0,
                        report.summary.oracleCaseCount - nonIndependentCases.count
                    ),
                    requiredCaseCount: report.caseCount,
                    reason: missingOracleCaseCount > 0
                        ? "Independent-oracle assessment requires an oracle comparison for every corpus case."
                        : "One or more oracle comparisons use the same backend implementation family or lack verifiable backend identity.",
                    suggestedActions: missingOracleCaseCount > 0
                        ? ["run_drc_corpus_with_independent_reference", "inspect_drc_oracle_readiness"]
                        : ["replace_self_oracle_with_independent_reference", "inspect_drc_backend_identity"]
                ))
            }
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
                observedCaseCount: max(
                    0,
                    report.summary.oracleCaseCount - report.summary.oracleReadinessBlockedCaseCount
                ),
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
        let coverageFamilies = coverageFamilySummaries(
            report: report,
            policy: policy,
            observedTags: observedTags,
            requiredTags: requiredTags,
            missingRequirementIDs: missingRequirementIDs
        )
        let requiredRequirementCount = policy.requirements.count
            + policyValidationErrors.count
            + (policy.requirePassingAssessment ? 1 : 0)
            + (policy.requireOracleAgreement ? 1 : 0)
            + (policy.requireIndependentOracle ? 1 : 0)
            + (policy.requireOracleReadiness ? 1 : 0)
            + (policy.requireDurationBudget ? 1 : 0)
            + (policy.maxReportAgeSeconds == nil ? 0 : 1)
            + (policy.minimumCaseCount > 0 ? 1 : 0)
        let durationBudgetPassRate = report.caseCount == 0
            ? 0
            : Double(report.summary.durationBudgetPassedCaseCount) / Double(report.caseCount)

        return DRCCorpusCoverageAudit(
            auditID: auditID ?? defaultAuditID(reportPath: reportPath, policyID: policy.policyID),
            status: status,
            policyID: policy.policyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "invalid-policy"
                : policy.policyID,
            reportPath: reportPath,
            summary: DRCCorpusCoverageAudit.Summary(
                caseCount: report.caseCount,
                matchedCaseCount: report.matchedCaseCount,
                meetsCriteria: report.assessment.meetsCriteria,
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
                coveredRequiredCoverageTagCount: coveredRequiredTags.count,
                reportGeneratedAt: report.generatedAt,
                checkedAt: freshness.checkedAtString,
                reportAgeSeconds: freshness.ageSeconds
            ),
            observedCoverageTags: observedTags.sorted(),
            coverageFamilies: coverageFamilies,
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

    private func coverageFamilySummaries(
        report: DRCCorpusReport,
        policy: DRCCorpusCoverageAuditPolicy,
        observedTags: Set<String>,
        requiredTags: Set<String>,
        missingRequirementIDs: Set<String>
    ) -> [DRCCorpusCoverageAudit.CoverageFamilySummary] {
        let familyIDs = Set(observedTags.union(requiredTags).map(familyID(for:)))
        return familyIDs.sorted().map { familyID in
            let observedFamilyTags = observedTags.filter { self.familyID(for: $0) == familyID }
            let requiredFamilyTags = requiredTags.filter { self.familyID(for: $0) == familyID }
            let coveredRequiredTags = requiredFamilyTags.filter { observedTags.contains($0) }
            let missingRequiredTags = requiredFamilyTags.filter { !observedTags.contains($0) }
            let relatedRequirements = policy.requirements.filter { requirement in
                requirement.requiredCoverageTags.contains { self.familyID(for: $0) == familyID }
            }
            let missingRequirementCount = relatedRequirements.filter {
                missingRequirementIDs.contains($0.requirementID)
            }.count
            let observedCaseCount = report.caseResults.filter { result in
                result.coverageTags.contains { self.familyID(for: $0) == familyID }
            }.count
            let coveragePassRate = requiredFamilyTags.isEmpty
                ? 1
                : Double(coveredRequiredTags.count) / Double(requiredFamilyTags.count)

            return DRCCorpusCoverageAudit.CoverageFamilySummary(
                familyID: familyID,
                observedCoverageTags: observedFamilyTags.sorted(),
                requiredCoverageTags: requiredFamilyTags.sorted(),
                coveredRequiredCoverageTags: coveredRequiredTags.sorted(),
                missingRequiredCoverageTags: missingRequiredTags.sorted(),
                observedCaseCount: observedCaseCount,
                requiredRequirementCount: relatedRequirements.count,
                satisfiedRequirementCount: max(0, relatedRequirements.count - missingRequirementCount),
                missingRequirementCount: missingRequirementCount,
                coveragePassRate: coveragePassRate
            )
        }
    }

    private func familyID(for coverageTag: String) -> String {
        let parts = coverageTag.split(separator: ".").map(String.init)
        guard let firstPart = parts.first else { return coverageTag }
        if firstPart == "drc", parts.count >= 2 {
            return parts.prefix(2).joined(separator: ".")
        }
        return firstPart
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

    private func reportFreshness(
        report: DRCCorpusReport,
        policy: DRCCorpusCoverageAuditPolicy,
        checkedAt: Date?
    ) -> (
        checkedAtString: String?,
        ageSeconds: Double?,
        missingRequirement: DRCCorpusCoverageAudit.MissingRequirement?
    ) {
        guard let maxReportAgeSeconds = policy.maxReportAgeSeconds else {
            return (checkedAt.map { iso8601String(from: $0) }, nil, nil)
        }
        guard maxReportAgeSeconds.isFinite, maxReportAgeSeconds >= 0 else {
            return (checkedAt.map { iso8601String(from: $0) }, nil, nil)
        }
        guard let checkedAt else {
            return (
                nil,
                nil,
                freshnessMissingRequirement(
                    observedAgeSeconds: nil,
                    requiredAgeSeconds: maxReportAgeSeconds,
                    reason: "The coverage audit policy requires a checkedAt timestamp."
                )
            )
        }
        let checkedAtString = iso8601String(from: checkedAt)
        guard let generatedAt = report.generatedAt, !generatedAt.isEmpty else {
            return (
                checkedAtString,
                nil,
                freshnessMissingRequirement(
                    observedAgeSeconds: nil,
                    requiredAgeSeconds: maxReportAgeSeconds,
                    reason: "The retained DRC corpus report does not include generatedAt."
                )
            )
        }
        guard let generatedAtDate = iso8601Date(from: generatedAt) else {
            return (
                checkedAtString,
                nil,
                freshnessMissingRequirement(
                    observedAgeSeconds: nil,
                    requiredAgeSeconds: maxReportAgeSeconds,
                    reason: "The retained DRC corpus report generatedAt timestamp is invalid."
                )
            )
        }
        let ageSeconds = checkedAt.timeIntervalSince(generatedAtDate)
        if ageSeconds < 0 {
            return (
                checkedAtString,
                ageSeconds,
                freshnessMissingRequirement(
                    observedAgeSeconds: ageSeconds,
                    requiredAgeSeconds: maxReportAgeSeconds,
                    reason: "The retained DRC corpus report generatedAt timestamp is newer than checkedAt."
                )
            )
        }
        if ageSeconds > maxReportAgeSeconds {
            return (
                checkedAtString,
                ageSeconds,
                freshnessMissingRequirement(
                    observedAgeSeconds: ageSeconds,
                    requiredAgeSeconds: maxReportAgeSeconds,
                    reason: "The retained DRC corpus report is older than the coverage audit policy allows."
                )
            )
        }
        return (checkedAtString, ageSeconds, nil)
    }

    private func freshnessMissingRequirement(
        observedAgeSeconds: Double?,
        requiredAgeSeconds: Double,
        reason: String
    ) -> DRCCorpusCoverageAudit.MissingRequirement {
        DRCCorpusCoverageAudit.MissingRequirement(
            requirementID: "retained-report-freshness",
            title: "Retained report freshness",
            missingCoverageTags: [],
            observedCaseCount: observedAgeSeconds.map { max(0, Int($0)) } ?? 0,
            requiredCaseCount: Int(requiredAgeSeconds),
            reason: reason,
            suggestedActions: ["rerun_drc_corpus_and_retain_report"]
        )
    }

    private func iso8601Date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
