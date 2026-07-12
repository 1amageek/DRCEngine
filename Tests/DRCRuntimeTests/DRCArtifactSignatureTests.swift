import Foundation
import Testing
import DRCCore

@Suite("DRC artifact signatures")
struct DRCArtifactSignatureTests {
    @Test func verifiesTrustedEd25519ManifestAndRejectsTampering() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let manifestURL = directory.appending(path: "manifest.json")
        let unsigned = DRCArtifactManifest(
            generatedAt: "2026-07-12T00:00:00Z",
            backendID: "native",
            toolName: "NativeDRC",
            passed: true,
            completed: true,
            inputs: [],
            outputs: [
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
        let signer = DRCEd25519ArtifactSigner()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let signature = try signer.sign(encoder.encode(unsigned.withSignature(nil)))
        let signed = unsigned.withSignature(signature)
        try encoder.encode(signed).write(to: manifestURL, options: [.atomic])

        let verifier = DRCArtifactManifestVerifier()
        #expect(try verifier.verify(
            manifestURL: manifestURL,
            requireSignature: false,
            trustedPublicKey: signer.publicKey
        ).isEmpty)
        #expect(try verifier.verify(
            manifestURL: manifestURL,
            requireSignature: true,
            trustedPublicKey: signer.publicKey
        ).contains { $0.code == "signed-request-digest-missing" })
        #expect(try !verifier.verify(
            manifestURL: manifestURL,
            requireSignature: false,
            trustedPublicKey: DRCEd25519ArtifactSigner().publicKey
        ).isEmpty)

        let tampered = unsigned.withSignature(
            DRCArtifactSignature(
                algorithm: signature.algorithm,
                publicKey: signature.publicKey,
                signature: String(signature.signature.dropLast()) + "A"
            )
        )
        try encoder.encode(tampered).write(to: manifestURL, options: [.atomic])
        #expect(try verifier.verify(
            manifestURL: manifestURL,
            requireSignature: false,
            trustedPublicKey: signer.publicKey
        ).contains { $0.code == "signature-invalid" })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCArtifactSignatureTests-\(UUID().uuidString)")
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
