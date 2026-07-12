import Foundation
import Testing
import DRCCore
import DRCRuntime

@Suite("DRC request validation")
struct DRCRequestValidationTests {
    @Test func rejectsInvalidTimeoutBeforeBackendLookup() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "missing"),
            options: DRCOptions(timeoutSeconds: .nan)
        )
        do {
            _ = try await DefaultDRCEngine(backends: []).run(request)
            Issue.record("Expected invalid timeout to be rejected")
        } catch let error as DRCError {
            #expect(error == .invalidInput("DRC timeoutSeconds must be finite and greater than zero."))
        }
    }

    @Test func rejectsControlCharactersInEnvironmentValues() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "missing"),
            options: DRCOptions(additionalEnvironment: ["DRC_CELL": "top\nother"])
        )
        do {
            _ = try await DefaultDRCEngine(backends: []).run(request)
            Issue.record("Expected invalid environment value to be rejected")
        } catch let error as DRCError {
            #expect(error == .invalidInput("DRC environment value for 'DRC_CELL' contains a control character."))
        }
    }

    @Test func rejectsNonPOSIXEnvironmentKeys() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "missing"),
            options: DRCOptions(additionalEnvironment: ["1INVALID": "value"])
        )

        do {
            _ = try await DefaultDRCEngine(backends: []).run(request)
            Issue.record("Expected invalid environment key to be rejected")
        } catch let error as DRCError {
            #expect(error == .invalidInput("DRC environment key '1INVALID' is invalid."))
        }
    }

    @Test func rejectsControlCharactersInTopCellBeforeBackendLookup() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top\ncell",
            backendSelection: DRCBackendSelection(backendID: "missing")
        )

        do {
            _ = try await DefaultDRCEngine(backends: []).run(request)
            Issue.record("Expected invalid top-cell control character to be rejected")
        } catch let error as DRCError {
            #expect(error == .invalidInput("DRC top cell contains a control character."))
        }
    }

    @Test func rejectsInvalidCanonicalStateDigestBeforeBackendLookup() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "missing"),
            canonicalStateDigest: "not-a-sha256"
        )

        await #expect(throws: DRCError.invalidInput(
            "DRC canonicalStateDigest must be a lowercase 64-character SHA-256 digest."
        )) {
            try await DefaultDRCEngine(backends: []).run(request)
        }
    }

    @Test func rejectsSignedArtifactsWithoutTrustedKeyBeforeBackendLookup() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/layout.json"),
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "missing"),
            options: DRCOptions(requireSignedArtifacts: true)
        )

        await #expect(throws: DRCError.invalidInput(
            "DRC trustedArtifactPublicKey is required when requireSignedArtifacts is enabled."
        )) {
            try await DefaultDRCEngine(backends: []).run(request)
        }
    }

    @Test func decodesLegacyOptionsWithoutNewTrustFields() throws {
        let data = Data("""
        {"timeoutSeconds":12,"additionalEnvironment":{"MODE":"test"}}
        """.utf8)
        let options = try JSONDecoder().decode(DRCOptions.self, from: data)
        #expect(options.timeoutSeconds == 12)
        #expect(options.additionalEnvironment["MODE"] == "test")
        #expect(!options.requireSignedArtifacts)
        #expect(options.trustedArtifactPublicKey == nil)
    }
}
