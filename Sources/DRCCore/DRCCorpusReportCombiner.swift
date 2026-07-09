public struct DRCCorpusReportCombiner: Sendable {
    public init() {}

    public func combine(
        primaryReport: DRCCorpusReport,
        includedReports: [DRCCorpusReport]
    ) -> DRCCorpusReport {
        let reports = [primaryReport] + includedReports
        let caseResults = reports.flatMap(\.caseResults)
        let passed = reports.allSatisfy(\.passed) && caseResults.allSatisfy(\.matched)
        let summary = DRCCorpusSummary(caseResults: caseResults)
        let qualificationPolicy = DRCCorpusQualificationPolicy.strict
        let baseQualification = qualificationPolicy.evaluate(
            passed: passed,
            caseCount: caseResults.count,
            summary: summary
        )
        let sourceFailures = reports.enumerated().flatMap { index, report in
            report.qualification.qualified ? [] : [
                DRCCorpusQualificationFailure(
                    code: "included_report_not_qualified",
                    message: "One or more source corpus reports did not qualify.",
                    observedCount: index,
                    requiredCount: 0
                ),
            ]
        }
        return DRCCorpusReport(
            generatedAt: combinedGeneratedAt(from: reports),
            passed: passed,
            caseCount: caseResults.count,
            matchedCaseCount: caseResults.filter(\.matched).count,
            budgetExceededCaseCount: caseResults.filter { !$0.durationBudgetPassed }.count,
            totalDurationSeconds: reports.reduce(0) { $0 + $1.totalDurationSeconds },
            runOptions: primaryReport.runOptions,
            summary: summary,
            qualificationPolicy: qualificationPolicy,
            qualification: DRCCorpusQualificationResult(
                policy: qualificationPolicy,
                failures: baseQualification.failures + sourceFailures
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
