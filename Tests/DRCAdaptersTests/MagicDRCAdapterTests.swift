import Foundation
import Synchronization
import Testing
import DRCCore
import DRCAdapters

@Suite("Magic DRC adapter")
struct MagicDRCAdapterTests {
    @Test func additionalEnvironmentCannotOverrideReservedKeys() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0]).write(to: layoutURL, options: .atomic)
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: URL(filePath: "/bin/true"),
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: layoutURL,
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
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0x00]).write(to: layoutURL, options: .atomic)
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            workingDirectory: directory,
            options: DRCOptions(additionalEnvironment: ["MAGIC_DRC_STYLE": "drc(full)"])
        )

        let result = try await adapter.run(request)
        let log = try String(contentsOfFile: result.result.logPath, encoding: .utf8)

        #expect(result.result.passed)
        #expect(log.contains("STYLE=drc(full)"))
        #expect(result.provenance.producer.identifier == "magic")
        #expect(result.provenance.producer.version == "test-magic-1.0")
        #expect(result.provenance.producer.build?.count == 64)
        #expect(result.provenance.inputs.count == 1)
        #expect(result.provenance.invocation?.executable == executableURL.path(percentEncoded: false))
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
            toolVersion: "test-magic-1.0",
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
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0]).write(to: layoutURL, options: .atomic)
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: URL(filePath: "/bin/true"),
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: layoutURL,
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

    @Test func unsupportedLayoutFormatIsRejectedBeforeLaunchingMagic() async throws {
        let directory = try makeTemporaryDirectory()
        let launchedMarker = directory.appending(path: "launched")
        let oasisURL = directory.appending(path: "layout.oas")
        try "not-oasis".write(to: oasisURL, atomically: true, encoding: .utf8)
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-unsupported-format",
            body: """
            #!/bin/sh
            touch \(shellSingleQuoted(launchedMarker.path(percentEncoded: false)))
            """
        )
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: oasisURL,
            topCell: "inv",
            layoutFormat: .oasis,
            workingDirectory: directory
        )

        do {
            _ = try await adapter.run(request)
            Issue.record("Expected Magic DRC unsupported format rejection")
        } catch let error as DRCError {
            guard case .invalidInput(let message) = error else {
                Issue.record("Unexpected DRC error: \(error)")
                return
            }
            #expect(message.contains("supports only GDSII or Magic layout inputs"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: launchedMarker.path(percentEncoded: false)))
    }

    @Test func unknownAutoLayoutExtensionIsRejectedBeforeLaunchingMagic() async throws {
        let directory = try makeTemporaryDirectory()
        let launchedMarker = directory.appending(path: "launched")
        let unknownLayoutURL = directory.appending(path: "layout.layout")
        try "not-gds-or-magic".write(to: unknownLayoutURL, atomically: true, encoding: .utf8)
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-unknown-auto-format",
            body: """
            #!/bin/sh
            touch \(shellSingleQuoted(launchedMarker.path(percentEncoded: false)))
            """
        )
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: unknownLayoutURL,
            topCell: "inv",
            layoutFormat: .auto,
            workingDirectory: directory
        )

        do {
            _ = try await adapter.run(request)
            Issue.record("Expected Magic DRC unknown auto-format rejection")
        } catch let error as DRCError {
            guard case .invalidInput(let message) = error else {
                Issue.record("Unexpected DRC error: \(error)")
                return
            }
            #expect(message.contains("auto layout format requires a .gds or .mag extension"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: launchedMarker.path(percentEncoded: false)))
    }

    @Test func emptyTopCellIsRejectedBeforeLaunchingMagic() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0]).write(to: layoutURL, options: .atomic)
        let launchedMarker = directory.appending(path: "launched")
        let executableURL = try makeExecutableScript(
            in: directory,
            name: "fake-magic-empty-top",
            body: """
            #!/bin/sh
            touch \(shellSingleQuoted(launchedMarker.path(percentEncoded: false)))
            """
        )
        let adapter = MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: layoutURL,
            topCell: " \t ",
            workingDirectory: directory
        )

        do {
            _ = try await adapter.run(request)
            Issue.record("Expected Magic DRC empty top-cell rejection")
        } catch let error as DRCError {
            guard case .invalidInput(let message) = error else {
                Issue.record("Unexpected DRC error: \(error)")
                return
            }
            #expect(message == "topCell must not be empty")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: launchedMarker.path(percentEncoded: false)))
    }

    @Test func repeatedRunsUseDistinctLogArtifacts() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "inverter.gds")
        try Data([0]).write(to: layoutURL, options: .atomic)
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
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
        let request = DRCRequest(
            layoutURL: layoutURL,
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
        let fixture = try makeCancellationFixture()
        let layoutURL = fixture.directory.appending(path: "inverter.gds")
        try Data([0]).write(to: layoutURL, options: .atomic)
        let adapter = makeAdapter(executableURL: fixture.executableURL)
        let request = DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            workingDirectory: fixture.directory,
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

        await expectMagicDRCCancellation(from: task)

        try await Task.sleep(nanoseconds: 1_300_000_000)
        assertNoChildProcessSurvived(fixture.childSurvived)
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

    private struct CancellationFixture {
        let directory: URL
        let childSurvived: URL
        let executableURL: URL
    }

    private func makeCancellationFixture() throws -> CancellationFixture {
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
        return CancellationFixture(
            directory: directory,
            childSurvived: childSurvived,
            executableURL: executableURL
        )
    }

    private func makeAdapter(executableURL: URL) -> MagicDRCAdapter {
        MagicDRCAdapter(toolchain: MagicDRCToolchain(
            toolVersion: "test-magic-1.0",
            magicExecutableURL: executableURL,
            rcFileURL: URL(filePath: "/tmp/sky130A.magicrc"),
            pdkRoot: "/tmp/pdk",
            driverScriptURL: URL(filePath: "/tmp/drc.tcl")
        ))
    }

    private func expectMagicDRCCancellation(from task: Task<DRCExecutionResult, Error>) async {
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
    }

    private func assertNoChildProcessSurvived(_ childSurvived: URL) {
        let didChildSurvive = FileManager.default.fileExists(atPath: childSurvived.path(percentEncoded: false))
        if didChildSurvive {
            Issue.record("Magic DRC child process survived cancellation")
        }
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
