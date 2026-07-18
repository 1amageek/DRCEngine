public struct DRCCorpusReportCombiner: Sendable {
    public init() {}

    public func combine(
        primaryReport: DRCCorpusReport,
        includedReports: [DRCCorpusReport]
    ) -> DRCCorpusReport {
        let reports = [primaryReport] + includedReports
        let caseResults = reports.flatMap(\.caseResults)
        let completed = reports.allSatisfy(\.completed)
        let passed = reports.allSatisfy(\.passed) && caseResults.allSatisfy(\.matched)
        let summary = DRCCorpusSummary(caseResults: caseResults)
        let evidenceKinds = Set(reports.map(\.evidenceKind))
        let evidenceKind: DRCCorpusEvidenceKind = evidenceKinds.count == 1
            ? (evidenceKinds.first ?? .regression)
            : .regression
        let acceptanceCriteria = DRCCorpusAcceptanceCriteria.strict.with(
            requireIndependentOracle: evidenceKind.requiresIndependentOracle
        )
        let baseAssessment = acceptanceCriteria.evaluate(
            passed: passed,
            caseCount: caseResults.count,
            summary: summary,
            completed: completed
        )
        let sourceFindings = reports.enumerated().flatMap { index, report in
            report.assessment.meetsCriteria ? [] : [
                DRCCorpusAssessmentFinding(
                    code: "included_report_not_qualified",
                    message: "One or more source corpus reports did not qualify.",
                    observedCount: index,
                    requiredCount: 0
                ),
            ]
        }
        let duplicateCaseIDs = Dictionary(grouping: caseResults, by: \.caseID)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        var combinationFindings = sourceFindings
        if evidenceKinds.count > 1 {
            combinationFindings.append(DRCCorpusAssessmentFinding(
                code: "mixed_evidence_kinds",
                message: "Corpus reports with different evidence kinds cannot be combined into one assessment lane.",
                observedCount: evidenceKinds.count,
                requiredCount: 1,
                observedText: evidenceKinds.map(\.rawValue).sorted().joined(separator: ","),
                requiredText: primaryReport.evidenceKind.rawValue
            ))
        }
        if !duplicateCaseIDs.isEmpty {
            combinationFindings.append(DRCCorpusAssessmentFinding(
                code: "duplicate_case_ids",
                message: "Combined corpus reports contain duplicate case IDs.",
                observedCount: duplicateCaseIDs.count,
                requiredCount: 0,
                observedText: duplicateCaseIDs.joined(separator: ",")
            ))
        }
        return DRCCorpusReport(
            generatedAt: combinedGeneratedAt(from: reports),
            runID: nil,
            parentRunID: nil,
            specSHA256: nil,
            completed: completed,
            passed: passed,
            caseCount: caseResults.count,
            matchedCaseCount: caseResults.filter(\.matched).count,
            budgetExceededCaseCount: caseResults.filter { !$0.durationBudgetPassed }.count,
            totalDurationSeconds: reports.reduce(0) { $0 + $1.totalDurationSeconds },
            evidenceKind: evidenceKind,
            runOptions: primaryReport.runOptions,
            summary: summary,
            acceptanceCriteria: acceptanceCriteria,
            assessment: DRCCorpusAssessment(
                criteria: acceptanceCriteria,
                findings: baseAssessment.findings + combinationFindings
            ),
            caseResults: caseResults
        )
    }

    private func combinedGeneratedAt(from reports: [DRCCorpusReport]) -> String? {
        let timestamps = reports.compactMap(\.generatedAt)
        guard timestamps.count == reports.count else {
            return nil
        }
        return timestamps.min()
    }
}
