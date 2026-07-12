import Foundation
import CryptoKit

public struct DRCArtifactManifestVerifier: Sendable {
    public init() {}

    public func verify(
        manifestURL: URL,
        requireSignature: Bool = false,
        trustedPublicKey: String? = nil
    ) throws -> [DRCArtifactIntegrityIssue] {
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw DRCError.invalidInput(
                "Could not read DRC artifact manifest '\(manifestURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        let manifest: DRCArtifactManifest
        do {
            manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: data)
        } catch {
            throw DRCError.invalidInput(
                "Could not decode DRC artifact manifest '\(manifestURL.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        return verify(
            manifest,
            relativeTo: manifestURL.deletingLastPathComponent(),
            requireSignature: requireSignature,
            trustedPublicKey: trustedPublicKey
        )
    }

    public func verify(
        _ manifest: DRCArtifactManifest,
        relativeTo baseDirectory: URL,
        requireSignature: Bool = false,
        trustedPublicKey: String? = nil
    ) -> [DRCArtifactIntegrityIssue] {
        var issues: [DRCArtifactIntegrityIssue] = []
        guard manifest.schemaVersion == 1 else {
            issues.append(DRCArtifactIntegrityIssue(
                code: "unsupported-schema-version",
                message: "DRC artifact manifest schemaVersion must be 1."
            ))
            return issues
        }
        if let runID = manifest.runID, runID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(DRCArtifactIntegrityIssue(
                code: "empty-run-id",
                message: "DRC artifact manifest runID must not be empty when present."
            ))
        }
        if let requestSHA256 = manifest.requestSHA256, !isValidSHA256(requestSHA256) {
            issues.append(DRCArtifactIntegrityIssue(
                code: "invalid-request-sha256",
                message: "DRC artifact requestSHA256 must be a lowercase 64-character hexadecimal digest."
            ))
        }
        if let requestEnvironmentSHA256 = manifest.requestEnvironmentSHA256,
           !isValidSHA256(requestEnvironmentSHA256) {
            issues.append(DRCArtifactIntegrityIssue(
                code: "invalid-request-environment-sha256",
                message: "DRC artifact requestEnvironmentSHA256 must be a lowercase 64-character hexadecimal digest."
            ))
        }
        if let artifactRootSHA256 = manifest.artifactRootSHA256,
           !isValidSHA256(artifactRootSHA256) {
            issues.append(DRCArtifactIntegrityIssue(
                code: "invalid-artifact-root-sha256",
                message: "DRC artifact artifactRootSHA256 must be a lowercase 64-character hexadecimal digest."
            ))
        }
        if let verdict = manifest.verdict,
           verdict == .passed && !manifest.passed {
            issues.append(DRCArtifactIntegrityIssue(
                code: "verdict-passed-flag-mismatch",
                message: "A passed DRC verdict requires the manifest passed flag to be true."
            ))
        } else if let verdict = manifest.verdict, verdict != .passed, manifest.passed {
            issues.append(DRCArtifactIntegrityIssue(
                code: "verdict-nonpassed-flag-mismatch",
                message: "A non-passed DRC verdict requires the manifest passed flag to be false."
            ))
        }
        verifySignature(
            manifest,
            requireSignature: requireSignature,
            trustedPublicKey: trustedPublicKey,
            issues: &issues
        )
        if requireSignature {
            verifyRequiredProvenance(manifest, issues: &issues)
        }
        var recordIDs: Set<String> = []
        for record in manifest.inputs + manifest.outputs {
            if record.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "empty-record-id",
                    path: record.path,
                    message: "DRC artifact record ID must not be empty."
                ))
            } else if !recordIDs.insert(record.id).inserted {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "duplicate-record-id",
                    recordID: record.id,
                    path: record.path,
                    message: "DRC artifact record IDs must be unique."
                ))
            }
            if record.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "empty-record-path",
                    recordID: record.id,
                    message: "DRC artifact record path must not be empty."
                ))
                continue
            }
            if let byteCount = record.byteCount, byteCount < 0 {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "invalid-byte-count",
                    recordID: record.id,
                    path: record.path,
                    message: "DRC artifact byteCount must be non-negative."
                ))
            }

            let isManifestRecord = record.kind == .manifest
            if isManifestRecord {
                guard record.id == "manifest" else {
                    issues.append(DRCArtifactIntegrityIssue(
                        code: "invalid-manifest-record",
                        recordID: record.id,
                        path: record.path,
                        message: "The manifest record must use the ID 'manifest'."
                    ))
                    continue
                }
                if record.byteCount != nil || record.sha256 != nil {
                    issues.append(DRCArtifactIntegrityIssue(
                        code: "manifest-record-must-be-unhashed",
                        recordID: record.id,
                        path: record.path,
                        message: "The manifest record must omit byteCount and sha256 to avoid a self-reference cycle."
                    ))
                }
            } else {
                if record.byteCount == nil || record.sha256 == nil {
                    issues.append(DRCArtifactIntegrityIssue(
                        code: "missing-integrity-fields",
                        recordID: record.id,
                        path: record.path,
                        message: "Non-manifest artifact records must include byteCount and sha256."
                    ))
                }
                if let sha256 = record.sha256,
                   !isValidSHA256(sha256) {
                    issues.append(DRCArtifactIntegrityIssue(
                        code: "invalid-sha256",
                        recordID: record.id,
                        path: record.path,
                        message: "DRC artifact sha256 must be a lowercase 64-character hexadecimal digest."
                    ))
                }
            }

            guard let artifactURL = containedURL(
                for: record.path,
                baseDirectory: baseDirectory
            ) else {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "path-outside-base-directory",
                    recordID: record.id,
                    path: record.path,
                    message: "DRC artifact path escapes the manifest base directory."
                ))
                continue
            }
            let data: Data
            do {
                data = try Data(contentsOf: artifactURL)
            } catch {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "artifact-read-failed",
                    recordID: record.id,
                    path: record.path,
                    message: "DRC artifact file could not be read."
                ))
                continue
            }
            if let byteCount = record.byteCount, byteCount != data.count {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "byte-count-mismatch",
                    recordID: record.id,
                    path: record.path,
                    message: "DRC artifact byteCount does not match the file."
                ))
            }
            if let expectedSHA256 = record.sha256 {
                let actualSHA256 = SHA256.hash(data: data)
                    .map { String(format: "%02x", $0) }
                    .joined()
                if expectedSHA256 != actualSHA256 {
                    issues.append(DRCArtifactIntegrityIssue(
                        code: "sha256-mismatch",
                        recordID: record.id,
                        path: record.path,
                        message: "DRC artifact sha256 does not match the file."
                    ))
                }
            }
        }
        verifyDerivedManifestCommitments(
            manifest,
            baseDirectory: baseDirectory,
            issues: &issues
        )
        return issues
    }

    private func verifyRequiredProvenance(
        _ manifest: DRCArtifactManifest,
        issues: inout [DRCArtifactIntegrityIssue]
    ) {
        if manifest.runID == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signed-run-id-missing",
                message: "Signed DRC artifact manifests must commit to a runID."
            ))
        }
        if manifest.requestSHA256 == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signed-request-digest-missing",
                message: "Signed DRC artifact manifests must commit to the canonical request digest."
            ))
        }
        if manifest.requestEnvironmentSHA256 == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signed-environment-digest-missing",
                message: "Signed DRC artifact manifests must commit to the request environment digest."
            ))
        }
        if manifest.artifactRootSHA256 == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signed-artifact-root-missing",
                message: "Signed DRC artifact manifests must commit to the artifact record root."
            ))
        }
        if manifest.verdict == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signed-verdict-missing",
                message: "Signed DRC artifact manifests must include a typed verdict."
            ))
        }
    }

    private func verifySignature(
        _ manifest: DRCArtifactManifest,
        requireSignature: Bool,
        trustedPublicKey: String?,
        issues: inout [DRCArtifactIntegrityIssue]
    ) {
        guard let signature = manifest.signature else {
            if requireSignature {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "signature-missing",
                    message: "A signed DRC artifact manifest is required."
                ))
            }
            return
        }
        guard !signature.algorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !signature.publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !signature.signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signature-fields-invalid",
                message: "DRC artifact signature fields must not be empty."
            ))
            return
        }
        if requireSignature && trustedPublicKey == nil {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signature-trust-root-missing",
                message: "A trusted artifact public key is required for signed verification."
            ))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let unsignedData: Data
        do {
            unsignedData = try encoder.encode(manifest.withSignature(nil))
        } catch {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signature-payload-encoding-failed",
                message: "The unsigned manifest payload could not be encoded for signature verification."
            ))
            return
        }
        guard DRCArtifactSignatureVerifier.verify(
            signature,
            data: unsignedData,
            trustedPublicKey: trustedPublicKey
        ) else {
            issues.append(DRCArtifactIntegrityIssue(
                code: "signature-invalid",
                message: "DRC artifact manifest signature is invalid or untrusted."
            ))
            return
        }
    }

    private func verifyDerivedManifestCommitments(
        _ manifest: DRCArtifactManifest,
        baseDirectory: URL,
        issues: inout [DRCArtifactIntegrityIssue]
    ) {
        if let expectedRootDigest = manifest.artifactRootSHA256 {
            let actualRootDigest = digestArtifactRecords(inputs: manifest.inputs, outputs: manifest.outputs)
            if expectedRootDigest != actualRootDigest {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "artifact-root-sha256-mismatch",
                    message: "DRC artifactRootSHA256 does not match the manifest records."
                ))
            }
        }

        guard manifest.requestSHA256 != nil || manifest.requestEnvironmentSHA256 != nil else {
            return
        }
        guard let reportRecord = (manifest.inputs + manifest.outputs).first(where: { $0.kind == .report }),
              let reportURL = containedURL(for: reportRecord.path, baseDirectory: baseDirectory) else {
            issues.append(DRCArtifactIntegrityIssue(
                code: "request-digest-report-missing",
                recordID: "report",
                message: "A report artifact is required to verify request provenance."
            ))
            return
        }
        let reportData: Data
        do {
            reportData = try Data(contentsOf: reportURL)
        } catch {
            issues.append(DRCArtifactIntegrityIssue(
                code: "request-digest-report-unreadable",
                recordID: reportRecord.id,
                path: reportRecord.path,
                message: "The report artifact could not be read for request provenance verification."
            ))
            return
        }
        let executionResult: DRCExecutionResult
        do {
            executionResult = try JSONDecoder().decode(DRCExecutionResult.self, from: reportData)
        } catch {
            issues.append(DRCArtifactIntegrityIssue(
                code: "request-digest-report-invalid",
                recordID: reportRecord.id,
                path: reportRecord.path,
                message: "The report artifact is not a valid DRCExecutionResult."
            ))
            return
        }
        if let expectedVerdict = manifest.verdict,
           expectedVerdict != executionResult.result.verdict {
            issues.append(DRCArtifactIntegrityIssue(
                code: "verdict-mismatch",
                recordID: reportRecord.id,
                path: reportRecord.path,
                message: "The manifest verdict does not match the persisted DRC result."
            ))
        }
        if let expectedRunID = manifest.runID,
           executionResult.artifactRunID != expectedRunID {
            issues.append(DRCArtifactIntegrityIssue(
                code: "run-id-mismatch",
                recordID: reportRecord.id,
                path: reportRecord.path,
                message: "The manifest runID does not match the persisted DRC result."
            ))
        }
        if let expectedRequestSHA256 = manifest.requestSHA256 {
            let actualRequestSHA256 = digest(executionResult.request)
            if expectedRequestSHA256 != actualRequestSHA256 {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "request-sha256-mismatch",
                    recordID: reportRecord.id,
                    path: reportRecord.path,
                    message: "DRC artifact requestSHA256 does not match the persisted request."
                ))
            }
        }
        if let expectedEnvironmentSHA256 = manifest.requestEnvironmentSHA256 {
            let actualEnvironmentSHA256 = digestEnvironment(executionResult.request.options.additionalEnvironment)
            if expectedEnvironmentSHA256 != actualEnvironmentSHA256 {
                issues.append(DRCArtifactIntegrityIssue(
                    code: "request-environment-sha256-mismatch",
                    recordID: reportRecord.id,
                    path: reportRecord.path,
                    message: "DRC artifact requestEnvironmentSHA256 does not match the persisted request."
                ))
            }
        }
    }

    private func digest<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            return ""
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func digestEnvironment(_ environment: [String: String]) -> String {
        let canonical = environment.keys.sorted().map { key in
            key + "=" + (environment[key] ?? "")
        }.joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func digestArtifactRecords(inputs: [DRCArtifactRecord], outputs: [DRCArtifactRecord]) -> String {
        let canonical = (inputs + outputs)
            .filter { $0.kind != .manifest }
            .sorted { $0.id < $1.id }
            .map { record in
                [record.id, record.kind.rawValue, record.path, String(record.byteCount ?? -1), record.sha256 ?? ""].joined(separator: "|")
            }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func isValidSHA256(_ value: String) -> Bool {
        value.count == 64
            && value.unicodeScalars.allSatisfy { scalar in
                (scalar.value >= 48 && scalar.value <= 57)
                    || (scalar.value >= 97 && scalar.value <= 102)
            }
    }

    private func containedURL(for path: String, baseDirectory: URL) -> URL? {
        guard !path.hasPrefix("/") else { return nil }
        let base = baseDirectory.standardizedFileURL
        let rawResolvedBasePath = base.resolvingSymlinksInPath().path(percentEncoded: false)
        let resolvedBasePath = rawResolvedBasePath.count > 1 && rawResolvedBasePath.hasSuffix("/")
            ? String(rawResolvedBasePath.dropLast())
            : rawResolvedBasePath
        let candidate = base.appending(path: path).standardizedFileURL
        let candidatePath = candidate.path(percentEncoded: false)
        let rawBasePath = base.path(percentEncoded: false)
        let basePath = rawBasePath.count > 1 && rawBasePath.hasSuffix("/")
            ? String(rawBasePath.dropLast())
            : rawBasePath
        guard candidatePath == basePath || candidatePath.hasPrefix(basePath + "/") else {
            return nil
        }
        let resolvedCandidate = candidate.resolvingSymlinksInPath().path(percentEncoded: false)
        guard resolvedCandidate == resolvedBasePath || resolvedCandidate.hasPrefix(resolvedBasePath + "/") else {
            return nil
        }
        return candidate
    }
}
