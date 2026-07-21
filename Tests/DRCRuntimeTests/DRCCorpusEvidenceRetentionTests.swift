import Foundation
import CryptoKit
import Testing
import DRCCore
import DRCRuntime

@Suite("DRC corpus evidence retention")
struct DRCCorpusEvidenceRetentionTests {
    @Test func corpusRunnerRetainsPrimaryAndOracleArtifactsForDisagreementEvidence() async throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let layoutURL = directory.appending(path: "layout.gds")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x0d, 0x0a, 0x63]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(
            defaultMaxDurationSeconds: 1,
            cases: [
                DRCCorpusCase(
                    caseID: "oracle-disagreement-artifacts",
                    layoutPath: layoutURL.lastPathComponent,
                    topCell: "inv",
                    backendID: "primary-pass-stub",
                    oracleBackendID: "oracle-width-stub",
                    expectedPassed: true,
                    coverageTags: ["diagnostic.rule-id", "drc.width", "external.oracle"],
                    maxDurationSeconds: 1
                ),
            ]
        ), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [
            PrimaryPassStubDRCBackend(),
            OracleWidthStubDRCBackend(),
        ])).run(specURL: specURL, outputDirectory: outputDirectory)

        #expect(!report.passed)
        #expect(report.caseCount == 1)
        #expect(report.matchedCaseCount == 0)
        #expect(report.summary.oracleCaseCount == 1)
        #expect(report.summary.oracleAgreementPassedCaseCount == 0)
        #expect(report.summary.oracleExecutionFailedCaseCount == 0)
        #expect(report.summary.oracleReadinessBlockedCaseCount == 0)
        #expect(report.summary.failureCategoryCounts["oracle_agreement_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["passed_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["active_error_rule_ids_mismatch"] == 1)
        let result = try #require(report.caseResults.first)
        #expect(result.expectationMatched)
        #expect(result.oracleComparison?.primaryBackendID == "primary-pass-stub")
        #expect(result.oracleComparison?.oracleBackendID == "oracle-width-stub")
        #expect(result.oracleComparison?.mismatchReasons == [
            "passed_mismatch",
            "active_error_rule_ids_mismatch",
            "diagnostic_summary_mismatch",
            "oracle_agreement_mismatch",
        ])

        let primaryReportPath = try #require(result.reportPath)
        let primaryManifestPath = try #require(result.manifestPath)
        let oracleReportPath = try #require(result.oracleResult?.reportPath)
        let oracleManifestPath = try #require(result.oracleResult?.manifestPath)
        #expect(fileExists(primaryReportPath))
        #expect(fileExists(primaryManifestPath))
        #expect(fileExists(oracleReportPath))
        #expect(fileExists(oracleManifestPath))

        let primaryReport = try decode(DRCExecutionResult.self, fromPath: primaryReportPath)
        let oracleReport = try decode(DRCExecutionResult.self, fromPath: oracleReportPath)
        #expect(primaryReport.result.backendID == "primary-pass-stub")
        #expect(primaryReport.result.passed)
        #expect(primaryReport.result.diagnostics.isEmpty)
        #expect(oracleReport.result.backendID == "oracle-width-stub")
        #expect(!oracleReport.result.passed)
        #expect(oracleReport.result.diagnostics.map(\.ruleID) == ["oracle.width"])

        let primaryManifest = try decode(DRCArtifactManifest.self, fromPath: primaryManifestPath)
        let oracleManifest = try decode(DRCArtifactManifest.self, fromPath: oracleManifestPath)
        #expect(primaryManifest.backendID == "primary-pass-stub")
        #expect(primaryManifest.passed)
        #expect(primaryManifest.diagnosticSummary.errorCount == 0)
        #expect(oracleManifest.backendID == "oracle-width-stub")
        #expect(!oracleManifest.passed)
        #expect(oracleManifest.diagnosticSummary.errorCount == 1)
        let expectedLayoutSHA256 = try sha256(layoutURL)
        #expect(try artifact("input-layout", in: primaryManifest.inputs).sha256 == expectedLayoutSHA256)
        #expect(try artifact("input-layout", in: oracleManifest.inputs).sha256 == expectedLayoutSHA256)
        #expect(try artifact("report", in: primaryManifest.outputs).sha256 == sha256(URL(filePath: primaryReportPath)))
        #expect(try artifact("report", in: oracleManifest.outputs).sha256 == sha256(URL(filePath: oracleReportPath)))
        #expect(primaryManifest.outputs.contains { $0.id == "manifest" && $0.kind == .manifest })
        #expect(oracleManifest.outputs.contains { $0.id == "manifest" && $0.kind == .manifest })

        let persistedReportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let persistedReport = try decode(DRCCorpusReport.self, from: persistedReportURL)
        #expect(persistedReport.caseResults.first?.reportPath == primaryReportPath)
        #expect(persistedReport.caseResults.first?.oracleResult?.reportPath == oracleReportPath)
        #expect(persistedReport.caseResults.first?.primaryProvenance?.outputArtifacts.contains {
            $0.id == "report" && $0.kind == .report
        } == true)
        #expect(persistedReport.caseResults.first?.oracleResult?.provenance?.outputArtifacts.contains {
            $0.id == "report" && $0.kind == .report
        } == true)
    }

    @Test func evidencePacketGroundsBlockedOracleReadinessToRetainedPrimaryArtifacts() async throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let layoutURL = directory.appending(path: "layout.gds")
        let specURL = directory.appending(path: "drc-corpus.json")
        let outputDirectory = directory.appending(path: "corpus-output")
        try Data([0x10, 0x20, 0x30]).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(
            defaultMaxDurationSeconds: 1,
            cases: [
                DRCCorpusCase(
                    caseID: "missing-oracle-readiness",
                    layoutPath: layoutURL.lastPathComponent,
                    topCell: "inv",
                    backendID: "primary-pass-stub",
                    oracleBackendID: "missing-oracle",
                    expectedPassed: true,
                    coverageTags: ["diagnostic.rule-id", "drc.width", "external.oracle"],
                    maxDurationSeconds: 1
                ),
            ]
        ), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [
            PrimaryPassStubDRCBackend(),
        ])).run(specURL: specURL, outputDirectory: outputDirectory)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")

        let packet = DRCCorpusEvidencePacketBuilder().build(
            report: report,
            reportPath: reportURL.path(percentEncoded: false),
            reportSHA256: try sha256(reportURL),
            packetID: "missing-oracle-readiness-packet"
        )

        #expect(report.summary.oracleReadinessBlockedCaseCount == 1)
        #expect(packet.packetID == "missing-oracle-readiness-packet")
        #expect(packet.readiness.contains {
            $0.component == "drc-oracle-comparison"
                && $0.status == .blocked
                && $0.suggestedActions.contains("inspect_oracle_backend_readiness")
        })
        #expect(packet.confidence.level == .medium)
        #expect(packet.coverageTags == ["diagnostic.rule-id", "drc.width", "external.oracle"])

        let result = try #require(report.caseResults.first)
        #expect(result.oracleResult?.backendID == "missing-oracle")
        #expect(result.oracleResult?.readinessStatus == .blocked)
        #expect(result.oracleResult?.provenance == nil)
        let retainedArtifactIDs = Set([
            "\(result.caseID):manifestPath",
            "\(result.caseID):reportPath",
        ])
        #expect(Set(packet.artifacts.map(\.artifactID)) == retainedArtifactIDs)
        #expect(packet.artifacts.allSatisfy { fileExists($0.path) })

        let readinessDiagnostic = try #require(packet.diagnostics.first {
            $0.diagnosticID == "\(result.caseID):oracle-readiness"
        })
        #expect(readinessDiagnostic.category == "oracle_readiness")
        #expect(Set(readinessDiagnostic.artifactIDs) == retainedArtifactIDs)
        #expect(readinessDiagnostic.suggestedActions == [
            "inspect_oracle_backend_readiness",
            "inspect_oracle_backend_logs",
        ])
        let executionDiagnostic = try #require(packet.diagnostics.first {
            $0.diagnosticID == "\(result.caseID):oracle-execution"
        })
        #expect(executionDiagnostic.category == "oracle_execution")
        #expect(Set(executionDiagnostic.artifactIDs) == retainedArtifactIDs)
        #expect(executionDiagnostic.message.contains("Unsupported DRC backend: missing-oracle"))
        let oracleHint = try #require(packet.decisionHints.first { $0.hintID == "drc:oracle_readiness" })
        #expect(oracleHint.priority == .high)
        #expect(oracleHint.diagnosticIDs.contains("\(result.caseID):oracle-readiness"))
        let normalizedView = try #require(packet.normalizedViews.first { $0.viewID == "drc-corpus-summary" })
        #expect(normalizedView.summaryCounts["oracleReadinessBlockedCaseCount"] == 1)
        #expect(normalizedView.summaryCounts["oracleExecutionFailedCaseCount"] == 1)
        #expect(Set(normalizedView.sourceArtifactIDs).isSuperset(of: retainedArtifactIDs))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCCorpusEvidenceRetentionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeTemporaryDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove temporary directory: \(error.localizedDescription)")
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func decode<T: Decodable>(_ type: T.Type, fromPath path: String) throws -> T {
        try decode(type, from: URL(filePath: path))
    }

    private func artifact(_ id: String, in records: [DRCArtifactRecord]) throws -> DRCArtifactRecord {
        try #require(records.first { $0.id == id })
    }

    private func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    private func sha256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct PrimaryPassStubDRCBackend: DRCBackend {
        let backendID = "primary-pass-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            try DRCExecutionResult.inProcess(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "primary-pass-stub-drc",
                    success: true,
                    completed: true,
                    logPath: "",
                    diagnostics: []
                )
            )
        }
    }

    private struct OracleWidthStubDRCBackend: DRCBackend {
        let backendID = "oracle-width-stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            try DRCExecutionResult.inProcess(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "oracle-width-stub-drc",
                    success: true,
                    completed: true,
                    logPath: "",
                    diagnostics: [
                        DRCDiagnostic(
                            severity: .error,
                            message: "Oracle retained width violation for review",
                            ruleID: "oracle.width",
                            kind: "minimumWidth",
                            layer: "met1",
                            measured: 0.12,
                            required: 0.14,
                            unit: "um",
                            rawLine: "ORACLE_WIDTH layer=met1 measured=0.12 required=0.14"
                        ),
                    ]
                )
            )
        }
    }
}
