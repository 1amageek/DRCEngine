import Foundation
import CryptoKit

public struct DRCCorpusToolEvidenceVerifier: Sendable {
    public init() {}

    public func verify(
        evidenceURL: URL,
        reportURL: URL,
        requireSignature: Bool = false,
        trustedPublicKey: String? = nil
    ) throws -> [DRCCorpusEvidenceIntegrityIssue] {
        let evidenceData: Data
        do {
            evidenceData = try Data(contentsOf: evidenceURL)
        } catch {
            throw DRCError.invalidInput(
                "Could not read DRC corpus evidence '\(evidenceURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        let evidence: DRCCorpusToolEvidenceExport
        do {
            evidence = try JSONDecoder().decode(DRCCorpusToolEvidenceExport.self, from: evidenceData)
        } catch {
            throw DRCError.invalidInput(
                "Could not decode DRC corpus evidence '\(evidenceURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        return try verify(
            evidence,
            reportURL: reportURL,
            requireSignature: requireSignature,
            trustedPublicKey: trustedPublicKey
        )
    }

    public func verify(
        _ evidence: DRCCorpusToolEvidenceExport,
        reportURL: URL,
        requireSignature: Bool = false,
        trustedPublicKey: String? = nil
    ) throws -> [DRCCorpusEvidenceIntegrityIssue] {
        var issues: [DRCCorpusEvidenceIntegrityIssue] = []
        if evidence.schemaVersion != 1 {
            issues.append(.init(
                code: "unsupported-schema-version",
                message: "DRC corpus evidence schemaVersion must be 1."
            ))
        }
        if evidence.reportPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "empty-report-path", message: "DRC corpus evidence reportPath must not be empty."))
        }
        if evidence.toolEvidence.evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "empty-evidence-id", message: "DRC corpus evidenceID must not be empty."))
        }
        if evidence.toolEvidence.kind != "corpus" {
            issues.append(.init(code: "invalid-evidence-kind", message: "DRC corpus tool evidence kind must be 'corpus'."))
        }

        let reportData: Data
        do {
            reportData = try Data(contentsOf: reportURL)
        } catch {
            throw DRCError.invalidInput(
                "Could not read DRC corpus report '\(reportURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        let report: DRCCorpusReport
        do {
            report = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
        } catch {
            throw DRCError.invalidInput(
                "Could not decode DRC corpus report '\(reportURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        try report.validateEvidence()

        let reportSHA256 = sha256(reportData)
        guard let declaredReportSHA256 = evidence.reportSHA256 else {
            issues.append(.init(
                code: "report-sha256-missing",
                message: "DRC corpus evidence must include the report SHA-256 digest."
            ))
            return verifySignature(
                evidence,
                requireSignature: requireSignature,
                trustedPublicKey: trustedPublicKey,
                issues: issues
            )
        }
        if !isValidSHA256(declaredReportSHA256) {
            issues.append(.init(
                code: "invalid-report-sha256",
                message: "DRC corpus evidence reportSHA256 must be a lowercase 64-character digest."
            ))
        } else if declaredReportSHA256 != reportSHA256 {
            issues.append(.init(
                code: "report-sha256-mismatch",
                message: "DRC corpus evidence reportSHA256 does not match the supplied report."
            ))
        }
        if evidence.toolEvidence.artifact.path != evidence.reportPath {
            issues.append(.init(
                code: "report-path-mismatch",
                message: "DRC corpus evidence report reference does not match reportPath."
            ))
        }
        if URL(filePath: evidence.reportPath).standardizedFileURL.path(percentEncoded: false)
            != reportURL.standardizedFileURL.path(percentEncoded: false) {
            issues.append(.init(
                code: "report-url-mismatch",
                message: "DRC corpus evidence reportPath does not identify the supplied reportURL."
            ))
        }
        if evidence.toolEvidence.artifact.sha256 != declaredReportSHA256 {
            issues.append(.init(
                code: "artifact-sha256-mismatch",
                message: "DRC corpus evidence artifact digest does not match reportSHA256."
            ))
        }

        let expected = DRCCorpusToolEvidenceExport(
            reportPath: evidence.reportPath,
            reportSHA256: reportSHA256,
            report: report,
            evidenceID: evidence.toolEvidence.evidenceID,
            checkedAt: Date(timeIntervalSince1970: 0)
        )
        if evidence.status != expected.status {
            issues.append(.init(code: "status-mismatch", message: "DRC corpus evidence status is stale."))
        }
        if evidence.summary != expected.summary {
            issues.append(.init(code: "summary-mismatch", message: "DRC corpus evidence summary is stale."))
        }
        if evidence.toolEvidence.qualification != expected.toolEvidence.qualification {
            issues.append(.init(
                code: "qualification-mismatch",
                message: "DRC corpus evidence qualification is stale or tampered."
            ))
        }
        if evidence.toolEvidence.checkedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "checked-at-missing", message: "DRC corpus evidence checkedAt must not be empty."))
        } else if ISO8601DateFormatter().date(from: evidence.toolEvidence.checkedAt) == nil {
            issues.append(.init(code: "checked-at-invalid", message: "DRC corpus evidence checkedAt must be ISO-8601."))
        }

        return verifySignature(
            evidence,
            requireSignature: requireSignature,
            trustedPublicKey: trustedPublicKey,
            issues: issues
        )
    }

    private func verifySignature(
        _ evidence: DRCCorpusToolEvidenceExport,
        requireSignature: Bool,
        trustedPublicKey: String?,
        issues: [DRCCorpusEvidenceIntegrityIssue]
    ) -> [DRCCorpusEvidenceIntegrityIssue] {
        var issues = issues
        guard let signature = evidence.signature else {
            if requireSignature {
                issues.append(.init(code: "signature-missing", message: "Signed DRC corpus evidence is required."))
            }
            return issues
        }
        if requireSignature && trustedPublicKey == nil {
            issues.append(.init(
                code: "signature-trust-root-missing",
                message: "A trusted public key is required for signed corpus evidence."
            ))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload: Data
        do {
            payload = try encoder.encode(evidence.withSignature(nil))
        } catch {
            issues.append(.init(
                code: "signature-payload-encoding-failed",
                message: "The unsigned corpus evidence payload could not be encoded."
            ))
            return issues
        }
        if !DRCArtifactSignatureVerifier.verify(
            signature,
            data: payload,
            trustedPublicKey: trustedPublicKey
        ) {
            issues.append(.init(
                code: "signature-invalid",
                message: "DRC corpus evidence signature is invalid or untrusted."
            ))
        }
        return issues
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func isValidSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57)
                || (scalar.value >= 97 && scalar.value <= 102)
        }
    }
}
