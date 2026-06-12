import Foundation
import Testing
import DRCCore
import DRCRuntime

@Suite("Default DRC engine")
struct DefaultDRCEngineTests {
    @Test func injectedBackendRunsAndPersistsReport() async throws {
        let directory = try makeTemporaryDirectory()
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            workingDirectory: directory,
            backendSelection: DRCBackendSelection(backendID: "stub")
        )

        let result = try await DefaultDRCEngine(backend: StubDRCBackend()).run(request)

        #expect(result.result.passed)
        #expect(result.reportURL?.lastPathComponent.hasPrefix("drc-report-") == true)
        #expect(result.reportURL?.pathExtension == "json")
        #expect(result.reportURL.map { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) } == true)
        let reportURL = try #require(result.reportURL)
        let data = try Data(contentsOf: reportURL)
        let decoded = try JSONDecoder().decode(DRCExecutionResult.self, from: data)
        #expect(decoded.result.provenance?.executablePath == "/bin/stub-drc")
    }

    @Test func rejectsMismatchedBackendSelection() async throws {
        let request = DRCRequest(
            layoutURL: URL(filePath: "/tmp/inverter.gds"),
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "magic")
        )
        var didThrowExpectedError = false

        do {
            _ = try await DefaultDRCEngine(backend: StubDRCBackend()).run(request)
        } catch let error as DRCError {
            didThrowExpectedError = error == .backendUnavailable("Unsupported DRC backend: magic")
        } catch {
            throw error
        }

        #expect(didThrowExpectedError)
    }

    @Test func pureSwiftBackendIsAvailableByDefault() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = directory.appending(path: "layout.json")
        try """
        {
          "rectangles" : [
            { "id" : "m1", "layer" : "met1", "xMax" : 1, "xMin" : 0, "yMax" : 1, "yMin" : 0 }
          ],
          "rules" : [
            { "id" : "met1.width", "kind" : "minimumWidth", "layer" : "met1", "value" : 0.5 }
          ],
          "technologyID" : "unit-test-tech",
          "topCell" : "inv",
          "unit" : "micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let result = try await DefaultDRCEngine(backend: nil).run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "pure-swift")
        ))

        #expect(result.result.passed)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DefaultDRCEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private struct StubDRCBackend: DRCBackend {
        let backendID = "stub"

        func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
            DRCExecutionResult(
                request: request,
                result: DRCResult(
                    backendID: backendID,
                    toolName: "stub-drc",
                    success: true,
                    completed: true,
                    logPath: "/tmp/stub-drc.log",
                    provenance: DRCToolProvenance(
                        executablePath: "/bin/stub-drc",
                        pdkRoot: "/tmp/pdk",
                        rcFilePath: "/tmp/sky130A.magicrc",
                        driverScriptPath: "/tmp/drc.tcl",
                        timeoutSeconds: request.options.timeoutSeconds
                    )
                )
            )
        }
    }
}
