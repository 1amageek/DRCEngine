import Testing
import DRCCore

@Suite("DRC corpus evidence validation")
struct DRCCorpusEvidenceValidationTests {
    @Test func persistedAssessmentIsCanonicalizedFromCaseResultsAndCriteria() throws {
        let result = caseResult(caseID: "clean")
        let forgedAssessment = DRCCorpusAssessment(
            criteria: DRCCorpusAcceptanceCriteria(requiredCoverageTags: ["missing-tag"]),
            findings: []
        )
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            summary: DRCCorpusSummary(caseResults: [result]),
            assessment: forgedAssessment,
            caseResults: [result]
        )

        #expect(!report.assessment.meetsCriteria)
        #expect(report.assessment.findings.contains { $0.code == "required_coverage_missing" })
        try report.validateEvidence()
    }

    @Test func persistedSummaryMustMatchCaseResults() throws {
        let result = caseResult(caseID: "clean")
        let staleSummary = DRCCorpusSummary(
            expectationMatchedCaseCount: 0,
            durationBudgetPassedCaseCount: 0,
            primaryExecutionFailedCaseCount: 1,
            oracleCaseCount: 0,
            oracleAgreementPassedCaseCount: 0,
            oracleExecutionFailedCaseCount: 0,
            failureCategoryCounts: ["primary_execution_failed": 1],
            passRate: 0,
            oracleAgreementRate: nil
        )
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            summary: staleSummary,
            caseResults: [result]
        )

        #expect(throws: DRCError.self) {
            try report.validateEvidence()
        }
    }

    @Test func corpusNamespaceRejectsSanitizedCaseIDCollisions() {
        let first = DRCCorpusCase(
            caseID: "a/b",
            layoutPath: "a.json",
            topCell: "top",
            expectedPassed: true
        )
        let second = DRCCorpusCase(
            caseID: "a_b",
            layoutPath: "b.json",
            topCell: "top",
            expectedPassed: true
        )

        #expect(throws: DRCError.self) {
            try DRCCorpusSpec(cases: [first, second]).validate()
        }
    }

    @Test func verdictSeparatesUnsupportedAndIncompleteResults() {
        let unsupported = DRCResult(
            backendID: "native-gds",
            toolName: "LayoutVerify",
            success: true,
            completed: true,
            logPath: "",
            diagnostics: [DRCDiagnostic(
                severity: .error,
                message: "Path geometry is unsupported.",
                ruleID: "drc.unsupported_exact_geometry",
                rawLine: "unsupported"
            )]
        )
        let incomplete = DRCResult(
            backendID: "native-gds",
            toolName: "LayoutVerify",
            success: true,
            completed: false,
            logPath: ""
        )

        #expect(unsupported.verdict == DRCVerdict.unsupported)
        #expect(incomplete.verdict == DRCVerdict.incomplete)
    }

    @Test func executionFailureTakesPrecedenceOverIncompleteState() {
        let failedExecution = DRCResult(
            backendID: "magic",
            toolName: "Magic",
            success: false,
            completed: false,
            logPath: ""
        )

        #expect(failedExecution.verdict == DRCVerdict.executionFailed)
    }

    @Test func completedDiagnosticFailureIsNotMisclassifiedAsIncomplete() {
        let failed = DRCResult(
            backendID: "native-gds",
            toolName: "LayoutVerify",
            success: true,
            completed: true,
            logPath: "",
            diagnostics: [DRCDiagnostic(
                severity: .error,
                message: "Hierarchy contains a missing child cell.",
                ruleID: "drc.missing_child_cell",
                kind: "layout-diagnostic",
                rawLine: "hierarchy"
            )]
        )

        #expect(failed.verdict == DRCVerdict.failed)
    }

    private func caseResult(caseID: String) -> DRCCorpusCaseResult {
        DRCCorpusCaseResult(
            caseID: caseID,
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            expectationMatched: true,
            durationSeconds: 0.01,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0),
            reportPath: nil,
            manifestPath: nil
        )
    }
}
