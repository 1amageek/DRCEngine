import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    func passingAuditCorpusReport() -> DRCCorpusReport {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let oracleResult = DRCCorpusOracleResult(
            backendID: "native",
            passed: true,
            activeErrorRuleIDs: [],
            diagnosticSummary: summary,
            durationSeconds: 0.01,
            agreementPassed: true,
            readinessStatus: .ready,
            readinessDiagnostics: [],
            failureReasons: [],
            reportPath: "/tmp/oracle/drc-report.json",
            manifestPath: "/tmp/oracle/drc-artifact-manifest.json"
        )
        let first = DRCCorpusCaseResult(
            caseID: "width-clean",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: ["diagnostic.rule-id", "drc.width"],
            expectationMatched: true,
            durationSeconds: 0.01,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: "/tmp/width-clean/drc-report.json",
            manifestPath: "/tmp/width-clean/drc-artifact-manifest.json",
            oracleResult: oracleResult
        )
        let second = DRCCorpusCaseResult(
            caseID: "width-violation",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: ["diagnostic.rule-id", "drc.width"],
            expectationMatched: true,
            durationSeconds: 0.02,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: "/tmp/width-violation/drc-report.json",
            manifestPath: "/tmp/width-violation/drc-artifact-manifest.json",
            oracleResult: oracleResult
        )
        return DRCCorpusReport(
            passed: true,
            caseCount: 2,
            matchedCaseCount: 2,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.03,
            caseResults: [first, second]
        )
    }

    func nativeGDSAuditCorpusReport() -> DRCCorpusReport {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseResult = passingAuditCaseResult(
            caseID: "native-gds-standard-input",
            coverageTags: ["drc.input.gds", "drc.tech.layer-map", "layout.gds"],
            oracleBackendID: "native-gds",
            summary: summary
        )
        return DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.01,
            caseResults: [caseResult]
        )
    }
    func passingAuditCaseResult(
        caseID: String,
        coverageTags: [String],
        oracleBackendID: String,
        summary: DRCDiagnosticSummary
    ) -> DRCCorpusCaseResult {
        let oracleResult = DRCCorpusOracleResult(
            backendID: oracleBackendID,
            passed: true,
            activeErrorRuleIDs: [],
            diagnosticSummary: summary,
            durationSeconds: 0.01,
            agreementPassed: true,
            readinessStatus: .ready,
            readinessDiagnostics: [],
            failureReasons: [],
            reportPath: "/tmp/\(caseID)/oracle-drc-report.json",
            manifestPath: "/tmp/\(caseID)/oracle-drc-artifact-manifest.json"
        )
        return DRCCorpusCaseResult(
            caseID: caseID,
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: coverageTags,
            expectationMatched: true,
            durationSeconds: 0.01,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: "/tmp/\(caseID)/drc-report.json",
            manifestPath: "/tmp/\(caseID)/drc-artifact-manifest.json",
            oracleResult: oracleResult
        )
    }

    func failingDRCCorpusReport() -> DRCCorpusReport {
        DRCCorpusReport(
            passed: false,
            caseCount: 1,
            matchedCaseCount: 0,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.12,
            caseResults: [
                DRCCorpusCaseResult(
                    caseID: "case-spacing",
                    matched: false,
                    expectedPassed: true,
                    actualPassed: false,
                    expectedActiveErrorRuleIDs: ["met1.width"],
                    actualActiveErrorRuleIDs: ["met1.spacing"],
                    coverageTags: ["drc.width", "diagnostic.rule-id", "failure.expected"],
                    expectationMatched: false,
                    durationSeconds: 0.12,
                    expectedMaxDurationSeconds: 1,
                    durationBudgetPassed: true,
                    failureReasons: [
                        "rule-set-mismatch: expected met1.width observed met1.spacing",
                    ],
                    diagnosticSummary: DRCDiagnosticSummary(
                        infoCount: 0,
                        warningCount: 0,
                        errorCount: 1
                    ),
                    reportPath: "/tmp/case-spacing/drc-report.json",
                    manifestPath: "/tmp/case-spacing/drc-artifact-manifest.json",
                    oracleResult: DRCCorpusOracleResult(
                        backendID: "magic",
                        passed: false,
                        activeErrorRuleIDs: ["met1.width"],
                        diagnosticSummary: DRCDiagnosticSummary(
                            infoCount: 0,
                            warningCount: 0,
                            errorCount: 1
                        ),
                        durationSeconds: 0,
                        agreementPassed: false,
                        readinessStatus: .blocked,
                        readinessDiagnostics: ["Magic DRC oracle is not available for this case."],
                        failureReasons: [
                            "oracle-agreement: native observed met1.spacing but oracle observed met1.width",
                        ],
                        reportPath: "/tmp/case-spacing/oracle-drc-report.json",
                        manifestPath: "/tmp/case-spacing/oracle-drc-artifact-manifest.json"
                    )
                ),
            ]
        )
    }
}
