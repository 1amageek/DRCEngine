import Foundation
import CryptoKit
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    @Test func techDefaultsToNativeGDSBackend() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.gds",
            "--top-cell", "inv",
            "--tech", "/tmp/tech.json",
            "--out", "/tmp/drc",
        ])

        #expect(options.makeRequest().backendSelection.backendID == "native-gds")
    }

    @Test func formatAndJSONFlagAreParsed() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.oas",
            "--top-cell", "inv",
            "--tech", "/tmp/tech.json",
            "--waivers", "/tmp/drc-waivers.json",
            "--format", "oasis",
            "--out", "/tmp/drc",
            "--json",
        ])

        let request = options.makeRequest()
        #expect(request.layoutFormat == .oasis)
        #expect(request.waiverURL?.path(percentEncoded: false) == "/tmp/drc-waivers.json")
        #expect(options.emitJSON)
    }

    @Test func flowAuthorityOptionIsRejected() throws {
        #expect(throws: DRCCLIError.self) {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.json",
                "--top-cell", "inv",
                "--waivers", "/tmp/drc-waivers.json",
                "--out", "/tmp/drc",
                "--require-approved-waivers",
            ])
        }
    }

    @Test func signedArtifactTrustGateIsForwardedToRequest() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.json",
            "--top-cell", "inv",
            "--out", "/tmp/drc",
            "--require-signed-artifacts",
            "--trusted-artifact-public-key", Data(repeating: 0, count: 32).base64EncodedString(),
            "--artifact-signing-private-key", "/tmp/drc-signing-key",
        ])

        #expect(options.requireSignedArtifacts)
        #expect(options.artifactSigningPrivateKeyURL?.path(percentEncoded: false) == "/tmp/drc-signing-key")
        #expect(options.trustedArtifactPublicKey == Data(repeating: 0, count: 32).base64EncodedString())
        #expect(options.makeRequest().options.requireSignedArtifacts)
        #expect(options.makeRequest().options.trustedArtifactPublicKey == Data(repeating: 0, count: 32).base64EncodedString())
    }

    @Test func antennaRuleReadinessGateIsForwardedToRequest() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.gds",
            "--top-cell", "inv",
            "--tech", "/tmp/tech.json",
            "--out", "/tmp/drc",
            "--require-antenna-rules",
        ])

        #expect(options.requireAntennaRules)
        #expect(options.makeRequest().options.requireAntennaRules)
    }

    @Test func signedArtifactCLIFlowPersistsVerifiableManifest() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let layoutURL = root.appending(path: "layout.json")
        let outputDirectory = root.appending(path: "artifacts")
        let keyURL = root.appending(path: "ed25519.key")
        let keyData = Data(repeating: 7, count: 32)
        let signer = try DRCEd25519ArtifactSigner(rawRepresentation: keyData)
        try keyData.write(to: keyURL, options: [.atomic])
        try Data("""
        {
          "rectangles" : [
            { "id" : "m1", "layer" : "met1", "xMax" : 1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "signed-cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.utf8).write(to: layoutURL, options: [.atomic])

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--require-signed-artifacts",
            "--trusted-artifact-public-key", signer.publicKey,
            "--artifact-signing-private-key", keyURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 0)
        let manifestURL = try #require(
            FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)
                .first { $0.lastPathComponent.hasPrefix("drc-artifact-manifest-") }
        )
        #expect(try DRCArtifactManifestVerifier().verify(
            manifestURL: manifestURL,
            requireSignature: true,
            trustedPublicKey: signer.publicKey
        ).isEmpty)
    }

    @Test func signedCorpusCLIFlowVerifiesCaseArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let keyURL = root.appending(path: "corpus.key")
        let keyData = Data(repeating: 11, count: 32)
        let signer = try DRCEd25519ArtifactSigner(rawRepresentation: keyData)
        try keyData.write(to: keyURL, options: [.atomic])

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", fixtureCorpusSpecURL("drc-corpus-tight-budget.json").path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--require-signed-artifacts",
            "--trusted-artifact-public-key", signer.publicKey,
            "--artifact-signing-private-key", keyURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 2)
        let caseManifestURL = try #require(
            FileManager.default.contentsOfDirectory(
                at: outputDirectory.appending(path: "cases/clean-tight-budget"),
                includingPropertiesForKeys: nil
            ).first { $0.lastPathComponent.hasPrefix("drc-artifact-manifest-") }
        )
        #expect(try DRCArtifactManifestVerifier().verify(
            manifestURL: caseManifestURL,
            requireSignature: true,
            trustedPublicKey: signer.publicKey
        ).isEmpty)
    }

    @Test func nativeJSONFormatIsParsedForAgentFacingCanonicalLayoutInput() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.layout.json",
            "--top-cell", "inv",
            "--tech", "/tmp/tech.json",
            "--format", "native-json",
            "--out", "/tmp/drc",
        ])

        #expect(options.makeRequest().layoutFormat == .nativeJSON)
    }

    @Test func magicLayoutFormatIsParsedForMagicNativeLayoutInput() throws {
        let options = try DRCCLIOptions(arguments: [
            "--layout", "/tmp/inverter.mag",
            "--top-cell", "inv",
            "--format", "magic-layout",
            "--out", "/tmp/drc",
        ])

        #expect(options.makeRequest().layoutFormat == .magicLayout)
    }

    @Test func invalidFormatThrows() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.gds",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
                "--format", "lef",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--format",
            value: "lef",
            expected: "auto, gds, oasis, cif, dxf, native-json, or magic-layout"
        ))
    }

    @Test func invalidTimeoutThrows() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.gds",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
                "--timeout", "abc",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--timeout",
            value: "abc",
            expected: "positive finite seconds"
        ))
    }

    @Test func zeroTimeoutThrows() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.gds",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
                "--timeout", "0",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--timeout",
            value: "0",
            expected: "positive finite seconds"
        ))
    }

    @Test func nativeCLIWritesReportAndManifest() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        try """
        {
          "rectangles" : [
            { "id" : "m1", "layer" : "met1", "xMax" : 1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let exitCode = await DRCCLI.run(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let reportURL = try onlyArtifact(in: outputDirectory, prefix: "drc-report-")
        let manifestURL = try onlyArtifact(in: outputDirectory, prefix: "drc-artifact-manifest-")
        let report = try JSONDecoder().decode(DRCExecutionResult.self, from: Data(contentsOf: reportURL))
        let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))

        #expect(report.result.passed)
        #expect(canonicalPath(report.artifactManifestURL) == canonicalPath(manifestURL))
        #expect(manifest.schemaVersion == DRCArtifactManifest.currentSchemaVersion)
        #expect(manifest.backendID == "native")
        #expect(manifest.toolName == "NativeDRC")
        #expect(manifest.passed)
        #expect(manifest.completed)
        #expect(manifest.diagnosticSummary.infoCount == 0)
        #expect(manifest.diagnosticSummary.warningCount == 0)
        #expect(manifest.diagnosticSummary.errorCount == 0)
        #expect(manifest.diagnosticSummary.waivedErrorCount == 0)

        let inputLayout = try #require(manifest.inputs.first { $0.id == "input-layout" })
        let reportOutput = try #require(manifest.outputs.first { $0.id == "report" })
        let manifestOutput = try #require(manifest.outputs.first { $0.id == "manifest" })
        let layoutData = try Data(contentsOf: layoutURL)
        let reportData = try Data(contentsOf: reportURL)

        #expect(inputLayout.kind == .layout)
        #expect(!inputLayout.path.hasPrefix("/"))
        #expect(inputLayout.path.hasPrefix("retained-artifacts/input-layout/"))
        #expect(FileManager.default.fileExists(
            atPath: outputDirectory.appending(path: inputLayout.path).path(percentEncoded: false)
        ))
        #expect(inputLayout.byteCount == layoutData.count)
        #expect(inputLayout.sha256 == sha256(layoutData))
        #expect(reportOutput.kind == .report)
        #expect(reportOutput.path == reportURL.lastPathComponent)
        #expect(reportOutput.byteCount == reportData.count)
        #expect(reportOutput.sha256 == sha256(reportData))
        #expect(manifestOutput.kind == .manifest)
        #expect(manifestOutput.path == manifestURL.lastPathComponent)
        #expect(manifestOutput.byteCount == nil)
        #expect(manifestOutput.sha256 == nil)
    }

    @Test func nativeCLIWritesFailureReportAndManifestWithDiagnostics() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        try """
        {
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMax" : 0.1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let exitCode = await DRCCLI.run(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 2)
        let reportURL = try onlyArtifact(in: outputDirectory, prefix: "drc-report-")
        let manifestURL = try onlyArtifact(in: outputDirectory, prefix: "drc-artifact-manifest-")
        let reportData = try Data(contentsOf: reportURL)
        let report = try JSONDecoder().decode(DRCExecutionResult.self, from: reportData)
        let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))

        #expect(!report.result.passed)
        #expect(report.result.completed)
        #expect(canonicalPath(report.artifactManifestURL) == canonicalPath(manifestURL))
        let diagnostic = try #require(report.result.diagnostics.first)
        #expect(report.result.diagnostics.count == 1)
        #expect(diagnostic.severity == .error)
        #expect(diagnostic.ruleID == "met1.width")
        #expect(diagnostic.kind == "minimumWidth")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.relatedShapeIDs == ["thin"])
        #expect(diagnostic.measured == 0.1)
        #expect(diagnostic.required == 0.5)
        #expect(diagnostic.suggestedFix != nil)

        #expect(!manifest.passed)
        #expect(manifest.completed)
        #expect(manifest.diagnosticSummary.infoCount == 0)
        #expect(manifest.diagnosticSummary.warningCount == 0)
        #expect(manifest.diagnosticSummary.errorCount == 1)
        #expect(manifest.diagnosticSummary.waivedErrorCount == 0)
        #expect(manifest.waiverReport == nil)

        let inputLayout = try #require(manifest.inputs.first { $0.id == "input-layout" })
        let reportOutput = try #require(manifest.outputs.first { $0.id == "report" })
        let manifestOutput = try #require(manifest.outputs.first { $0.id == "manifest" })
        let layoutData = try Data(contentsOf: layoutURL)

        #expect(inputLayout.kind == .layout)
        #expect(inputLayout.byteCount == layoutData.count)
        #expect(inputLayout.sha256 == sha256(layoutData))
        #expect(reportOutput.kind == .report)
        #expect(reportOutput.path == reportURL.lastPathComponent)
        #expect(reportOutput.byteCount == reportData.count)
        #expect(reportOutput.sha256 == sha256(reportData))
        #expect(manifestOutput.kind == .manifest)
        #expect(manifestOutput.path == manifestURL.lastPathComponent)
        #expect(manifestOutput.byteCount == nil)
        #expect(manifestOutput.sha256 == nil)
    }

    @Test func nativeCLIInvocationJSONOutputMatchesPersistedFailureArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        try """
        {
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMax" : 0.1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 2)
        #expect(invocation.standardError.isEmpty)
        #expect(invocation.standardOutput.contains(#""status" : "failed""#))
        #expect(!invocation.standardOutput.contains("status=failed"))

        let data = try #require(invocation.standardOutput.data(using: .utf8))
        let output = try JSONDecoder().decode(DRCCLIOutput.self, from: data)
        let reportURL = try #require(output.reportPath.map(URL.init(fileURLWithPath:)))
        let manifestURL = try #require(output.manifestPath.map(URL.init(fileURLWithPath:)))
        let report = try JSONDecoder().decode(DRCExecutionResult.self, from: Data(contentsOf: reportURL))
        let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))

        #expect(output.status == "failed")
        #expect(output.backendID == "native")
        #expect(output.toolName == "NativeDRC")
        #expect(output.diagnosticSummary.errorCount == 1)
        #expect(output.runSummary.activeViolationCount == 1)
        #expect(output.runSummary.violationBuckets.first?.ruleID == "met1.width")
        #expect(output.diagnostics.first?.relatedShapeIDs == ["thin"])
        #expect(output.reportPath == reportURL.path(percentEncoded: false))
        #expect(output.manifestPath == manifestURL.path(percentEncoded: false))
        #expect(report.result.diagnostics == output.diagnostics)
        #expect(manifest.diagnosticSummary == output.diagnosticSummary)
        let reportOutput = try #require(manifest.outputs.first { $0.id == "report" })
        let reportData = try Data(contentsOf: reportURL)
        #expect(reportOutput.sha256 == sha256(reportData))
        #expect(reportOutput.byteCount == reportData.count)
    }

    @Test func singleRunCLIMissingLayoutReturnsOneWithoutArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let missingLayoutURL = root.appending(path: "missing-layout.json")

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", missingLayoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError.contains("Artifact file does not exist"))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.path(percentEncoded: false)))
    }

    @Test func singleRunCLIUnsupportedBackendReturnsOneWithoutArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        try """
        {
          "rectangles" : [],
          "rules" : [],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "unsupported-native",
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError.contains("Unsupported DRC backend"))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.path(percentEncoded: false)))
    }

    @Test func singleRunCLIDuplicateWaiverIDsReturnsOneWithoutArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        let waiverURL = root.appending(path: "drc-waivers.json")
        try """
        {
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMax" : 0.1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)
        try """
        {
          "schemaVersion" : 1,
          "waivers" : [
            {
              "id" : "duplicate-waiver",
              "kind" : "minimumWidth",
              "layer" : "met1",
              "reason" : "Fixture waiver",
              "relatedShapeIDs" : ["thin"],
              "ruleID" : "met1.width"
            },
            {
              "id" : "duplicate-waiver",
              "kind" : "minimumWidth",
              "layer" : "met1",
              "reason" : "Duplicate fixture waiver",
              "relatedShapeIDs" : ["thin"],
              "ruleID" : "met1.width"
            }
          ]
        }
        """.write(to: waiverURL, atomically: true, encoding: .utf8)

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--waivers", waiverURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError.contains("Waiver IDs must be unique"))
        #expect(try artifactCount(in: outputDirectory, prefix: "drc-report-") == 0)
        #expect(try artifactCount(in: outputDirectory, prefix: "drc-artifact-manifest-") == 0)
    }

    @Test func singleRunCLIUnscopedWaiverReturnsOneWithoutArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        let waiverURL = root.appending(path: "drc-waivers.json")
        try """
        {
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMax" : 0.1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)
        try """
        {
          "schemaVersion" : 1,
          "waivers" : [
            {
              "id" : "blanket-waiver",
              "reason" : "Too broad"
            }
          ]
        }
        """.write(to: waiverURL, atomically: true, encoding: .utf8)

        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--waivers", waiverURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError.contains("drc_waiver_unscoped"))
        #expect(invocation.standardError.contains("must include at least one scope selector"))
        #expect(try artifactCount(in: outputDirectory, prefix: "drc-report-") == 0)
        #expect(try artifactCount(in: outputDirectory, prefix: "drc-artifact-manifest-") == 0)
    }

    @Test func nativeCLIAppliesWaiverFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "artifacts")
        let layoutURL = root.appending(path: "layout.json")
        let waiverURL = root.appending(path: "drc-waivers.json")
        try """
        {
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMax" : 0.1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "cli-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)
        try """
        {
          "schemaVersion" : 1,
          "waivers" : [
            {
              "id" : "waive-thin-met1",
              "kind" : "minimumWidth",
              "layer" : "met1",
              "reason" : "Known fixture exception",
              "relatedShapeIDs" : ["thin"],
              "ruleID" : "met1.width"
            }
          ]
        }
        """.write(to: waiverURL, atomically: true, encoding: .utf8)

        let exitCode = await DRCCLI.run(arguments: [
            "--layout", layoutURL.path(percentEncoded: false),
            "--top-cell", "inv",
            "--backend", "native",
            "--waivers", waiverURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let reportURL = try onlyArtifact(in: outputDirectory, prefix: "drc-report-")
        let report = try JSONDecoder().decode(DRCExecutionResult.self, from: Data(contentsOf: reportURL))
        #expect(report.result.passed)
        #expect(report.result.diagnostics.first?.waiverID == "waive-thin-met1")
        #expect(report.waiverReport?.waivedDiagnosticCount == 1)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func artifactCount(in directory: URL, prefix: String) throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return 0
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(prefix) }.count
    }
}
