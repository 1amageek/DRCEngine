import Foundation
import Testing
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech
@testable import DRCPureSwift

/// The pure Swift engine on STANDARD inputs: GDS geometry plus a
/// LayoutTechDatabase JSON deck, judged by the same kernel the layout
/// editor uses. Fixtures are generated in code — no binary blobs.
@Suite("Layout GDS DRC backend", .timeLimit(.minutes(2)))
struct LayoutGDSDRCBackendTests {

    private func makeRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "gds-drc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeTech(in root: URL) throws -> URL {
        let url = root.appending(path: "tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(LayoutTechDatabase.sampleProcess())).write(to: url)
        return url
    }

    private func writeGDS(shapes: [LayoutShape], cellName: String, in root: URL) throws -> URL {
        var cell = LayoutCell(name: cellName)
        cell.shapes = shapes
        let document = LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
        let url = root.appending(path: "\(cellName).gds")
        try GDSFormatConverter(tech: LayoutTechDatabase.sampleProcess())
            .exportDocument(document, to: url, format: .gds)
        return url
    }

    private func m1(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "M1", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    @Test func cleanLayoutPasses() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let gds = try writeGDS(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "CLEAN",
            technologyURL: try writeTech(in: root),
            workingDirectory: root
        ))
        #expect(execution.result.passed)
        #expect(execution.result.diagnostics.isEmpty)
        #expect(FileManager.default.fileExists(atPath: execution.result.logPath))
    }

    @Test func spacingFaultFails() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // Two M1 wires 0.1µm apart against sampleProcess's 0.23 rule.
        let gds = try writeGDS(
            shapes: [m1(0, 0, 2.0, 0.3), m1(0, 0.4, 2.0, 0.3)],
            cellName: "SPACING",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "SPACING",
            technologyURL: try writeTech(in: root)
        ))
        #expect(!execution.result.passed)
        #expect(execution.result.diagnostics.contains { $0.ruleID?.contains("minSpacing") == true })
    }

    @Test func missingTechnologyIsInvalidInput() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let gds = try writeGDS(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

        await #expect(throws: DRCError.self) {
            _ = try await LayoutGDSDRCBackend().run(DRCRequest(layoutURL: gds, topCell: "CLEAN"))
        }
    }

    @Test func wrongTopCellIsInvalidInput() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let gds = try writeGDS(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

        await #expect(throws: DRCError.self) {
            _ = try await LayoutGDSDRCBackend().run(DRCRequest(
                layoutURL: gds,
                topCell: "NO_SUCH_CELL",
                technologyURL: try writeTech(in: root)
            ))
        }
    }
}
