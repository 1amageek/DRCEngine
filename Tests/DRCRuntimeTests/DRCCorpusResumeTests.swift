import Foundation
import Testing
import DRCCore
import DRCRuntime

@Suite("DRC corpus resume")
struct DRCCorpusResumeTests {
    @Test func resumeReusesVerifiedMatchedCasesAndEmitsProgress() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let layoutURL = root.appending(path: "layout.json")
        let specURL = root.appending(path: "corpus.json")
        let outputDirectory = root.appending(path: "output")
        try Data("layout".utf8).write(to: layoutURL)
        try writeJSON(DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "clean",
                layoutPath: layoutURL.lastPathComponent,
                topCell: "top",
                backendID: "resume-stub",
                expectedPassed: true
            ),
        ]), to: specURL)

        let counter = RunCounter()
        let engine = DefaultDRCEngine(backends: [ResumeStubBackend(counter: counter)])
        let firstReport = try await DRCCorpusRunner(engine: engine).run(
            specURL: specURL,
            outputDirectory: outputDirectory
        )
        #expect(firstReport.completed)
        #expect(firstReport.runID != nil)
        #expect(firstReport.specSHA256?.count == 64)
        #expect(await counter.value == 1)

        let firstManifestPath = try #require(firstReport.caseResults.first?.manifestPath)
        let firstManifestIssues = try DRCArtifactManifestVerifier().verify(
            manifestURL: URL(filePath: firstManifestPath)
        )
        #expect(firstManifestIssues.isEmpty)

        let eventSink = EventSink()
        let resumedReport = try await DRCCorpusRunner(engine: engine).run(
            specURL: specURL,
            outputDirectory: outputDirectory,
            options: DRCCorpusRunOptions(
                resumeReportURL: outputDirectory.appending(path: "drc-corpus-report.json")
            ),
            eventHandler: { event in
                await eventSink.append(event)
            }
        )

        #expect(resumedReport.completed)
        #expect(resumedReport.parentRunID == firstReport.runID)
        #expect(await counter.value == 1)
        #expect(await eventSink.resumedCaseCount == 1)
        #expect(await eventSink.completedCaseCount == 1)
        #expect(await eventSink.checkpointCount >= 1)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCCorpusResumeTests-\(UUID().uuidString)")
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

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic])
    }
}

private actor RunCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor EventSink {
    private(set) var resumedCaseCount = 0
    private(set) var completedCaseCount = 0
    private(set) var checkpointCount = 0

    func append(_ event: DRCCorpusRunEvent) {
        switch event {
        case .caseResumed:
            resumedCaseCount += 1
        case .caseCompleted:
            completedCaseCount += 1
        case .checkpointWritten:
            checkpointCount += 1
        default:
            break
        }
    }
}

private struct ResumeStubBackend: DRCBackend {
    let counter: RunCounter
    let backendID = "resume-stub"
    let identity = DRCBackendIdentity(backendID: "resume-stub", implementationFamily: .layoutVerify)

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        await counter.increment()
        return try DRCExecutionResult.inProcess(
            request: request,
            result: DRCResult(
                backendID: backendID,
                backendIdentity: identity,
                toolName: "ResumeStub",
                success: true,
                completed: true,
                logPath: ""
            ),
            implementationID: DRCExecutionProvenance.implementationID(for: identity),
            implementationVersion: identity.toolVersion
                ?? DRCExecutionProvenance.implementationVersion(for: backendID),
            implementationBuild: identity.executableDigest
                ?? DRCExecutionProvenance.currentExecutableDigest()
        )
    }
}
