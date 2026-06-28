import Foundation
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
        #expect(manifest.backendID == "native")
        #expect(manifest.passed)
        #expect(manifest.inputs.contains { $0.id == "input-layout" && $0.sha256 != nil })
        #expect(manifest.outputs.contains { $0.id == "report" && $0.sha256 != nil })
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
}
