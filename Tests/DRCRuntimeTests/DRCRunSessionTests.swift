import Foundation
import Testing
import DRCCore
import DRCRuntime

@Suite("DRC run session")
struct DRCRunSessionTests {
    @Test func successfulSessionFinishesEventStream() async throws {
        let fixture = try SessionLayoutFixture()
        defer { fixture.remove() }
        let request = DRCRequest(
            layoutURL: fixture.layoutURL,
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "stub")
        )
        let backend = SessionStubBackend()
        let session = DRCRunSession(
            engine: DefaultDRCEngine(backends: [backend]),
            request: request
        )
        await session.start()

        var sawCompletion = false
        for await event in session.events {
            if case .completed = event {
                sawCompletion = true
            }
        }
        #expect(sawCompletion)
        #expect(await session.currentState() == .succeeded)
        _ = try await session.wait()
        await session.shutdown()
    }

    @Test func cancellationFinishesEventStreamAsCancelled() async throws {
        let fixture = try SessionLayoutFixture()
        defer { fixture.remove() }
        let request = DRCRequest(
            layoutURL: fixture.layoutURL,
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "stub")
        )
        let session = DRCRunSession(
            engine: DefaultDRCEngine(backends: [SessionStubBackend(delayNanoseconds: 50_000_000)]),
            request: request
        )
        await session.start()
        await session.cancel(reason: "test cancellation")

        var sawCancellation = false
        for await event in session.events {
            if case .cancelled(let reason) = event {
                sawCancellation = reason == "test cancellation"
            }
        }
        #expect(sawCancellation)
        #expect(await session.currentState() == .cancelled)
        await session.shutdown()
    }

    @Test func shutdownTransitionsRunningSessionToCancelledAndFinishesStream() async throws {
        let fixture = try SessionLayoutFixture()
        defer { fixture.remove() }
        let request = DRCRequest(
            layoutURL: fixture.layoutURL,
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "stub")
        )
        let session = DRCRunSession(
            engine: DefaultDRCEngine(backends: [SessionStubBackend(delayNanoseconds: 50_000_000)]),
            request: request
        )
        await session.start()
        await session.shutdown()
        #expect(await session.currentState() == .cancelled)

        var eventCount = 0
        for await _ in session.events {
            eventCount += 1
        }
        #expect(eventCount > 0)
    }
}

private struct SessionLayoutFixture {
    let directory: URL
    let layoutURL: URL

    init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCRunSessionTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let layoutURL = directory.appending(path: "layout.json")
        try Data("{}".utf8).write(to: layoutURL, options: .atomic)
        self.directory = directory
        self.layoutURL = layoutURL
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove DRC run-session fixture: \(error.localizedDescription)")
        }
    }
}

private struct SessionStubBackend: DRCBackend {
    let backendID = "stub"
    var delayNanoseconds: UInt64 = 0

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try DRCExecutionResult.inProcess(
            request: request,
            result: DRCResult(
                backendID: backendID,
                toolName: "session-stub",
                success: true,
                completed: true,
                logPath: ""
            )
        )
    }
}
