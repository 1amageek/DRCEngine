import Foundation
import Testing
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech
@testable import DRCNative

/// The Native engine on STANDARD inputs: GDS geometry plus a
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

    private func writeExactOverlapTech(in root: URL) throws -> URL {
        let url = root.appending(path: "exact-overlap-tech.json")
        var tech = LayoutTechDatabase.sampleProcess()
        tech.exactOverlapRules = [
            LayoutExactOverlapRule(
                id: "exactOverlap.M1.M2",
                primaryLayer: LayoutLayerID(name: "M1", purpose: "drawing"),
                secondaryLayer: LayoutLayerID(name: "M2", purpose: "drawing")
            )
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(tech)).write(to: url)
        return url
    }

    private func writeAngleTech(in root: URL) throws -> URL {
        let url = root.appending(path: "angle-tech.json")
        var tech = LayoutTechDatabase.sampleProcess()
        tech.layerRules = tech.layerRules.map { rule in
            guard rule.layerID.name == "M1" else { return rule }
            var updated = rule
            updated.allowedAngleStepDegrees = 90
            return updated
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(tech)).write(to: url)
        return url
    }

    private func writePairSpacingTech(in root: URL) throws -> URL {
        let url = root.appending(path: "pair-spacing-tech.json")
        var tech = LayoutTechDatabase.sampleProcess()
        tech.spacingRules = [
            LayoutSpacingRule(
                id: "magicSpacing.M1.M2",
                primaryLayer: LayoutLayerID(name: "M1", purpose: "drawing"),
                secondaryLayer: LayoutLayerID(name: "M2", purpose: "drawing"),
                minSpacing: 0.2
            )
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(tech)).write(to: url)
        return url
    }

    private func writeEnclosedAreaTech(in root: URL) throws -> URL {
        let url = root.appending(path: "enclosed-area-tech.json")
        var tech = LayoutTechDatabase.sampleProcess()
        tech.layerRules = tech.layerRules.map { rule in
            guard rule.layerID.name == "M1" else { return rule }
            var updated = rule
            updated.minEnclosedArea = 0.1
            return updated
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(tech)).write(to: url)
        return url
    }

    private func forbiddenMarkerTech() -> LayoutTechDatabase {
        let marker = LayoutLayerID(name: "NWELL_MISSING", purpose: "marker")
        return LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.01,
            layers: [
                LayoutLayerDefinition(
                    id: marker,
                    displayName: "Nwell Missing Marker",
                    gdsLayer: 200,
                    gdsDatatype: 0,
                    color: LayoutColor(red: 1, green: 0, blue: 0),
                    fillPattern: .crosshatch
                )
            ],
            vias: [],
            layerRules: [],
            forbiddenLayerRules: [
                LayoutForbiddenLayerRule(
                    id: "forbiddenMarker.nwell_missing",
                    layer: marker,
                    reason: "Nwell missing marker"
                )
            ]
        )
    }

    private func writeForbiddenMarkerTech(in root: URL) throws -> URL {
        let url = root.appending(path: "forbidden-marker-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(forbiddenMarkerTech())).write(to: url)
        return url
    }

    private func derivedMIMTech() -> LayoutTechDatabase {
        let capm = LayoutLayerID(name: "CAPM", purpose: "drawing")
        let via3 = LayoutLayerID(name: "VIA3", purpose: "cut")
        let mimcc = LayoutLayerID(name: "MIMCC", purpose: "cut")
        return LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.01,
            layers: [
                LayoutLayerDefinition(
                    id: capm,
                    displayName: "MiM Capacitor Plate",
                    gdsLayer: 89,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.55, green: 0.35, blue: 0.85),
                    fillPattern: .forwardDiagonal
                ),
                LayoutLayerDefinition(
                    id: via3,
                    displayName: "Via3",
                    gdsLayer: 70,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.62, green: 0.62, blue: 0.62),
                    fillPattern: .crosshatch
                ),
            ],
            vias: [],
            layerRules: [
                LayoutLayerRuleSet(layerID: capm, minWidth: 0, minSpacing: 0, minArea: 0, minDensity: 0, maxDensity: 1),
                LayoutLayerRuleSet(layerID: via3, minWidth: 0, minSpacing: 0, minArea: 0, minDensity: 0, maxDensity: 1),
                LayoutLayerRuleSet(layerID: mimcc, minWidth: 0.3, minSpacing: 0, minArea: 0, minDensity: 0, maxDensity: 1),
            ],
            derivedLayerRules: [
                LayoutDerivedLayerRule(
                    id: "sky130.derived.MIMCC",
                    targetLayer: mimcc,
                    sourceLayers: [via3, capm],
                    operation: .intersection
                )
            ]
        )
    }

    private func writeDerivedMIMTech(in root: URL) throws -> URL {
        let url = root.appending(path: "derived-mim-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(derivedMIMTech())).write(to: url)
        return url
    }

    private func derivedDifferenceMarkerTech() -> LayoutTechDatabase {
        var tech = LayoutTechDatabase.sampleProcess()
        let marker = LayoutLayerID(name: "M1_NOT_M2", purpose: "marker")
        tech.derivedLayerRules = [
            LayoutDerivedLayerRule(
                id: "derived.M1_NOT_M2",
                targetLayer: marker,
                sourceLayers: [
                    LayoutLayerID(name: "M1", purpose: "drawing"),
                    LayoutLayerID(name: "M2", purpose: "drawing"),
                ],
                operation: .difference
            )
        ]
        tech.forbiddenLayerRules = [
            LayoutForbiddenLayerRule(
                id: "forbiddenMarker.m1_not_m2",
                layer: marker,
                reason: "M1 must be covered by M2"
            )
        ]
        return tech
    }

    private func writeDerivedDifferenceMarkerTech(in root: URL) throws -> URL {
        let url = root.appending(path: "derived-difference-marker-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(derivedDifferenceMarkerTech())).write(to: url)
        return url
    }

    private func derivedUnionMarkerTech() -> LayoutTechDatabase {
        var tech = LayoutTechDatabase.sampleProcess()
        let marker = LayoutLayerID(name: "M1_OR_M2", purpose: "marker")
        tech.derivedLayerRules = [
            LayoutDerivedLayerRule(
                id: "derived.M1_OR_M2",
                targetLayer: marker,
                sourceLayers: [
                    LayoutLayerID(name: "M1", purpose: "drawing"),
                    LayoutLayerID(name: "M2", purpose: "drawing"),
                ],
                operation: .union
            )
        ]
        tech.forbiddenLayerRules = [
            LayoutForbiddenLayerRule(
                id: "forbiddenMarker.m1_or_m2",
                layer: marker,
                reason: "Union marker must be empty"
            )
        ]
        return tech
    }

    private func derivedBloatAllMarkerTech() -> LayoutTechDatabase {
        let tap = LayoutLayerID(name: "NSC", purpose: "drawing")
        let nwell = LayoutLayerID(name: "NWELL", purpose: "drawing")
        let tappedNwell = LayoutLayerID(name: "NWELL_WITH_TAP", purpose: "derived")
        let marker = LayoutLayerID(name: "NWELL_MISSING_TAP", purpose: "marker")
        return LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.01,
            layers: [
                LayoutLayerDefinition(
                    id: tap,
                    displayName: "N Tap Contact",
                    gdsLayer: 93,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.2, green: 0.65, blue: 0.2),
                    fillPattern: .solid
                ),
                LayoutLayerDefinition(
                    id: nwell,
                    displayName: "Nwell",
                    gdsLayer: 64,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.25, green: 0.45, blue: 0.95),
                    fillPattern: .forwardDiagonal
                ),
            ],
            vias: [],
            layerRules: [],
            derivedLayerRules: [
                LayoutDerivedLayerRule(
                    id: "magic.templayer.nwell_with_tap",
                    targetLayer: tappedNwell,
                    sourceLayers: [tap, nwell],
                    operation: .bloatAll,
                    primarySourceLayerCount: 1
                ),
                LayoutDerivedLayerRule(
                    id: "magic.templayer.nwell_missing_tap",
                    targetLayer: marker,
                    sourceLayers: [nwell, tappedNwell],
                    operation: .difference
                ),
            ],
            forbiddenLayerRules: [
                LayoutForbiddenLayerRule(
                    id: "forbiddenMarker.nwell_missing_tap",
                    layer: marker,
                    reason: "Nwell must contain a tap"
                )
            ]
        )
    }

    private func derivedCellBoundaryMarkerTech() -> LayoutTechDatabase {
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        let abutmentBox = LayoutLayerID(name: "ABUTMENT_BOX", purpose: "derived")
        let marker = LayoutLayerID(name: "BBOX_MISSING", purpose: "marker")
        return LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.01,
            layers: [
                LayoutLayerDefinition(
                    id: poly,
                    displayName: "Poly",
                    gdsLayer: 66,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.8, green: 0.25, blue: 0.2),
                    fillPattern: .solid
                ),
            ],
            vias: [],
            layerRules: [],
            derivedLayerRules: [
                LayoutDerivedLayerRule(
                    id: "magic.templayer.abutment_box",
                    targetLayer: abutmentBox,
                    sourceLayers: [],
                    operation: .cellBoundary
                ),
                LayoutDerivedLayerRule(
                    id: "magic.templayer.bbox_missing",
                    targetLayer: marker,
                    sourceLayers: [poly, abutmentBox],
                    operation: .difference
                ),
            ],
            forbiddenLayerRules: [
                LayoutForbiddenLayerRule(
                    id: "forbiddenMarker.bbox_missing",
                    layer: marker,
                    reason: "Device must be inside a fixed cell bounding box"
                )
            ]
        )
    }

    private func writeDerivedUnionMarkerTech(in root: URL) throws -> URL {
        let url = root.appending(path: "derived-union-marker-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(derivedUnionMarkerTech())).write(to: url)
        return url
    }

    private func writeDerivedBloatAllMarkerTech(in root: URL) throws -> URL {
        let url = root.appending(path: "derived-bloat-all-marker-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(derivedBloatAllMarkerTech())).write(to: url)
        return url
    }

    private func writeDerivedCellBoundaryMarkerTech(in root: URL) throws -> URL {
        let url = root.appending(path: "derived-cell-boundary-marker-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(derivedCellBoundaryMarkerTech())).write(to: url)
        return url
    }

    private func writeLayout(
        shapes: [LayoutShape],
        cellName: String,
        format: LayoutFileFormat = .gds,
        fileExtension: String = "gds",
        exportTech: LayoutTechDatabase = LayoutTechDatabase.sampleProcess(),
        in root: URL
    ) throws -> URL {
        var cell = LayoutCell(name: cellName)
        cell.shapes = shapes
        let document = LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
        let url = root.appending(path: "\(cellName).\(fileExtension)")
        try MaskDataFormatConverter(tech: exportTech)
            .exportDocument(document, to: url, format: format)
        return url
    }

    private func writeNativeLayout(
        shapes: [LayoutShape],
        cellName: String,
        properties: [String: String] = [:],
        in root: URL
    ) throws -> URL {
        let cell = LayoutCell(name: cellName, shapes: shapes, properties: properties)
        let document = LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
        let url = root.appending(path: "\(cellName).json")
        try LayoutDocumentSerializer().encodeDocument(document).write(to: url)
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

    private func m2(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "M2", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func poly(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "POLY", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func forbiddenMarker(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "NWELL_MISSING", purpose: "marker"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func angledM1() -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "M1", purpose: "drawing"),
            geometry: .polygon(LayoutPolygon(points: [
                LayoutPoint(x: 0, y: 0),
                LayoutPoint(x: 2, y: 0),
                LayoutPoint(x: 3, y: 1),
                LayoutPoint(x: 0, y: 1),
            ]))
        )
    }

    private func capm(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "CAPM", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func capmPolygon() -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "CAPM", purpose: "drawing"),
            geometry: .polygon(LayoutPolygon(points: [
                LayoutPoint(x: 0, y: 0),
                LayoutPoint(x: 1, y: 0),
                LayoutPoint(x: 1, y: 0.4),
                LayoutPoint(x: 0.4, y: 0.4),
                LayoutPoint(x: 0.4, y: 1),
                LayoutPoint(x: 0, y: 1),
            ]))
        )
    }

    private func via3(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "VIA3", purpose: "cut"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func nwell(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "NWELL", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func dnwell(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "DNWELL", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func nsc(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> LayoutShape {
        LayoutShape(
            layer: LayoutLayerID(name: "NSC", purpose: "drawing"),
            geometry: .rect(LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: w, height: h)
            ))
        )
    }

    private func m1SmallHoleRing() -> [LayoutShape] {
        [
            m1(0, 0, 0.4, 1),
            m1(0.6, 0, 0.4, 1),
            m1(0.4, 0, 0.2, 0.4),
            m1(0.4, 0.6, 0.2, 0.4),
        ]
    }

    @Test func cleanLayoutPasses() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

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
        defer { removeTemporaryDirectory(root) }
        // Two M1 wires 0.1µm apart against sampleProcess's 0.23 rule.
        let gds = try writeLayout(
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
        #expect(execution.result.diagnostics.contains { $0.kind == "minSpacing" && $0.region != nil })
        let geometry = try #require(execution.repairHintGeometry)
        #expect(geometry.source == "standard-layout")
        #expect(geometry.topCell == "SPACING")
        #expect(geometry.rectangles.count == 2)

        let hints = DRCRepairHintBuilder().build(result: execution)
        let translation = try #require(hints.hints.first { $0.operationID == "layout.translate-shape" })
        let requiredSpacing = try #require(translation.required)
        let measuredSpacing = try #require(translation.measured)
        let missingSpacing = requiredSpacing - measuredSpacing
        #expect(translation.stringParameters["translationReason"] == "minimumSpacing")
        #expect(translation.stringParameters["translationAxis"] == "vertical")
        #expect(translation.numericParameters["deltaX"] == 0)
        #expect(abs((translation.numericParameters["deltaY"] ?? 1) + missingSpacing) < 0.000001)
        #expect(abs((translation.numericParameters["translationDistance"] ?? -1) - missingSpacing) < 0.000001)
        #expect(translation.verificationGates.contains("native-lvs"))
    }

    @Test func exactOverlapFaultFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: [m1(0, 0, 1.0, 1.0), m2(0, 0, 1.1, 1.0)],
            cellName: "EXACT_OVERLAP",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "EXACT_OVERLAP",
            technologyURL: try writeExactOverlapTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "exactOverlap" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "exactOverlap.M1.drawing.M2.drawing.exactOverlap.M1.M2")
        #expect(diagnostic.layer == "M1:drawing")
        #expect(abs((diagnostic.measured ?? 0) - 0.1) < 0.000001)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.region != nil)
    }

    @Test func forbiddenMarkerLayerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let tech = forbiddenMarkerTech()
        let gds = try writeLayout(
            shapes: [forbiddenMarker(0, 0, 1.0, 1.0)],
            cellName: "FORBIDDEN_MARKER",
            exportTech: tech,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "FORBIDDEN_MARKER",
            technologyURL: try writeForbiddenMarkerTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.NWELL_MISSING.marker.forbiddenMarker.nwell_missing")
        #expect(diagnostic.layer == "NWELL_MISSING:marker")
        #expect(diagnostic.measured == 1)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.region != nil)
    }

    @Test func angleFaultFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: [angledM1()],
            cellName: "ANGLE",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "ANGLE",
            technologyURL: try writeAngleTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "angle" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "layer.M1.drawing.angle")
        #expect(diagnostic.layer == "M1:drawing")
        #expect(diagnostic.measured == 45)
        #expect(diagnostic.required == 90)
        #expect(diagnostic.region != nil)
    }

    @Test func pairSpacingFaultFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: [m1(0, 0, 1.0, 0.3), m2(0, 0.4, 1.0, 0.3)],
            cellName: "PAIR_SPACING",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "PAIR_SPACING",
            technologyURL: try writePairSpacingTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first {
            $0.ruleID == "spacing.M1.drawing.M2.drawing.magicSpacing.M1.M2"
        })
        #expect(!execution.result.passed)
        #expect(diagnostic.kind == "minSpacing")
        #expect(diagnostic.layer == "M1:drawing")
        #expect(abs((diagnostic.measured ?? 0) - 0.1) < 0.000001)
        #expect(diagnostic.required == 0.2)
        #expect(diagnostic.region != nil)
    }

    @Test func derivedMIMContactLayerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let exportTech = derivedMIMTech()
        let gds = try writeLayout(
            shapes: [
                capm(0, 0, 1.0, 1.0),
                via3(0, 0, 0.2, 0.2),
            ],
            cellName: "DERIVED_MIM",
            exportTech: exportTech,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "DERIVED_MIM",
            technologyURL: try writeDerivedMIMTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first {
            $0.ruleID == "layer.MIMCC.cut.minWidth"
        })
        #expect(!execution.result.passed)
        #expect(diagnostic.kind == "minWidth")
        #expect(diagnostic.layer == "MIMCC:cut")
        #expect(abs((diagnostic.measured ?? 0) - 0.2) < 0.000001)
        #expect(diagnostic.required == 0.3)
        #expect(diagnostic.region != nil)
    }

    @Test func derivedMIMContactLayerSkipsNonRectangularSourceBounds() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let exportTech = derivedMIMTech()
        let gds = try writeLayout(
            shapes: [
                capmPolygon(),
                via3(0.6, 0.6, 0.2, 0.2),
            ],
            cellName: "DERIVED_MIM_NON_RECT",
            exportTech: exportTech,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "DERIVED_MIM_NON_RECT",
            technologyURL: try writeDerivedMIMTech(in: root),
            workingDirectory: root
        ))

        #expect(execution.result.passed)
        #expect(!execution.result.diagnostics.contains { $0.layer == "MIMCC:cut" })
    }

    @Test func derivedDifferenceMarkerLayerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: [
                m1(0, 0, 1.0, 1.0),
                m2(0.5, 0, 0.5, 1.0),
            ],
            cellName: "DERIVED_DIFFERENCE_MARKER",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "DERIVED_DIFFERENCE_MARKER",
            technologyURL: try writeDerivedDifferenceMarkerTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.M1_NOT_M2.marker.forbiddenMarker.m1_not_m2")
        #expect(diagnostic.layer == "M1_NOT_M2:marker")
        #expect(diagnostic.measured == 1)
        #expect(diagnostic.required == 0)
        #expect(abs((diagnostic.region?.width ?? 0) - 0.5) < 0.000001)
        #expect(abs((diagnostic.region?.height ?? 0) - 1.0) < 0.000001)
    }

    @Test func derivedUnionMarkerLayerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: [m2(0, 0, 1.0, 1.0)],
            cellName: "DERIVED_UNION_MARKER",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "DERIVED_UNION_MARKER",
            technologyURL: try writeDerivedUnionMarkerTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.M1_OR_M2.marker.forbiddenMarker.m1_or_m2")
        #expect(diagnostic.layer == "M1_OR_M2:marker")
        #expect(diagnostic.region != nil)
    }

    @Test func importedDirectBooleanTemplayerMarkerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )
        let imported = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer nwell_missing nwell
                and-not dnwell
            drc
              width dnwell 3000 "Deep nwell width"
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell must be covered by deep nwell"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )
        #expect(imported.report.status == .complete)
        #expect(imported.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        let technologyURL = root.appending(path: "imported-templayer-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(imported.technology)).write(to: technologyURL)
        let gds = try writeLayout(
            shapes: [nwell(0, 0, 1.0, 1.0)],
            cellName: "IMPORTED_TEMPLAYER_MARKER",
            exportTech: imported.technology,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "IMPORTED_TEMPLAYER_MARKER",
            technologyURL: technologyURL,
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.nwell_missing.marker.forbiddenMarker.nwell_missing")
        #expect(diagnostic.layer == "nwell_missing:marker")
        #expect(diagnostic.region != nil)
    }

    @Test func importedGrowShrinkTemplayerMarkerFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )
        let imported = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer dnwell_shrink dnwell
                shrink 1000
              templayer nwell_missing dnwell
                grow 400
                and-not dnwell_shrink
                and-not nwell
            drc
              width dnwell 3000 "Deep nwell width"
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell must include nwell coverage"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )
        #expect(imported.report.status == .complete)
        #expect(imported.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        let technologyURL = root.appending(path: "imported-grow-shrink-templayer-tech.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(imported.technology)).write(to: technologyURL)
        let gds = try writeLayout(
            shapes: [dnwell(0, 0, 3.0, 3.0)],
            cellName: "IMPORTED_GROW_SHRINK_TEMPLAYER_MARKER",
            exportTech: imported.technology,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "IMPORTED_GROW_SHRINK_TEMPLAYER_MARKER",
            technologyURL: technologyURL,
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.nwell_missing.marker.forbiddenMarker.nwell_missing")
        #expect(diagnostic.layer == "nwell_missing:marker")
        #expect(diagnostic.region != nil)
    }

    @Test func bloatAllDerivedMarkerFailsOnlyUntappedGuideIslandThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let tech = derivedBloatAllMarkerTech()
        let technologyURL = try writeDerivedBloatAllMarkerTech(in: root)
        let gds = try writeLayout(
            shapes: [
                nwell(0, 0, 1, 1),
                nsc(0.2, 0.2, 0.2, 0.2),
                nwell(2, 0, 1, 1),
            ],
            cellName: "BLOAT_ALL_MARKER",
            exportTech: tech,
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "BLOAT_ALL_MARKER",
            technologyURL: technologyURL,
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.NWELL_MISSING_TAP.marker.forbiddenMarker.nwell_missing_tap")
        #expect(diagnostic.layer == "NWELL_MISSING_TAP:marker")
        #expect(diagnostic.region?.x == 2)
        #expect(diagnostic.region?.width == 1)
    }

    @Test func cellBoundaryDerivedMarkerUsesFixedBBoxFromNativeLayoutInput() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let technologyURL = try writeDerivedCellBoundaryMarkerTech(in: root)
        let layoutURL = try writeNativeLayout(
            shapes: [poly(0, 0, 2, 1)],
            cellName: "CELL_BOUNDARY_MARKER",
            properties: ["FIXED_BBOX": "0 0 1 1"],
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "CELL_BOUNDARY_MARKER",
            layoutFormat: .nativeJSON,
            technologyURL: technologyURL,
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "forbiddenLayer" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "forbiddenLayer.BBOX_MISSING.marker.forbiddenMarker.bbox_missing")
        #expect(diagnostic.layer == "BBOX_MISSING:marker")
        #expect(diagnostic.region?.x == 1)
        #expect(diagnostic.region?.width == 1)
    }

    @Test func enclosedAreaFaultFailsThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(
            shapes: m1SmallHoleRing(),
            cellName: "ENCLOSED_AREA",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: gds,
            topCell: "ENCLOSED_AREA",
            technologyURL: try writeEnclosedAreaTech(in: root),
            workingDirectory: root
        ))

        let diagnostic = try #require(execution.result.diagnostics.first { $0.kind == "minEnclosedArea" })
        #expect(!execution.result.passed)
        #expect(diagnostic.ruleID == "layer.M1.drawing.minEnclosedArea")
        #expect(diagnostic.layer == "M1:drawing")
        #expect(abs((diagnostic.measured ?? 0) - 0.04) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.region != nil)
    }

    @Test func oasisLayoutPassesThroughStandardInputBackend() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let oasis = try writeLayout(
            shapes: [m1(0, 0, 2.0, 0.3)],
            cellName: "CLEAN_OASIS",
            format: .oasis,
            fileExtension: "oas",
            in: root
        )

        let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
            layoutURL: oasis,
            topCell: "CLEAN_OASIS",
            layoutFormat: .oasis,
            technologyURL: try writeTech(in: root),
            workingDirectory: root
        ))

        #expect(execution.result.passed)
        #expect(FileManager.default.fileExists(atPath: execution.result.logPath))
    }

    @Test func standardMaskFormatsProduceEquivalentViolations() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let technologyURL = try writeTech(in: root)
        let cases: [(String, LayoutFileFormat, DRCLayoutFormat, String)] = [
            ("GDS", .gds, .gds, "gds"),
            ("OASIS", .oasis, .oasis, "oas"),
            ("CIF", .cif, .cif, "cif"),
            ("DXF", .dxf, .dxf, "dxf"),
        ]

        for formatCase in cases {
            let layoutURL = try writeLayout(
                shapes: [
                    m1(0, 0, 2.0, 0.1),
                    m1(0, 0.2, 2.0, 0.1),
                ],
                cellName: "BAD_\(formatCase.0)",
                format: formatCase.1,
                fileExtension: formatCase.3,
                in: root
            )

            let execution = try await LayoutGDSDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "BAD_\(formatCase.0)",
                layoutFormat: formatCase.2,
                technologyURL: technologyURL,
                workingDirectory: root
            ))
            let stamps = Set(execution.result.diagnostics.map(DiagnosticStamp.init))

            #expect(!execution.result.passed, "\(formatCase.0) unexpectedly passed")
            #expect(stamps.contains(DiagnosticStamp(kind: "minWidth", layer: "M1:drawing")), "\(formatCase.0) missing minWidth")
            #expect(stamps.contains(DiagnosticStamp(kind: "minSpacing", layer: "M1:drawing")), "\(formatCase.0) missing minSpacing")
        }
    }

    @Test func missingTechnologyIsInvalidInput() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

        await #expect(throws: DRCError.self) {
            _ = try await LayoutGDSDRCBackend().run(DRCRequest(layoutURL: gds, topCell: "CLEAN"))
        }
    }

    @Test func wrongTopCellIsInvalidInput() async throws {
        let root = try makeRoot()
        defer { removeTemporaryDirectory(root) }
        let gds = try writeLayout(shapes: [m1(0, 0, 2.0, 0.3)], cellName: "CLEAN", in: root)

        await #expect(throws: DRCError.self) {
            _ = try await LayoutGDSDRCBackend().run(DRCRequest(
                layoutURL: gds,
                topCell: "NO_SUCH_CELL",
                technologyURL: try writeTech(in: root)
            ))
        }
    }

    private func removeTemporaryDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove temporary directory: \(error.localizedDescription)")
        }
    }

    private struct DiagnosticStamp: Hashable {
        let kind: String?
        let layer: String?

        init(kind: String?, layer: String?) {
            self.kind = kind
            self.layer = layer
        }

        init(_ diagnostic: DRCDiagnostic) {
            self.kind = diagnostic.kind
            self.layer = diagnostic.layer
        }
    }
}
