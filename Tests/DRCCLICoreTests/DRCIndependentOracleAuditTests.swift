import Foundation
import Testing
import DRCCore

@Suite("DRC independent oracle audit")
struct DRCIndependentOracleAuditTests {
    @Test func acceptanceCriteriaPersistsAndFailsIndependentOracleGate() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let oracle = DRCCorpusOracleResult(
            backendID: "magic",
            passed: true,
            activeErrorRuleIDs: [],
            diagnosticSummary: summary,
            durationSeconds: 0.1,
            agreementPassed: false,
            readinessStatus: .blocked,
            failureReasons: ["same_backend_reference"],
            reportPath: nil,
            manifestPath: nil
        )
        let caseResult = DRCCorpusCaseResult(
            caseID: "self-oracle",
            matched: false,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: ["external.magic"],
            expectationMatched: true,
            durationSeconds: 0.1,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: ["oracle_agreement_mismatch", "same_backend_reference"],
            diagnosticSummary: summary,
            reportPath: nil,
            manifestPath: nil,
            oracleResult: oracle
        )
        let report = DRCCorpusReport(
            passed: false,
            caseCount: 1,
            matchedCaseCount: 0,
            caseResults: [caseResult]
        )

        #expect(report.summary.nonIndependentOracleCaseCount == 1)
        let policy = DRCCorpusAcceptanceCriteria(requireIndependentOracle: true)
        let qualification = policy.evaluate(
            passed: report.passed,
            caseCount: report.caseCount,
            summary: report.summary
        )
        #expect(qualification.findings.contains { $0.code == "independent_oracle_failed" })

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(DRCCorpusAcceptanceCriteria.self, from: data)
        #expect(decoded.requireIndependentOracle)
    }

    @Test func defaultFoundryPolicyRejectsRetainedSelfOracle() {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let result = DRCCorpusCaseResult(
            caseID: "self-oracle",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: ["external.magic", "layout.gds"],
            expectationMatched: true,
            durationSeconds: 0.1,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: "/tmp/self-oracle/report.json",
            manifestPath: "/tmp/self-oracle/manifest.json",
            primaryProvenance: DRCCorpusCaseProvenance(
                backendID: "magic",
                reportPath: "/tmp/self-oracle/report.json",
                manifestPath: "/tmp/self-oracle/manifest.json"
            ),
            oracleResult: DRCCorpusOracleResult(
                backendID: "magic",
                passed: true,
                activeErrorRuleIDs: [],
                diagnosticSummary: summary,
                durationSeconds: 0.1,
                agreementPassed: true,
                readinessStatus: .ready,
                failureReasons: [],
                reportPath: "/tmp/self-oracle/oracle-report.json",
                manifestPath: "/tmp/self-oracle/oracle-manifest.json"
            )
        )
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            caseResults: [result]
        )

        let audit = DRCCorpusCoverageAuditor().audit(
            report: report,
            policy: .magicFoundryExpansion,
            checkedAt: Date()
        )

        #expect(audit.status == .incomplete)
        #expect(audit.missingRequirements.contains { $0.requirementID == "independent-oracle" })
        #expect(audit.suggestedActions.contains { $0.actionID == "replace_self_oracle_with_independent_reference" })
    }

    @Test func retainedBackendIdentityOverridesAmbiguousBackendIDs() {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let result = DRCCorpusCaseResult(
            caseID: "explicit-identities",
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
            manifestPath: nil,
            primaryProvenance: DRCCorpusCaseProvenance(
                backendID: "custom-primary",
                backendIdentity: DRCBackendIdentity(
                    backendID: "custom-primary",
                    implementationFamily: .klayout,
                    executableDigest: String(repeating: "1", count: 64),
                    ruleProgramDigest: String(repeating: "2", count: 64),
                    technologyDigest: String(repeating: "3", count: 64)
                ),
                reportPath: nil,
                manifestPath: nil
            ),
            oracleResult: DRCCorpusOracleResult(
                backendID: "custom-oracle",
                backendIdentity: DRCBackendIdentity(
                    backendID: "custom-oracle",
                    implementationFamily: .magic,
                    executableDigest: String(repeating: "4", count: 64),
                    ruleProgramDigest: String(repeating: "5", count: 64),
                    technologyDigest: String(repeating: "6", count: 64)
                ),
                passed: true,
                activeErrorRuleIDs: [],
                diagnosticSummary: summary,
                durationSeconds: 0.1,
                agreementPassed: true,
                failureReasons: [],
                reportPath: nil,
                manifestPath: nil
            )
        )

        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            caseResults: [result]
        )
        #expect(report.summary.nonIndependentOracleCaseCount == 0)
    }
}
