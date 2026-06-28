import Foundation
import Synchronization
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

    @Test func magicDRCStyleEnvironmentIsForwarded() async throws {
        let directory = try makeTemporaryDirectory()
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-style",
            body: """
            #!/bin/sh
            echo "STYLE=$MAGIC_DRC_STYLE"
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
            workingDirectory: directory,
            options: DRCOptions(additionalEnvironment: ["MAGIC_DRC_STYLE": "drc(full)"])
        )

        let result = try await adapter.run(request)
        let log = try String(contentsOfFile: result.result.logPath, encoding: .utf8)

        #expect(result.result.passed)
        #expect(log.contains("STYLE=drc(full)"))
    }

    @Test func magicLayoutInputForwardsDRCMagInsteadOfDRCGDS() async throws {
        let directory = try makeTemporaryDirectory()
        let magicLayoutURL = directory.appending(path: "inv.mag")
        try "magic\ntech sky130A\n<< end >>\n".write(to: magicLayoutURL, atomically: true, encoding: .utf8)
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-layout",
            body: """
            #!/bin/sh
            echo "MAG=$DRC_MAG"
            echo "GDS=$DRC_GDS"
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
            layoutURL: magicLayoutURL,
            topCell: "inv",
            layoutFormat: .magicLayout,
            workingDirectory: directory
        )

        let result = try await adapter.run(request)
        let log = try String(contentsOfFile: result.result.logPath, encoding: .utf8)

        #expect(result.result.passed)
        #expect(log.contains("MAG=\(magicLayoutURL.path(percentEncoded: false))"))
        #expect(log.contains("GDS=\n"))
    }

    @Test func invalidMagicDRCStyleEnvironmentIsRejected() async throws {
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            magicExecutableURL: URL(filePath: "/bin/true"),
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            options: DRCOptions(additionalEnvironment: ["MAGIC_DRC_STYLE": "drc(full);exec"])
        )

        var didThrowExpectedError = false
        do {
            _ = try await adapter.run(request)
        } catch let error as DRCError {
            didThrowExpectedError = error == .invalidInput("MAGIC_DRC_STYLE contains unsupported characters")
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

    @Test(.timeLimit(.minutes(1)))
    func cancellationCheckTerminatesMagicProcessTree() async throws {
        let directory = try makeTemporaryDirectory()
        let childSurvived = directory.appending(path: "child-survived")
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-cancel",
            body: """
            #!/bin/sh
            trap '' TERM
            (
                trap '' TERM
                sleep 1
                touch \(shellSingleQuoted(childSurvived.path(percentEncoded: false)))
            ) &
            echo "DRC_STARTED"
            sleep 10
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
            workingDirectory: directory,
            options: DRCOptions(timeoutSeconds: 5)
        )
        let probe = CancellationProbe()

        let task = Task {
            try await adapter.run(
                request,
                cancellationCheck: {
                    probe.isCancelled
                }
            )
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        probe.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected Magic DRC cancellation")
        } catch let error as DRCError {
            switch error {
            case .cancelled:
                break
            default:
                Issue.record("Unexpected DRC error: \(error)")
            }
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }

        try await Task.sleep(nanoseconds: 1_300_000_000)
        let didChildSurvive = FileManager.default.fileExists(atPath: childSurvived.path(percentEncoded: false))
        if didChildSurvive {
            Issue.record("Magic DRC child process survived cancellation")
        }
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

    private func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private final class CancellationProbe: Sendable {
    private let state = Mutex(false)

    var isCancelled: Bool {
        state.withLock { $0 }
    }

    func cancel() {
        state.withLock { $0 = true }
    }
}
