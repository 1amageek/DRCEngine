import Testing
import DRCCore

@Suite("DRC corpus evidence kind")
struct DRCCorpusEvidenceKindTests {
    @Test func corpusCaseCanonicalIdentityIsValidated() {
        let invalid = DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "identity",
                layoutPath: "layout.json",
                topCell: "top",
                canonicalStateDigest: "not-a-digest",
                expectedPassed: true
            ),
        ])

        #expect(throws: DRCError.self) {
            try invalid.validate()
        }
    }

    @Test func independentCorrelationAutomaticallyRequiresIndependentOracle() {
        let spec = DRCCorpusSpec(
            evidenceKind: .independentCorrelation,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(),
            cases: []
        )
        #expect(spec.effectiveAcceptanceCriteria.requireIndependentOracle)
    }

    @Test func regressionKeepsExplicitPolicyWithoutPromotingEvidence() {
        let spec = DRCCorpusSpec(
            evidenceKind: .regression,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(),
            cases: []
        )
        #expect(spec.evidenceKind == .regression)
        #expect(!spec.effectiveAcceptanceCriteria.requireIndependentOracle)
    }

    @Test func corpusSpecValidationRejectsDuplicateCaseIDsBeforeExecution() {
        let caseValue = DRCCorpusCase(
            caseID: "duplicate",
            layoutPath: "layout.json",
            topCell: "top",
            expectedPassed: true
        )
        let spec = DRCCorpusSpec(cases: [caseValue, caseValue])

        #expect(throws: DRCError.self) {
            try spec.validate()
        }
    }

    @Test func corpusSpecValidationRejectsInvalidCaseEnvironment() {
        let spec = DRCCorpusSpec(cases: [DRCCorpusCase(
            caseID: "invalid-environment",
            layoutPath: "layout.json",
            topCell: "top",
            additionalEnvironment: ["1INVALID": "value"],
            expectedPassed: true
        )])

        #expect(throws: DRCError.self) {
            try spec.validate()
        }
    }

    @Test func independentQualificationRejectsMissingOracleCases() {
        let summary = DRCCorpusSummary(
            expectationMatchedCaseCount: 1,
            durationBudgetPassedCaseCount: 1,
            primaryExecutionFailedCaseCount: 0,
            oracleCaseCount: 0,
            oracleAgreementPassedCaseCount: 0,
            oracleExecutionFailedCaseCount: 0,
            failureCategoryCounts: [:],
            passRate: 1,
            oracleAgreementRate: nil
        )
        let result = DRCCorpusAcceptanceCriteria(requireIndependentOracle: true).evaluate(
            passed: true,
            caseCount: 1,
            summary: summary
        )

        #expect(result.findings.contains { $0.code == "independent_oracle_missing" })
    }

    @Test func missingOracleAgreementDoesNotHideOtherQualificationFailures() {
        let summary = DRCCorpusSummary(
            expectationMatchedCaseCount: 0,
            durationBudgetPassedCaseCount: 0,
            primaryExecutionFailedCaseCount: 1,
            oracleCaseCount: 0,
            oracleAgreementPassedCaseCount: 0,
            oracleExecutionFailedCaseCount: 0,
            failureCategoryCounts: [:],
            passRate: 0,
            oracleAgreementRate: nil
        )
        let policy = DRCCorpusAcceptanceCriteria(
            minimumOracleAgreementRate: 1,
            requireIndependentOracle: true
        )
        let result = policy.evaluate(passed: false, caseCount: 1, summary: summary)

        #expect(result.findings.contains { $0.code == "oracle_agreement_rate_missing" })
        #expect(result.findings.contains { $0.code == "independent_oracle_missing" })
        #expect(result.findings.contains { $0.code == "primary_execution_failed" })
    }

    @Test func corpusReportValidationRejectsTamperedCaseCounts() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseResult = DRCCorpusCaseResult(
            caseID: "case",
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
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 2,
            matchedCaseCount: 2,
            caseResults: [caseResult]
        )

        #expect(throws: DRCError.self) {
            try report.validate()
        }
    }

    @Test func independentReportConstructorUsesIndependentQualificationPolicy() {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseResult = DRCCorpusCaseResult(
            caseID: "independent-without-oracle",
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
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            evidenceKind: .independentCorrelation,
            caseResults: [caseResult]
        )

        #expect(!report.assessment.meetsCriteria)
        #expect(report.assessment.findings.contains { $0.code == "independent_oracle_missing" })
    }
}
