import Foundation
import Testing
import DRCCore
import DRCPureSwift

@Suite("Pure Swift DRC backend")
struct PureSwiftDRCBackendTests {
    @Test func cleanLayoutPassesWithoutExternalTool() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            PureSwiftDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    PureSwiftDRCRectangle(id: "m1_a", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                    PureSwiftDRCRectangle(id: "m1_b", layer: "met1", xMin: 2, yMin: 0, xMax: 3, yMax: 1),
                ],
                rules: [
                    PureSwiftDRCRule(id: "met1.width", kind: .minimumWidth, layer: "met1", value: 0.5),
                    PureSwiftDRCRule(id: "met1.space", kind: .minimumSpacing, layer: "met1", value: 0.5),
                ]
            ),
            in: directory
        )

        let result = try await PureSwiftDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "pure-swift")
        ))

        #expect(result.result.passed)
        #expect(result.result.provenance?.executablePath == "in-process")
    }

    @Test func minimumWidthViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            PureSwiftDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    PureSwiftDRCRectangle(id: "thin", layer: "met1", xMin: 0, yMin: 0, xMax: 0.1, yMax: 1),
                ],
                rules: [
                    PureSwiftDRCRule(id: "met1.width", kind: .minimumWidth, layer: "met1", value: 0.5),
                ]
            ),
            in: directory
        )

        let result = try await PureSwiftDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "pure-swift")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        #expect(result.result.diagnostics[0].ruleID == "met1.width")
    }

    @Test func minimumSpacingViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            PureSwiftDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    PureSwiftDRCRectangle(id: "left", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                    PureSwiftDRCRectangle(id: "right", layer: "met1", xMin: 1.1, yMin: 0, xMax: 2.1, yMax: 1),
                ],
                rules: [
                    PureSwiftDRCRule(id: "met1.space", kind: .minimumSpacing, layer: "met1", value: 0.2),
                ]
            ),
            in: directory
        )

        let result = try await PureSwiftDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "pure-swift")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        #expect(result.result.diagnostics[0].ruleID == "met1.space")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PureSwiftDRCBackendTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeLayout(_ layout: PureSwiftDRCLayout, in directory: URL) throws -> URL {
        let url = directory.appending(path: "layout.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(layout)
        try data.write(to: url)
        return url
    }
}
