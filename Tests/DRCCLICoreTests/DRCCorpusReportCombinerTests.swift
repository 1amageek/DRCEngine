import Testing
import DRCCore

@Suite("DRC corpus report combiner")
struct DRCCorpusReportCombinerTests {
    @Test func mixedEvidenceKindsAndDuplicateCaseIDsAreNotQualified() {
        let primary = report(evidenceKind: .regression, caseID: "same")
        let included = report(evidenceKind: .independentCorrelation, caseID: "same")

        let combined = DRCCorpusReportCombiner().combine(
            primaryReport: primary,
            includedReports: [included]
        )

        #expect(combined.evidenceKind == .regression)
        #expect(!combined.assessment.meetsCriteria)
        #expect(combined.assessment.findings.contains { $0.code == "mixed_evidence_kinds" })
        #expect(combined.assessment.findings.contains { $0.code == "duplicate_case_ids" })
    }

    @Test func homogeneousIndependentEvidenceKeepsItsQualificationLane() {
        let primary = report(evidenceKind: .independentCorrelation, caseID: "primary")
        let included = report(evidenceKind: .independentCorrelation, caseID: "included")

        let combined = DRCCorpusReportCombiner().combine(
            primaryReport: primary,
            includedReports: [included]
        )

        #expect(combined.evidenceKind == .independentCorrelation)
        #expect(combined.assessment.criteria.requireIndependentOracle)
    }

    private func report(
        evidenceKind: DRCCorpusEvidenceKind,
        caseID: String
    ) -> DRCCorpusReport {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let result = DRCCorpusCaseResult(
            caseID: caseID,
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            expectationMatched: true,
            durationSeconds: 0.1,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: nil,
            manifestPath: nil
        )
        return DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            evidenceKind: evidenceKind,
            caseResults: [result]
        )
    }
}
