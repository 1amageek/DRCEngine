import Foundation
import Testing
import DRCCore
import DRCAdapters

@Suite("Magic DRC adapter")
struct MagicDRCAdapterTests {
    @Test func additionalEnvironmentCannotOverrideReservedKeys() async throws {
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            magicExecutableURL: URL(filePath: "/bin/true"),
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            options: DRCOptions(additionalEnvironment: ["DRC_CELL": "other"])
        )

        var didThrowExpectedError = false
        do {
            _ = try await adapter.run(request)
        } catch let error as DRCError {
            didThrowExpectedError = error == .invalidInput("additionalEnvironment contains reserved keys: DRC_CELL")
        } catch {
            throw error
        }

        #expect(didThrowExpectedError)
    }

    @Test func repeatedRunsUseDistinctLogArtifacts() async throws {
        let directory = try makeTemporaryDirectory()
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic",
            body: """
            #!/bin/sh
            echo "DRC_SUMMARY total=0 cell=$DRC_CELL"
            echo "DRC_DONE"
            """
        )
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            workingDirectory: directory
        )

        let first = try await adapter.run(request)
        let second = try await adapter.run(request)

        #expect(first.result.passed)
        #expect(second.result.passed)
        #expect(first.result.logPath != second.result.logPath)
        #expect(FileManager.default.fileExists(atPath: first.result.logPath))
        #expect(FileManager.default.fileExists(atPath: second.result.logPath))
        #expect(first.result.provenance?.executablePath == executableURL.path(percentEncoded: false))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MagicDRCAdapterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutableScript(in directory: URL, name: String, body: String) throws -> URL {
        let scriptURL = directory.appending(path: name)
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path(percentEncoded: false)
        )
        return scriptURL
    }
}
