import Foundation
import Testing
import DRCCore
import DRCNative

@Suite("Native DRC basic rules")
struct NativeDRCBasicRuleTests {
    @Test func cleanLayoutPassesWithoutExternalTool() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "m1_a", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                    NativeDRCRectangle(id: "m1_b", layer: "met1", xMin: 2, yMin: 0, xMax: 3, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(id: "met1.grid", kind: .manufacturingGrid, layer: "met1", value: 0.001),
                    NativeDRCRule(id: "met1.width", kind: .minimumWidth, layer: "met1", value: 0.5),
                    NativeDRCRule(id: "met1.space", kind: .minimumSpacing, layer: "met1", value: 0.5),
                    NativeDRCRule(id: "met1.area", kind: .minimumArea, layer: "met1", value: 0.5),
                    NativeDRCRule(id: "met1.density", kind: .maximumDensity, layer: "met1", value: 1.0),
                    NativeDRCRule(id: "met1.notch", kind: .minimumNotch, layer: "met1", value: 0.5),
                    NativeDRCRule(id: "met1.antenna", kind: .maximumAntennaRatio, layer: "met1", value: 10),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(result.result.passed)
        #expect(result.result.provenance?.executablePath == "in-process")
    }

    @Test func manufacturingGridViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "offgrid",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1.015,
                        yMax: 1,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(id: "met1.grid", kind: .manufacturingGrid, layer: "met1", value: 0.01),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.grid")
        #expect(diagnostic.kind == "manufacturingGrid")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.005) < 0.000001)
        #expect(diagnostic.required == 0.01)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1.015, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["offgrid"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("coordinates=xMax"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumWidthViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "thin", layer: "met1", xMin: 0, yMin: 0, xMax: 0.1, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(id: "met1.width", kind: .minimumWidth, layer: "met1", value: 0.5),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.width")
        #expect(diagnostic.kind == "minimumWidth")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 0.1)
        #expect(diagnostic.required == 0.5)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 0.1, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["thin"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func maximumWidthViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "wide", layer: "met1", xMin: 0, yMin: 0, xMax: 3, yMax: 0.8),
                ],
                rules: [
                    NativeDRCRule(id: "met1.maxWidth", kind: .maximumWidth, layer: "met1", value: 2),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.maxWidth")
        #expect(diagnostic.kind == "maximumWidth")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 3)
        #expect(diagnostic.required == 2)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 3, height: 0.8))
        #expect(diagnostic.relatedShapeIDs == ["wide"])
        #expect(diagnostic.rawLine.contains("MAX_WIDTH"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func forbiddenLayerViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_not_m2_marker",
                        layer: "m1_not_m2_marker",
                        xMin: 0.25,
                        yMin: 0.5,
                        xMax: 1.25,
                        yMax: 1.5,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "m1_not_m2_marker.forbidden",
                        kind: .forbiddenLayer,
                        layer: "m1_not_m2_marker",
                        value: 0
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "m1_not_m2_marker.forbidden")
        #expect(diagnostic.kind == "forbiddenLayer")
        #expect(diagnostic.layer == "m1_not_m2_marker")
        #expect(diagnostic.measured == 1)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.unit == "shape")
        #expect(diagnostic.region == DRCRegion(x: 0.25, y: 0.5, width: 1, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["m1_not_m2_marker"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("FORBIDDEN_LAYER"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumAreaViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "small", layer: "met1", xMin: 0, yMin: 0, xMax: 0.4, yMax: 0.4),
                ],
                rules: [
                    NativeDRCRule(id: "met1.area", kind: .minimumArea, layer: "met1", value: 0.5),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.area")
        #expect(diagnostic.kind == "minimumArea")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.16) < 0.000001)
        #expect(diagnostic.required == 0.5)
        #expect(diagnostic.unit == "micrometer^2")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 0.4, height: 0.4))
        #expect(diagnostic.relatedShapeIDs == ["small"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func maximumDensityViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "dense", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.density",
                        kind: .maximumDensity,
                        layer: "met1",
                        value: 0.6,
                        windowWidth: 1,
                        windowHeight: 1
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.density")
        #expect(diagnostic.kind == "maximumDensity")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 1)
        #expect(diagnostic.required == 0.6)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["dense"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumDensityViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "sparse", layer: "met1", xMin: 0, yMin: 0, xMax: 0.25, yMax: 0.25),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.minimumDensity",
                        kind: .minimumDensity,
                        layer: "met1",
                        value: 0.2,
                        windowWidth: 1,
                        windowHeight: 1,
                        windowOriginX: 0,
                        windowOriginY: 0
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.minimumDensity")
        #expect(diagnostic.kind == "minimumDensity")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.0625) < 0.000001)
        #expect(diagnostic.required == 0.2)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["sparse"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumDensityViolationFailsForEmptyTargetLayerWithExplicitWindow() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "bounds", layer: "met2", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.minimumDensity",
                        kind: .minimumDensity,
                        layer: "met1",
                        value: 0.2,
                        windowWidth: 1,
                        windowHeight: 1,
                        windowOriginX: 0,
                        windowOriginY: 0
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.minimumDensity")
        #expect(diagnostic.kind == "minimumDensity")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 0)
        #expect(diagnostic.required == 0.2)
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1, height: 1))
        #expect(diagnostic.relatedShapeIDs.isEmpty)
    }

    @Test func minimumCutUnlabeledConductorOverlapWithoutCutsFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "lower", layer: "met1", xMin: 0, yMin: 0, xMax: 2, yMax: 2),
                    NativeDRCRectangle(id: "upper", layer: "met2", xMin: 0, yMin: 0, xMax: 2, yMax: 2),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.minimumCut",
                        kind: .minimumCut,
                        layer: "via1",
                        value: 1,
                        lowerLayer: "met1",
                        upperLayer: "met2"
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.kind == "minimumCut")
        #expect(diagnostic.measured == 0)
        #expect(diagnostic.required == 1)
        #expect(diagnostic.relatedShapeIDs == ["lower", "upper"])
        #expect(diagnostic.relatedNetIDs.isEmpty)
        #expect(diagnostic.rawLine.contains("net=unlabeled"))
    }

    @Test func minimumCutCountsUnlabeledCutForLabeledConductors() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "lower",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "upper",
                        layer: "met2",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(id: "cut", layer: "via1", xMin: 0.5, yMin: 0.5, xMax: 1, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.minimumCut",
                        kind: .minimumCut,
                        layer: "via1",
                        value: 1,
                        lowerLayer: "met1",
                        upperLayer: "met2"
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(result.result.passed)
        #expect(result.result.diagnostics.isEmpty)
    }
}
