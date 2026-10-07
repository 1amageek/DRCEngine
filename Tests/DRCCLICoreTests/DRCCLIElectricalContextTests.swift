import Foundation
import CryptoKit
import Testing
import DRCCore
import DRCCLICore
import LayoutCore
import LayoutTech

extension DRCCLIOptionsTests {
    @Test(arguments: [DRCElectricalContext.geometric, .deviceAwareMOS])
    func electricalContextFlagIsTypedAndRetained(context: DRCElectricalContext) throws {
        let arguments = [
            "--layout", "/tmp/layout.layout.json", "--top-cell", "TOP", "--out", "/tmp/drc",
        ]
        let explicit = try DRCCLIOptions(arguments: arguments + ["--electrical-context", context.rawValue])
        #expect(explicit.electricalContext == context)
        #expect(explicit.makeRequest().options.electricalContext == context)

        let omitted = try DRCCLIOptions(arguments: arguments)
        #expect(omitted.electricalContext == .geometric)
        #expect(omitted.makeRequest().options.electricalContext == .geometric)
        let encoded = try JSONEncoder().encode(omitted.makeRequest().options)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["electricalContext"] as? String == "geometric")
    }

    @Test(arguments: [
        ["--electrical-context"],
        ["--electrical-context", ""],
        ["--electrical-context", "--json"],
        ["--electrical-context", "DeviceAwareMOS"],
        ["--electrical-context", " "],
    ])
    func invalidElectricalContextValuesRefuseBeforeArtifacts(arguments: [String]) async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let output = root.appending(path: "artifacts")
        let command = [
            "--layout", root.appending(path: "missing.layout.json").path(percentEncoded: false),
            "--top-cell", "TOP", "--out", output.path(percentEncoded: false),
        ] + arguments
        let expected: DRCCLIError
        if arguments.count == 1 || arguments[1].isEmpty || arguments[1].hasPrefix("--") {
            expected = .missingValue("--electrical-context")
        } else {
            expected = .invalidValue(
                argument: "--electrical-context", value: arguments[1],
                expected: "geometric or deviceAwareMOS"
            )
        }
        #expect(throws: expected) { _ = try DRCCLIOptions(arguments: command) }
        let invocation = await DRCCLI.invoke(arguments: command)
        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError == expected.localizedDescription + "\n")
        #expect(!FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
    }

    @Test func nativeCLIContextsPersistTheDeclaredFieldAndCommitDifferentRequestDigests() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let layoutURL = root.appending(path: "layout.layout.json")
        let technologyURL = root.appending(path: "technology.json")
        let output = root.appending(path: "artifacts")
        let cell = LayoutCell(name: "TOP", shapes: [LayoutShape(
            layer: LayoutLayerID(name: "M1", purpose: "drawing"),
            geometry: .rect(.init(origin: .init(x: 0, y: 0), size: .init(width: 1, height: 1)))
        )])
        try writeJSON(LayoutDocument(name: "CLI", cells: [cell], topCellID: cell.id), to: layoutURL)
        try writeJSON(LayoutTechDatabase.sampleProcess(), to: technologyURL)
        let layoutBytes = try Data(contentsOf: layoutURL)
        let technologyBytes = try Data(contentsOf: technologyURL)
        var requestDigests: [String] = []
        var requestsWithoutContext: [Data] = []

        for context in [DRCElectricalContext.geometric, .deviceAwareMOS] {
            let invocation = await DRCCLI.invoke(arguments: [
                "--layout", layoutURL.path(percentEncoded: false), "--top-cell", "TOP",
                "--tech", technologyURL.path(percentEncoded: false), "--format", "native-json",
                "--backend", "native-gds", "--out", output.path(percentEncoded: false),
                "--electrical-context", context.rawValue, "--json",
            ])
            #expect(invocation.exitCode == 0)
            #expect(invocation.standardError.isEmpty)
            let cli = try JSONDecoder().decode(DRCCLIOutput.self, from: Data(invocation.standardOutput.utf8))
            let reportURL = try #require(cli.reportPath.map(URL.init(fileURLWithPath:)))
            let manifestURL = try #require(cli.manifestPath.map(URL.init(fileURLWithPath:)))
            let report = try JSONDecoder().decode(DRCExecutionResult.self, from: Data(contentsOf: reportURL))
            let manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: Data(contentsOf: manifestURL))
            #expect(cli.status == "passed")
            #expect(report.result.passed && report.result.completed)
            #expect(report.result.backendID == "native-gds")
            #expect(report.request.options.electricalContext == context)
            let nativeInvocation = try #require(report.provenance.invocation)
            #expect(nativeInvocation.mode == .inProcess)
            #expect(nativeInvocation.entryPoint == "LayoutGDSDRCBackend.run")
            #expect(try DRCArtifactManifestVerifier().verify(manifestURL: manifestURL).isEmpty)
            let retainedLayout = try #require(manifest.inputs.first { $0.id == "input-layout" })
            #expect(retainedLayout.sha256 == electricalContextSHA256(layoutBytes))
            #expect(retainedLayout.byteCount == layoutBytes.count)
            let retainedTechnology = try #require(manifest.inputs.first { $0.id == "input-technology" })
            #expect(retainedTechnology.sha256 == electricalContextSHA256(technologyBytes))
            #expect(retainedTechnology.byteCount == technologyBytes.count)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let requestBytes = try encoder.encode(report.request)
            let digest = try #require(manifest.requestSHA256)
            #expect(digest == electricalContextSHA256(requestBytes))
            requestDigests.append(digest)
            var requestObject = try #require(JSONSerialization.jsonObject(with: requestBytes) as? [String: Any])
            var optionsObject = try #require(requestObject["options"] as? [String: Any])
            #expect(optionsObject.removeValue(forKey: "electricalContext") as? String == context.rawValue)
            requestObject["options"] = optionsObject
            requestsWithoutContext.append(try JSONSerialization.data(withJSONObject: requestObject, options: [.sortedKeys]))
        }
        #expect(requestDigests[0] != requestDigests[1])
        #expect(requestsWithoutContext[0] == requestsWithoutContext[1])
        #expect(try Data(contentsOf: layoutURL) == layoutBytes)
        #expect(try Data(contentsOf: technologyURL) == technologyBytes)
    }

    @Test func incapableBackendRejectsDeviceContextBeforeInputIO() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let output = root.appending(path: "artifacts")
        let invocation = await DRCCLI.invoke(arguments: [
            "--layout", root.appending(path: "missing.json").path(percentEncoded: false),
            "--top-cell", "TOP", "--backend", "native", "--out", output.path(percentEncoded: false),
            "--electrical-context", "deviceAwareMOS", "--json",
        ])
        let expected = DRCError.unsupportedElectricalContext(backendID: "native", requested: .deviceAwareMOS)
        #expect(invocation.exitCode == 1)
        #expect(invocation.standardOutput.isEmpty)
        #expect(invocation.standardError == expected.localizedDescription + "\n")
        #expect(!FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
    }

    @Test func helpAdvertisesTheExplicitContextWithoutExecution() async {
        let invocation = await DRCCLI.invoke(arguments: ["--help"])
        #expect(invocation.exitCode == 0)
        #expect(invocation.standardError.isEmpty)
        #expect(invocation.standardOutput.contains("--electrical-context <context>"))
        #expect(invocation.standardOutput.contains("geometric or deviceAwareMOS (case-sensitive)"))
        #expect(invocation.standardOutput.contains("Default: geometric; backend must support the context"))
    }
}

private func electricalContextSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
