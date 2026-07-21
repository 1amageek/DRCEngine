import Foundation
import CryptoKit
import Testing
import CircuiteFoundation
import DRCCore

@Suite("DRC artifact manifest verifier")
struct DRCArtifactManifestVerifierTests {
    @Test func verifiesStoredArtifactHashesAndManifestShape() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let layoutURL = directory.appending(path: "layout.gds")
        let reportURL = directory.appending(path: "report.json")
        let manifestURL = directory.appending(path: "manifest.json")
        try Data("layout".utf8).write(to: layoutURL)
        try Data("report".utf8).write(to: reportURL)
        let layoutRecord = try record(id: "input-layout", kind: .layout, url: layoutURL, base: directory)
        let reportRecord = try record(id: "report", kind: .report, url: reportURL, base: directory)

        let manifest = DRCArtifactManifest(
            generatedAt: "2026-07-12T00:00:00Z",
            backendID: "native",
            producer: try ProducerIdentity(
                kind: .engine,
                identifier: "layout-verify",
                version: DRCExecutionProvenance.nativeImplementationVersion,
                build: DRCExecutionProvenance.currentExecutableDigest()
            ),
            toolName: "NativeDRC",
            passed: true,
            completed: true,
            inputs: [layoutRecord],
            outputs: [
                reportRecord,
                DRCArtifactRecord(id: "manifest", kind: .manifest, path: "manifest.json", byteCount: nil, sha256: nil),
            ],
            diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        )
        try writeJSON(manifest, to: manifestURL)

        let issues = try DRCArtifactManifestVerifier().verify(manifestURL: manifestURL)

        #expect(issues.isEmpty)
    }

    @Test func detectsArtifactHashTamperingAndPathEscape() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let reportURL = directory.appending(path: "report.json")
        try Data("tampered".utf8).write(to: reportURL)
        let manifest = DRCArtifactManifest(
            generatedAt: "2026-07-12T00:00:00Z",
            backendID: "native",
            producer: try ProducerIdentity(
                kind: .engine,
                identifier: "layout-verify",
                version: DRCExecutionProvenance.nativeImplementationVersion,
                build: DRCExecutionProvenance.currentExecutableDigest()
            ),
            toolName: "NativeDRC",
            passed: true,
            completed: true,
            inputs: [],
            outputs: [
                DRCArtifactRecord(
                    id: "report",
                    kind: .report,
                    path: "report.json",
                    byteCount: 1,
                    sha256: String(repeating: "0", count: 64)
                ),
                DRCArtifactRecord(
                    id: "outside",
                    kind: .log,
                    path: "../outside.log",
                    byteCount: 1,
                    sha256: String(repeating: "0", count: 64)
                ),
                DRCArtifactRecord(
                    id: "manifest",
                    kind: .manifest,
                    path: "manifest.json",
                    byteCount: nil,
                    sha256: nil
                ),
            ],
            diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        )

        let issues = DRCArtifactManifestVerifier().verify(manifest, relativeTo: directory)

        #expect(issues.contains { $0.code == "byte-count-mismatch" })
        #expect(issues.contains { $0.code == "sha256-mismatch" })
        #expect(issues.contains { $0.code == "path-outside-base-directory" })
    }

    @Test func rejectsInputWithoutExactSourceReference() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let layoutURL = directory.appending(path: "layout.gds")
        try Data("layout".utf8).write(to: layoutURL)
        let data = try Data(contentsOf: layoutURL)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let manifest = DRCArtifactManifest(
            generatedAt: "2026-07-12T00:00:00Z",
            backendID: "native",
            producer: try ProducerIdentity(
                kind: .engine,
                identifier: "layout-verify",
                version: DRCExecutionProvenance.nativeImplementationVersion,
                build: DRCExecutionProvenance.currentExecutableDigest()
            ),
            toolName: "NativeDRC",
            passed: true,
            completed: true,
            inputs: [
                DRCArtifactRecord(
                    id: "input-layout",
                    kind: .layout,
                    path: "layout.gds",
                    byteCount: data.count,
                    sha256: digest
                ),
            ],
            outputs: [],
            diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        )

        let issues = DRCArtifactManifestVerifier().verify(manifest, relativeTo: directory)

        #expect(issues.contains { $0.code == "input-source-reference-missing" })
    }

    private func record(
        id: String,
        kind: DRCArtifactRecord.Kind,
        url: URL,
        base: URL
    ) throws -> DRCArtifactRecord {
        let data = try Data(contentsOf: url)
        let sha256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let sourceReference: ArtifactReference?
        if kind == .layout {
            sourceReference = ArtifactReference(
                locator: ArtifactLocator(
                    location: try ArtifactLocation(fileURL: url),
                    role: .input,
                    kind: .layout,
                    format: .gdsii
                ),
                digest: try ContentDigest(algorithm: .sha256, hexadecimalValue: sha256),
                byteCount: UInt64(data.count)
            )
        } else {
            sourceReference = nil
        }
        return DRCArtifactRecord(
            id: id,
            kind: kind,
            path: String(url.path(percentEncoded: false).dropFirst(base.path(percentEncoded: false).count + 1)),
            byteCount: data.count,
            sha256: sha256,
            sourceReference: sourceReference
        )
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCArtifactManifestVerifierTests-\(UUID().uuidString)")
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
