import CircuiteFoundation
import DRCCore
import Foundation
import Testing

@Suite("DRC execution provenance")
struct DRCExecutionProvenanceTests {
    @Test func rejectsInputChangedAfterExecutionSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let layoutURL = directory.appending(path: "layout.json")
        try Data("initial-layout".utf8).write(to: layoutURL)
        let request = DRCRequest(
            layoutURL: layoutURL,
            topCell: "top",
            backendSelection: DRCBackendSelection(backendID: "native")
        )
        let inputs = try DRCExecutionProvenance.captureInputArtifacts(for: request)
        try Data("changed-layout".utf8).write(to: layoutURL, options: .atomic)
        let result = DRCResult(
            backendID: "native",
            toolName: "NativeDRC",
            success: true,
            completed: true,
            logPath: ""
        )

        #expect(throws: DRCError.backendFailed(
            "A DRC input artifact changed during execution."
        )) {
            _ = try DRCExecutionProvenance.make(
                request: request,
                result: result,
                inputArtifacts: inputs,
                invocation: ExecutionInvocation.inProcess(entryPoint: "test"),
                startedAt: Date(timeIntervalSince1970: 1),
                completedAt: Date(timeIntervalSince1970: 2)
            )
        }
    }
}
