import Foundation
import CryptoKit
import Testing
import DRCCore

@Suite("DRC corpus observation verifier")
struct DRCCorpusObservationVerifierTests {
    @Test func verifiesSignedEvidenceAgainstCurrentReport() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let reportURL = directory.appending(path: "drc-corpus-report.json")
        let evidenceURL = directory.appending(path: "drc-observation-export.json")
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            caseResults: [
                DRCCorpusCaseResult(
                    caseID: "clean",
                    matched: true,
                    expectedPassed: true,
                    actualPassed: true,
                    expectedActiveErrorRuleIDs: [],
                    actualActiveErrorRuleIDs: [],
                    expectationMatched: true,
                    durationSeconds: 0.01,
                    expectedMaxDurationSeconds: nil,
                    durationBudgetPassed: true,
                    failureReasons: [],
                    diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0),
                    reportPath: nil,
                    manifestPath: nil
                ),
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let reportData = try encoder.encode(report)
        try reportData.write(to: reportURL, options: [.atomic])
        let reportSHA256 = sha256(reportData)
        let signer = DRCEd25519ArtifactSigner()
        let evidence = try DRCCorpusObservationExport(
            reportPath: reportURL.lastPathComponent,
            reportSHA256: reportSHA256,
            reportByteCount: UInt64(reportData.count),
            report: report,
            recordID: "signed-corpus",
            observedAt: Date(timeIntervalSince1970: 1_783_000_000)
        )
        try encoder.encode(evidence.signed(using: signer)).write(to: evidenceURL, options: [.atomic])

        let verifier = DRCCorpusObservationVerifier()
        #expect(try verifier.verify(
            evidenceURL: evidenceURL,
            reportURL: reportURL,
            requireSignature: true,
            trustedPublicKey: signer.publicKey
        ).isEmpty)
        #expect(try !verifier.verify(
            evidenceURL: evidenceURL,
            reportURL: reportURL,
            requireSignature: true,
            trustedPublicKey: DRCEd25519ArtifactSigner().publicKey
        ).isEmpty)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCCorpusObservationVerifierTests-\(UUID().uuidString)")
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
}
