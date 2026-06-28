import Foundation
import CryptoKit
import Testing
import DRCCore
import DRCRuntime

@Suite("Default DRC engine")
struct DefaultDRCEngineTests {
    @Test func injectedBackendRunsAndPersistsReport() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0x00, 0x01, 0x02]).write(to: layoutURL)
        let request = DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            workingDirectory: directory,
            backendSelection: DRCBackendSelection(backendID: "stub")
        )

        let result = try await DefaultDRCEngine(backend: StubDRCBackend()).run(request)

        #expect(result.result.passed)
        #expect(result.reportURL?.lastPathComponent.hasPrefix("drc-report-") == true)
        #expect(result.reportURL?.pathExtension == "json")
        #expect(result.artifactManifestURL?.lastPathComponent.hasPrefix("drc-artifact-manifest-") == true)
        #expect(result.reportURL.map { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) } == true)
        let reportURL = try #require(result.reportURL)
        let data = try Data(contentsOf: reportURL)
        let decoded = try JSONDecoder().decode(DRCExecutionResult.self, from: data)
        #expect(decoded.result.provenance?.executablePath == "/bin/stub-drc")
        let manifestURL = try #require(result.artifactManifestURL)
        let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))
        let inputLayout = try artifact("input-layout", in: manifest.inputs)
        let report = try artifact("report", in: manifest.outputs)
        let expectedInputLayoutSHA256 = try sha256(layoutURL)
        let expectedReportSHA256 = try sha256(reportURL)
        #expect(inputLayout.sha256 == expectedInputLayoutSHA256)
        #expect(inputLayout.byteCount == 3)
        #expect(report.sha256 == expectedReportSHA256)
        #expect(report.byteCount == data.count)
    }

    @Test func rejectsMismatchedBackendSelection() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "magic")
        )
        var didThrowExpectedError = false

        do {
            _ = try await DefaultDRCEngine(backend: StubDRCBackend()).run(request)
        } catch let error as DRCError {
            didThrowExpectedError = error == .backendUnavailable("Unsupported DRC backend: magic")
        } catch {
            throw error
        }

        #expect(didThrowExpectedError)
    }

    @Test func corpusOracleReadinessDefaultsWhenDecodingLegacyArtifacts() throws {
        let successfulOracleJSON = """
        {
          "backendID": "native",
          "passed": true,
          "activeErrorRuleIDs": [],
          "diagnosticSummary": {
            "infoCount": 0,
            "warningCount": 0,
            "errorCount": 0,
            "waivedErrorCount": 0
          },
          "durationSeconds": 0.01,
          "agreementPassed": true,
          "failureReasons": [],
          "executionError": null,
          "reportPath": "/tmp/report.json",
          "manifestPath": "/tmp/manifest.json"
        }
        """
        let blockedOracleJSON = """
        {
          "backendID": "magic",
          "passed": false,
          "activeErrorRuleIDs": [],
          "diagnosticSummary": {
            "infoCount": 0,
            "warningCount": 0,
            "errorCount": 0,
            "waivedErrorCount": 0
          },
          "durationSeconds": 0.01,
          "agreementPassed": false,
          "failureReasons": ["oracle_execution_failed:missing tool"],
          "executionError": "missing tool",
          "reportPath": null,
          "manifestPath": null
        }
        """
        let summaryJSON = """
        {
          "expectationMatchedCaseCount": 1,
          "durationBudgetPassedCaseCount": 1,
          "primaryExecutionFailedCaseCount": 0,
          "oracleCaseCount": 1,
          "oracleAgreementPassedCaseCount": 0,
          "oracleExecutionFailedCaseCount": 1,
          "failureCategoryCounts": {"oracle_execution_failed": 1},
          "coverageTagCounts": {},
          "passRate": 0,
          "oracleAgreementRate": 0
        }
        """

        let successfulOracle = try JSONDecoder().decode(
            DRCCorpusOracleResult.self,
            from: Data(successfulOracleJSON.utf8)
        )
        let blockedOracle = try JSONDecoder().decode(
            DRCCorpusOracleResult.self,
            from: Data(blockedOracleJSON.utf8)
        )
        let summary = try JSONDecoder().decode(
            DRCCorpusSummary.self,
            from: Data(summaryJSON.utf8)
        )

        #expect(successfulOracle.readinessStatus == .ready)
        #expect(successfulOracle.readinessDiagnostics.isEmpty)
        #expect(successfulOracle.provenance == nil)
        #expect(blockedOracle.readinessStatus == .blocked)
        #expect(blockedOracle.readinessDiagnostics.isEmpty)
        #expect(blockedOracle.provenance == nil)
        #expect(summary.oracleReadinessBlockedCaseCount == 1)
    }

    @Test func nativeBackendIsAvailableByDefault() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        try """
        {
          "rectangles" : [
            { "id" : "m1", "layer" : "met1", "xMax" : 1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "unit-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let result = try await DefaultDRCEngine(backend: nil).run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(result.result.passed)
    }

    @Test func deprecatedBackendAliasesAreNormalized() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "pure-swift")
        )

        let result = try await DefaultDRCEngine(backend: AliasStubDRCBackend(backendID: "native")).run(request)

        #expect(result.result.backendID == "native")
    }

    @Test func waiverFileMarksMatchingDiagnosticsAndIsPersisted() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        let waiverURL = directory.appending(path: "drc-waivers.json")
        try Data([0x01, 0x02, 0x03]).write(to: layoutURL)
        try writeWaivers(
            DRCWaiverFile(waivers: [
                DRCWaiver(
                    id: "waive-met1-width-thin",
                    reason: "Known fixture violation",
                    ruleID: "met1.width",
                    kind: "minimumWidth",
                    layer: "met1",
                    relatedShapeIDs: ["thin"]
                ),
                DRCWaiver(
                    id: "unused-waiver",
                    reason: "Should be reported as stale",
                    ruleID: "met2.width"
                ),
            ]),
            to: waiverURL
        )

        let result = try await DefaultDRCEngine(backend: WaiverStubDRCBackend()).run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            waiverURL: waiverURL,
            workingDirectory: directory,
            backendSelection: DRCBackendSelection(backendID: "waiver-stub")
        ))

        #expect(result.result.passed)
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.waiverID == "waive-met1-width-thin")
        #expect(diagnostic.waiverReason == "Known fixture violation")
        let waiverReport = try #require(result.waiverReport)
        #expect(waiverReport.waivedDiagnosticCount == 1)
        #expect(waiverReport.unusedWaiverIDs == ["unused-waiver"])
        let manifestURL = try #require(result.artifactManifestURL)
        let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))
        #expect(manifest.passed)
        #expect(manifest.diagnosticSummary.errorCount == 0)
        #expect(manifest.diagnosticSummary.waivedErrorCount == 1)
        #expect(manifest.waiverReport == waiverReport)
        #expect(manifest.inputs.contains { $0.id == "input-waivers" && $0.kind == .waiver && $0.sha256 != nil })
    }

    @Test func corpusRunnerFailsWhenOracleBackendDisagrees() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x01]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "oracle-mismatch",
                layoutPath: layoutURL.lastPathComponent,
                topCell: "inv",
                backendID: "clean-stub",
                oracleBackendID: "violation-stub",
                expectedPassed: true
            ),
        ]), to: specURL)

        let engine = DefaultDRCEngine(backends: [
            CleanStubDRCBackend(),
            ViolationStubDRCBackend(),
        ])
        let report = try await DRCCorpusRunner(engine: engine).run(
            specURL: specURL,
            outputDirectory: outputDirectory
        )

        #expect(!report.passed)
        #expect(report.caseCount == 1)
        #expect(report.matchedCaseCount == 0)
        #expect(report.summary.primaryExecutionFailedCaseCount == 0)
        #expect(report.summary.oracleExecutionFailedCaseCount == 0)
        #expect(report.summary.failureCategoryCounts["oracle_agreement_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["passed_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["active_error_rule_ids_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["diagnostic_summary_mismatch"] == 1)
        let result = try #require(report.caseResults.first)
        #expect(result.expectationMatched)
        #expect(result.primaryProvenance?.backendID == "clean-stub")
        #expect(result.primaryProvenance?.inputArtifacts.contains { $0.id == "input-layout" && $0.kind == .layout } == true)
        #expect(result.primaryProvenance?.outputArtifacts.contains { $0.id == "report" && $0.kind == .report } == true)
        #expect(result.primaryProvenance?.outputArtifacts.contains { $0.id == "manifest" && $0.kind == .manifest } == true)
        #expect(result.oracleResult?.backendID == "violation-stub")
        #expect(result.oracleResult?.agreementPassed == false)
        #expect(result.oracleResult?.readinessStatus == .ready)
        #expect(result.oracleResult?.readinessDiagnostics.isEmpty == true)
        #expect(result.oracleResult?.provenance?.backendID == "violation-stub")
        #expect(result.oracleResult?.provenance?.inputArtifacts.contains { $0.id == "input-layout" && $0.kind == .layout } == true)
        #expect(result.oracleResult?.provenance?.outputArtifacts.contains { $0.id == "report" && $0.kind == .report } == true)
        #expect(result.oracleResult?.provenance?.outputArtifacts.contains { $0.id == "manifest" && $0.kind == .manifest } == true)
        #expect(result.oracleComparison?.primaryBackendID == "clean-stub")
        #expect(result.oracleComparison?.oracleBackendID == "violation-stub")
        #expect(result.oracleComparison?.passedMatched == false)
        #expect(result.oracleComparison?.activeErrorRuleIDsMatched == false)
        #expect(result.oracleComparison?.diagnosticSummaryMatched == false)
        #expect(result.oracleComparison?.primaryPassed == true)
        #expect(result.oracleComparison?.oraclePassed == false)
        #expect(result.oracleComparison?.primaryActiveErrorRuleIDs == [])
        #expect(result.oracleComparison?.oracleActiveErrorRuleIDs == ["oracle.width"])
        #expect(result.oracleComparison?.mismatchReasons == [
            "passed_mismatch",
            "active_error_rule_ids_mismatch",
            "diagnostic_summary_mismatch",
            "oracle_agreement_mismatch",
        ])
        #expect(result.failureReasons.contains("oracle_agreement_mismatch"))
        #expect(result.oracleResult?.failureReasons == [
            "passed_mismatch",
            "active_error_rule_ids_mismatch",
            "diagnostic_summary_mismatch",
            "oracle_agreement_mismatch",
        ])
    }

    @Test func corpusRunnerWritesCaseFailureWhenPrimaryBackendIsUnavailable() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x01]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "missing-primary",
                layoutPath: layoutURL.lastPathComponent,
                topCell: "inv",
                backendID: "missing-backend",
                expectedPassed: true
            ),
        ]), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [])).run(
            specURL: specURL,
            outputDirectory: outputDirectory
        )

        #expect(!report.passed)
        #expect(report.caseCount == 1)
        #expect(report.matchedCaseCount == 0)
        #expect(report.summary.primaryExecutionFailedCaseCount == 1)
        #expect(report.summary.failureCategoryCounts["primary_execution_failed"] == 1)
        let result = try #require(report.caseResults.first)
        #expect(result.executionError?.contains("Unsupported DRC backend: missing-backend") == true)
        #expect(result.failureReasons.contains {
            $0.hasPrefix("primary_execution_failed:")
        })
        #expect(result.reportPath == nil)
        #expect(result.manifestPath == nil)
        #expect(FileManager.default.fileExists(
            atPath: outputDirectory.appending(path: "drc-corpus-report.json").path(percentEncoded: false)
        ))
    }

    @Test func corpusRunnerReportsOracleBackendUnavailable() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x01]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "missing-oracle",
                layoutPath: layoutURL.lastPathComponent,
                topCell: "inv",
                backendID: "clean-stub",
                oracleBackendID: "missing-oracle",
                expectedPassed: true
            ),
        ]), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [
            CleanStubDRCBackend(),
        ])).run(
            specURL: specURL,
            outputDirectory: outputDirectory
        )

        #expect(!report.passed)
        #expect(report.summary.oracleCaseCount == 1)
        #expect(report.summary.oracleAgreementPassedCaseCount == 0)
        #expect(report.summary.oracleExecutionFailedCaseCount == 1)
        #expect(report.summary.oracleReadinessBlockedCaseCount == 1)
        #expect(report.summary.failureCategoryCounts["oracle_agreement_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["oracle_execution_failed"] == 1)
        #expect(report.summary.failureCategoryCounts["passed_mismatch"] == 1)
        let result = try #require(report.caseResults.first)
        #expect(result.expectationMatched)
        #expect(result.primaryProvenance?.backendID == "clean-stub")
        #expect(result.oracleResult?.backendID == "missing-oracle")
        #expect(result.oracleResult?.agreementPassed == false)
        #expect(result.oracleResult?.readinessStatus == .blocked)
        #expect(result.oracleResult?.readinessDiagnostics.contains {
            $0.contains("Unsupported DRC backend: missing-oracle")
        } == true)
        #expect(result.oracleResult?.executionError?.contains("Unsupported DRC backend: missing-oracle") == true)
        #expect(result.oracleResult?.provenance == nil)
        #expect(result.oracleComparison?.primaryBackendID == "clean-stub")
        #expect(result.oracleComparison?.oracleBackendID == "missing-oracle")
        #expect(result.oracleComparison?.passedMatched == false)
        #expect(result.oracleComparison?.activeErrorRuleIDsMatched == true)
        #expect(result.oracleComparison?.mismatchReasons.contains("passed_mismatch") == true)
        #expect(result.oracleComparison?.mismatchReasons.contains {
            $0.hasPrefix("oracle_execution_failed:")
        } == true)
        #expect(result.failureReasons.contains("oracle_agreement_mismatch"))
        #expect(result.failureReasons.contains("passed_mismatch"))
        #expect(result.failureReasons.contains {
            $0.hasPrefix("oracle_execution_failed:")
        })
    }

    @Test func corpusRunnerMarksIncompleteOracleResultAsBlocked() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x01]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "incomplete-oracle",
                layoutPath: layoutURL.lastPathComponent,
                topCell: "inv",
                backendID: "clean-stub",
                oracleBackendID: "incomplete-stub",
                expectedPassed: true
            ),
        ]), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [
            CleanStubDRCBackend(),
            IncompleteStubDRCBackend(),
        ])).run(
            specURL: specURL,
            outputDirectory: outputDirectory
        )

        #expect(!report.passed)
        #expect(report.summary.oracleCaseCount == 1)
        #expect(report.summary.oracleAgreementPassedCaseCount == 0)
        #expect(report.summary.oracleExecutionFailedCaseCount == 1)
        #expect(report.summary.oracleReadinessBlockedCaseCount == 1)
        #expect(report.summary.failureCategoryCounts["oracle_execution_failed"] == 1)
        #expect(report.summary.failureCategoryCounts["passed_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["active_error_rule_ids_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["diagnostic_summary_mismatch"] == 1)
        let result = try #require(report.caseResults.first)
        #expect(result.expectationMatched)
        #expect(result.primaryProvenance?.backendID == "clean-stub")
        #expect(result.oracleResult?.backendID == "incomplete-stub")
        #expect(result.oracleResult?.agreementPassed == false)
        #expect(result.oracleResult?.readinessStatus == .blocked)
        #expect(result.oracleResult?.readinessDiagnostics.first == "oracle_result_incomplete")
        #expect(result.oracleResult?.readinessDiagnostics.contains {
            $0.contains("DRIVER: cell not found or empty")
        } == true)
        #expect(result.oracleResult?.executionError == "oracle_result_incomplete")
        #expect(result.oracleResult?.provenance?.backendID == "incomplete-stub")
        #expect(result.oracleComparison?.passedMatched == false)
        #expect(result.oracleComparison?.activeErrorRuleIDsMatched == false)
        #expect(result.oracleComparison?.diagnosticSummaryMatched == false)
        #expect(result.oracleComparison?.mismatchReasons.contains {
            $0.hasPrefix("oracle_execution_failed:")
        } == true)
        #expect(result.failureReasons.contains("oracle_agreement_mismatch"))
        #expect(result.failureReasons.contains {
            $0.hasPrefix("oracle_execution_failed:")
        })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DefaultDRCEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func artifact(_ id: String, in records: [DRCArtifactRecord]) throws -> DRCArtifactRecord {
        try #require(records.first { $0.id == id })
    }

    private func sha256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func writeWaivers(_ waivers: DRCWaiverFile, to url: URL) throws {
        try writeJSON(waivers, to: url)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private struct StubDRCBackend: DRCBackend {
        let backendID = "stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "stub-drc",
                    success: true,
                    completed: true,
                    logPath: "/tmp/stub-drc.log",
                    provenance: DRCToolProvenance(
                        executablePath: "/bin/stub-drc",
                        pdkRoot: "/tmp/pdk",
                        rcFilePath: "/tmp/sky130A.magicrc",
                        driverScriptPath: "/tmp/drc.tcl",
                        timeoutSeconds: request.options.timeoutSeconds
                    )
                )
            )
        }
    }

    private struct AliasStubDRCBackend: DRCBackend {
        let backendID: String

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "alias-stub-drc",
                    success: true,
                    completed: true,
                    logPath: ""
                )
            )
        }
    }

    private struct WaiverStubDRCBackend: DRCBackend {
        let backendID = "waiver-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "waiver-stub-drc",
                    success: true,
                    completed: true,
                    logPath: "",
                    diagnostics: [
                        DRCDiagnostic(
                            severity: .error,
                            message: "Rectangle thin on met1 violates minimum width 0.5",
                            ruleID: "met1.width",
                            kind: "minimumWidth",
                            layer: "met1",
                            relatedShapeIDs: ["thin"],
                            rawLine: "MIN_WIDTH layer=met1 id=thin"
                        ),
                    ]
                )
            )
        }
    }

    private struct CleanStubDRCBackend: DRCBackend {
        let backendID = "clean-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "clean-stub-drc",
                    success: true,
                    completed: true,
                    logPath: ""
                )
            )
        }
    }

    private struct ViolationStubDRCBackend: DRCBackend {
        let backendID = "violation-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "violation-stub-drc",
                    success: true,
                    completed: true,
                    logPath: "",
                    diagnostics: [
                        DRCDiagnostic(
                            severity: .error,
                            message: "Oracle reports width mismatch",
                            ruleID: "oracle.width",
                            rawLine: "ORACLE_WIDTH"
                        ),
                    ]
                )
            )
        }
    }

    private struct IncompleteStubDRCBackend: DRCBackend {
        let backendID = "incomplete-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "incomplete-stub-drc",
                    success: false,
                    completed: false,
                    logPath: "",
                    diagnostics: [
                        DRCDiagnostic(
                            severity: .error,
                            message: "cell not found or empty: inv",
                            ruleID: "DRIVER",
                            rawLine: "ERROR rule=DRIVER message=\"cell not found or empty: inv\""
                        ),
                    ]
                )
            )
        }
    }
}
