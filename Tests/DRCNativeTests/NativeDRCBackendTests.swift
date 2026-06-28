import Foundation
import Testing
import DRCCore
import DRCNative

@Suite("Native DRC backend")
struct NativeDRCBackendTests {
    @Test func cleanLayoutPassesWithoutExternalTool() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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

    @Test func minimumAreaViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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

    @Test func forbiddenOverlapViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "active",
                        layer: "active",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "source"
                    ),
                    NativeDRCRectangle(
                        id: "nwell",
                        layer: "nwell",
                        xMin: 1.5,
                        yMin: 0.25,
                        xMax: 2.5,
                        yMax: 0.75,
                        netID: "bulk"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "active.nwell.forbiddenOverlap",
                        kind: .forbiddenOverlap,
                        layer: "active",
                        value: 0,
                        secondaryLayer: "nwell"
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
        #expect(diagnostic.ruleID == "active.nwell.forbiddenOverlap")
        #expect(diagnostic.kind == "forbiddenOverlap")
        #expect(diagnostic.layer == "active,nwell")
        #expect(abs((diagnostic.measured ?? 0) - 0.25) < 0.000001)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.unit == "micrometer^2")
        #expect(diagnostic.region == DRCRegion(x: 1.5, y: 0.25, width: 0.5, height: 0.5))
        #expect(diagnostic.relatedShapeIDs == ["active", "nwell"])
        #expect(diagnostic.relatedNetIDs == ["bulk", "source"])
        #expect(diagnostic.rawLine.contains("FORBIDDEN_OVERLAP"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func forbiddenOverlapThresholdAllowsBoundedOverlap() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "active",
                        layer: "active",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1
                    ),
                    NativeDRCRectangle(
                        id: "nwell",
                        layer: "nwell",
                        xMin: 1.5,
                        yMin: 0.25,
                        xMax: 2.5,
                        yMax: 0.75
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "active.nwell.forbiddenOverlap",
                        kind: .forbiddenOverlap,
                        layer: "active",
                        value: 0.25,
                        secondaryLayer: "nwell"
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

    @Test func forbiddenOverlapRequiresSecondaryLayer() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "active",
                        layer: "active",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "active.nwell.forbiddenOverlap",
                        kind: .forbiddenOverlap,
                        layer: "active",
                        value: 0
                    ),
                ]
            ),
            in: directory
        )

        var didThrowExpectedError = false
        do {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        } catch let error as DRCError {
            didThrowExpectedError = error == .invalidInput("Rule active.nwell.forbiddenOverlap requires secondaryLayer for forbiddenOverlap")
        } catch {
            throw error
        }

        #expect(didThrowExpectedError)
    }

    @Test func differentNetOverlapViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "sig",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "clk",
                        layer: "met1",
                        xMin: 1.25,
                        yMin: 0.25,
                        xMax: 2.25,
                        yMax: 0.75,
                        netID: "clk"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.short",
                        kind: .differentNetOverlap,
                        layer: "met1",
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
        #expect(diagnostic.ruleID == "met1.short")
        #expect(diagnostic.kind == "differentNetOverlap")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.375) < 0.000001)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.unit == "micrometer^2")
        #expect(diagnostic.region == DRCRegion(x: 1.25, y: 0.25, width: 0.75, height: 0.5))
        #expect(diagnostic.relatedShapeIDs == ["sig", "clk"])
        #expect(diagnostic.relatedNetIDs == ["clk", "sig"])
        #expect(diagnostic.rawLine.contains("DIFFERENT_NET_OVERLAP"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func differentNetOverlapIgnoresSameNetAndUnassignedShapes() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "sig-a",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "sig-b",
                        layer: "met1",
                        xMin: 1,
                        yMin: 0.25,
                        xMax: 2.25,
                        yMax: 0.75,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "unassigned",
                        layer: "met1",
                        xMin: 1.25,
                        yMin: 0.5,
                        xMax: 2.5,
                        yMax: 1.25
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.short",
                        kind: .differentNetOverlap,
                        layer: "met1",
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

        #expect(result.result.passed)
        #expect(result.result.diagnostics.isEmpty)
    }

    @Test func exactOverlapViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 0.2,
                        yMax: 0.2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "marker",
                        layer: "via1_marker",
                        xMin: 0,
                        yMin: 0,
                        xMax: 0.25,
                        yMax: 0.2,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.marker.exactOverlap",
                        kind: .exactOverlap,
                        layer: "via1",
                        value: 0,
                        secondaryLayer: "via1_marker"
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
        #expect(diagnostic.ruleID == "via1.marker.exactOverlap")
        #expect(diagnostic.kind == "exactOverlap")
        #expect(diagnostic.layer == "via1,via1_marker")
        #expect(abs((diagnostic.measured ?? 0) - 0.05) < 0.000001)
        #expect(diagnostic.required == 0)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 0.2, height: 0.2))
        #expect(diagnostic.relatedShapeIDs == ["via1", "marker"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("EXACT_OVERLAP"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func exactOverlapPassesWithMatchingSecondaryRectangle() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 0.2,
                        yMax: 0.2
                    ),
                    NativeDRCRectangle(
                        id: "marker",
                        layer: "via1_marker",
                        xMin: 0,
                        yMin: 0,
                        xMax: 0.2,
                        yMax: 0.2
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.marker.exactOverlap",
                        kind: .exactOverlap,
                        layer: "via1",
                        value: 0,
                        secondaryLayer: "via1_marker"
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

    @Test func exactOverlapRequiresSecondaryLayer() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 0.2,
                        yMax: 0.2
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.marker.exactOverlap",
                        kind: .exactOverlap,
                        layer: "via1",
                        value: 0
                    ),
                ]
            ),
            in: directory
        )

        var didThrowExpectedError = false
        do {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        } catch let error as DRCError {
            didThrowExpectedError = error == .invalidInput("Rule via1.marker.exactOverlap requires secondaryLayer for exactOverlap")
        } catch {
            throw error
        }

        #expect(didThrowExpectedError)
    }

    @Test func maximumDensityViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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

    @Test func maximumAntennaRatioViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 6,
                        yMax: 2,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 3,
                        xMax: 1,
                        yMax: 4,
                        netID: "out",
                        antennaGateArea: 1.5
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 5,
                        gateLayer: "poly"
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
        #expect(diagnostic.ruleID == "met1.antenna")
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 8)
        #expect(diagnostic.required == 5)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 6, height: 2))
        #expect(diagnostic.relatedShapeIDs == ["wire", "gate"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func maximumAntennaRatioAccumulatesConfiguredLayers() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 2,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "m2_wire",
                        layer: "met2",
                        xMin: 3,
                        yMin: 0,
                        xMax: 8,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 3,
                        xMax: 1,
                        yMax: 4,
                        netID: "out",
                        antennaGateArea: 1.5
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met2.antenna",
                        kind: .maximumAntennaRatio,
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"]
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
        #expect(diagnostic.ruleID == "met2.antenna")
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.layer == "met2")
        #expect(diagnostic.measured == 6)
        #expect(diagnostic.required == 5)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 8, height: 2))
        #expect(diagnostic.relatedShapeIDs == ["m1_wire", "m2_wire", "gate"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func maximumAntennaRatioFiltersConductorsByProcessStep() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "out",
                        antennaProcessStep: "m1"
                    ),
                    NativeDRCRectangle(
                        id: "m2_late_wire",
                        layer: "met2",
                        xMin: 0,
                        yMin: 2,
                        xMax: 20,
                        yMax: 7,
                        netID: "out",
                        antennaProcessStep: "m2"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 8,
                        xMax: 1,
                        yMax: 9,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.processStep",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"],
                        processStep: "m1"
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

    @Test func maximumAntennaRatioReportsProcessStepViolation() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 8,
                        yMax: 1,
                        netID: "out",
                        antennaProcessStep: "m1"
                    ),
                    NativeDRCRectangle(
                        id: "m2_late_wire",
                        layer: "met2",
                        xMin: 0,
                        yMin: 2,
                        xMax: 20,
                        yMax: 7,
                        netID: "out",
                        antennaProcessStep: "m2"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 8,
                        xMax: 1,
                        yMax: 9,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.processStep",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"],
                        processStep: "m1"
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
        #expect(diagnostic.ruleID == "met1.antenna.processStep")
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 8)
        #expect(diagnostic.required == 5)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.relatedShapeIDs == ["m1_wire", "gate"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.message.contains("process step m1"))
        #expect(diagnostic.rawLine.contains("step=m1"))
        #expect(diagnostic.suggestedFix?.contains("process step m1") == true)
    }

    @Test func maximumAntennaRatioRequiresCutPathForConfiguredCutConnections() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 8,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "m2_wire",
                        layer: "met2",
                        xMin: 0,
                        yMin: 2,
                        xMax: 20,
                        yMax: 7,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 8,
                        xMax: 1,
                        yMax: 9,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met2.antenna.viaAware",
                        kind: .maximumAntennaRatio,
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"],
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ]
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

    @Test func maximumAntennaRatioIgnoresNonOverlappingCutStack() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "floating_contact",
                        layer: "contact",
                        xMin: 5,
                        yMin: 5,
                        xMax: 5.2,
                        yMax: 5.2,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "floating_via1",
                        layer: "via1",
                        xMin: 6,
                        yMin: 5,
                        xMax: 6.2,
                        yMax: 5.2,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "m2_wire",
                        layer: "met2",
                        xMin: 1.5,
                        yMin: 0,
                        xMax: 7.5,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met2.antenna.viaAware",
                        kind: .maximumAntennaRatio,
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"],
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ]
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

    @Test func maximumAntennaRatioReportsCutConnectedViolation() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "contact",
                        layer: "contact",
                        xMin: 0.25,
                        yMin: 0.25,
                        xMax: 0.5,
                        yMax: 0.5,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 1.5,
                        yMin: 0.25,
                        xMax: 1.75,
                        yMax: 0.5,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "m2_wire",
                        layer: "met2",
                        xMin: 1.5,
                        yMin: 0,
                        xMax: 7.5,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met2.antenna.viaAware",
                        kind: .maximumAntennaRatio,
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        conductorLayers: ["met1", "met2"],
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ]
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
        #expect(diagnostic.ruleID == "met2.antenna.viaAware")
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.layer == "met2")
        #expect(diagnostic.measured == 8)
        #expect(diagnostic.required == 5)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.relatedShapeIDs == ["m1_wire", "m2_wire", "contact", "via1", "gate"])
        #expect(diagnostic.relatedViaIDs == ["contact", "via1"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.message.contains("through contact,via1"))
        #expect(diagnostic.rawLine.contains("cuts=contact,via1"))
        #expect(diagnostic.suggestedFix?.contains("cut stack") == true)
    }

    @Test func minimumNotchViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "left", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 3),
                    NativeDRCRectangle(id: "right", layer: "met1", xMin: 1.2, yMin: 0, xMax: 2.2, yMax: 3),
                    NativeDRCRectangle(id: "bridge", layer: "met1", xMin: 0, yMin: 2, xMax: 2.2, yMax: 3),
                ],
                rules: [
                    NativeDRCRule(id: "met1.notch", kind: .minimumNotch, layer: "met1", value: 0.5),
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
        #expect(diagnostic.ruleID == "met1.notch")
        #expect(diagnostic.kind == "minimumNotch")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.2) < 0.000001)
        #expect(diagnostic.required == 0.5)
        #expect(diagnostic.unit == "micrometer")
        let region = try #require(diagnostic.region)
        #expect(region.x == 1)
        #expect(region.y == 0)
        #expect(abs(region.width - 0.2) < 0.000001)
        #expect(region.height == 2)
        #expect(diagnostic.relatedShapeIDs == ["left", "right", "bridge"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumSpacingViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "left", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                    NativeDRCRectangle(id: "right", layer: "met1", xMin: 1.1, yMin: 0, xMax: 2.1, yMax: 1),
                ],
                rules: [
                    NativeDRCRule(id: "met1.space", kind: .minimumSpacing, layer: "met1", value: 0.2),
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
        #expect(diagnostic.ruleID == "met1.space")
        #expect(diagnostic.kind == "minimumSpacing")
        #expect(diagnostic.layer == "met1")
        #expect(diagnostic.measured == 0.10000000000000009)
        #expect(diagnostic.required == 0.2)
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 2.1, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["left", "right"])
    }

    @Test func minimumSpacingDifferentNetScopeIgnoresSameNetPairs() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "same-left",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "same-right",
                        layer: "met1",
                        xMin: 1.1,
                        yMin: 0,
                        xMax: 2.1,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "diff-left",
                        layer: "met1",
                        xMin: 10,
                        yMin: 0,
                        xMax: 11,
                        yMax: 1,
                        netID: "sig_a"
                    ),
                    NativeDRCRectangle(
                        id: "diff-right",
                        layer: "met1",
                        xMin: 11.1,
                        yMin: 0,
                        xMax: 12.1,
                        yMax: 1,
                        netID: "sig_b"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.space.diffnet",
                        kind: .minimumSpacing,
                        layer: "met1",
                        value: 0.2,
                        spacingNetScope: .differentNet
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
        #expect(diagnostic.ruleID == "met1.space.diffnet")
        #expect(diagnostic.relatedShapeIDs == ["diff-left", "diff-right"])
        #expect(diagnostic.rawLine.contains("netScope=differentNet"))
    }

    @Test func minimumSpacingSameNetScopeIgnoresDifferentNetPairs() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "same-left",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "same-right",
                        layer: "met1",
                        xMin: 1.1,
                        yMin: 0,
                        xMax: 2.1,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "diff-left",
                        layer: "met1",
                        xMin: 10,
                        yMin: 0,
                        xMax: 11,
                        yMax: 1,
                        netID: "sig_a"
                    ),
                    NativeDRCRectangle(
                        id: "diff-right",
                        layer: "met1",
                        xMin: 11.1,
                        yMin: 0,
                        xMax: 12.1,
                        yMax: 1,
                        netID: "sig_b"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.space.samenet",
                        kind: .minimumSpacing,
                        layer: "met1",
                        value: 0.2,
                        spacingNetScope: .sameNet
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
        #expect(diagnostic.ruleID == "met1.space.samenet")
        #expect(diagnostic.relatedShapeIDs == ["same-left", "same-right"])
        #expect(diagnostic.rawLine.contains("netScope=sameNet"))
    }

    @Test func minimumSpacingSecondaryLayerViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "metal",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "cut",
                        layer: "via1",
                        xMin: 1.1,
                        yMin: 0,
                        xMax: 2.1,
                        yMax: 1,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.via1.spacing",
                        kind: .minimumSpacing,
                        layer: "met1",
                        value: 0.2,
                        secondaryLayer: "via1"
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
        #expect(diagnostic.ruleID == "met1.via1.spacing")
        #expect(diagnostic.kind == "minimumSpacing")
        #expect(diagnostic.layer == "met1,via1")
        #expect(diagnostic.relatedShapeIDs == ["metal", "cut"])
        #expect(diagnostic.rawLine.contains("layers=met1,via1"))
    }

    @Test func minimumEndOfLineSpacingViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "wire",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 3,
                        yMax: 0.2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "blocker",
                        layer: "met1",
                        xMin: 3.1,
                        yMin: 0,
                        xMax: 4,
                        yMax: 1,
                        netID: "sig2"
                    ),
                    NativeDRCRectangle(
                        id: "side-clear",
                        layer: "met1",
                        xMin: 1,
                        yMin: 0.5,
                        xMax: 2,
                        yMax: 0.7,
                        netID: "sig3"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.eol",
                        kind: .minimumEndOfLineSpacing,
                        layer: "met1",
                        value: 0.3,
                        spacingNetScope: .differentNet,
                        endOfLineWidth: 0.25
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
        #expect(diagnostic.ruleID == "met1.eol")
        #expect(diagnostic.kind == "minimumEndOfLineSpacing")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.1) < 0.000001)
        #expect(diagnostic.required == 0.3)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.relatedShapeIDs == ["wire", "blocker"])
        #expect(diagnostic.relatedNetIDs == ["sig", "sig2"])
        #expect(diagnostic.rawLine.contains("edge=wire:right"))
        #expect(diagnostic.rawLine.contains("netScope=differentNet"))
    }

    @Test func minimumSpacingParallelRunLengthViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "left",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 3,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "right",
                        layer: "met1",
                        xMin: 1.1,
                        yMin: 0,
                        xMax: 2.1,
                        yMax: 3,
                        netID: "sig2"
                    ),
                    NativeDRCRectangle(
                        id: "short",
                        layer: "met1",
                        xMin: 0,
                        yMin: 4,
                        xMax: 1,
                        yMax: 4.5,
                        netID: "sig3"
                    ),
                    NativeDRCRectangle(
                        id: "short-near",
                        layer: "met1",
                        xMin: 1.05,
                        yMin: 4,
                        xMax: 2,
                        yMax: 4.5,
                        netID: "sig4"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.spacing.prl",
                        kind: .minimumSpacing,
                        layer: "met1",
                        value: 0.2,
                        spacingNetScope: .differentNet,
                        spacingDirection: .horizontal,
                        minimumParallelRunLength: 2
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
        #expect(diagnostic.ruleID == "met1.spacing.prl")
        #expect(diagnostic.kind == "minimumSpacing")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.1) < 0.000001)
        #expect(diagnostic.required == 0.2)
        #expect(diagnostic.relatedShapeIDs == ["left", "right"])
        #expect(diagnostic.rawLine.contains("direction=horizontal"))
        #expect(diagnostic.rawLine.contains("minPRL=2.0"))
    }

    @Test func wideMinimumSpacingOnlyAppliesNextToWideGeometry() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "wide_metal",
                rectangles: [
                    NativeDRCRectangle(
                        id: "wide",
                        layer: "met1",
                        xMin: 0,
                        yMin: 0,
                        xMax: 1,
                        yMax: 2,
                        netID: "vdd"
                    ),
                    NativeDRCRectangle(
                        id: "near_wide",
                        layer: "met1",
                        xMin: 1.3,
                        yMin: 0,
                        xMax: 1.5,
                        yMax: 2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "narrow_a",
                        layer: "met1",
                        xMin: 4,
                        yMin: 0,
                        xMax: 4.2,
                        yMax: 2,
                        netID: "a"
                    ),
                    NativeDRCRectangle(
                        id: "narrow_b",
                        layer: "met1",
                        xMin: 4.5,
                        yMin: 0,
                        xMax: 4.7,
                        yMax: 2,
                        netID: "b"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.wideSpacing",
                        kind: .minimumSpacing,
                        layer: "met1",
                        value: 0.5,
                        spacingNetScope: .differentNet,
                        wideWidthThreshold: 0.8
                    ),
                ]
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "wide_metal",
            backendSelection: DRCBackendSelection(backendID: "native")
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "met1.wideSpacing")
        #expect(diagnostic.kind == "minimumSpacing")
        #expect(diagnostic.relatedShapeIDs == ["wide", "near_wide"])
        #expect(abs((diagnostic.measured ?? 0) - 0.3) < 0.000001)
        #expect(diagnostic.required == 0.5)
        #expect(diagnostic.rawLine.contains("wideWidthThreshold=0.8"))
    }

    @Test func minimumCutViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
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
                    NativeDRCRectangle(
                        id: "cut-a",
                        layer: "via1",
                        xMin: 0.5,
                        yMin: 0.5,
                        xMax: 1,
                        yMax: 1,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "via1.minimumCut",
                        kind: .minimumCut,
                        layer: "via1",
                        value: 2,
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
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "via1.minimumCut")
        #expect(diagnostic.kind == "minimumCut")
        #expect(diagnostic.layer == "via1")
        #expect(diagnostic.measured == 1)
        #expect(diagnostic.required == 2)
        #expect(diagnostic.unit == "cut")
        #expect(diagnostic.relatedShapeIDs == ["lower", "upper", "cut-a"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.relatedViaIDs == ["cut-a"])
        #expect(diagnostic.rawLine.contains("lowerLayer=met1"))
        #expect(diagnostic.rawLine.contains("upperLayer=met2"))
    }

    @Test func minimumEnclosureViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "m1_cover", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 1),
                    NativeDRCRectangle(id: "via1_bad", layer: "via1", xMin: 0.4, yMin: 0.4, xMax: 1.2, yMax: 0.6),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.via1.enclosure",
                        kind: .minimumEnclosure,
                        layer: "met1",
                        value: 0.1,
                        enclosedLayer: "via1"
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
        #expect(diagnostic.ruleID == "met1.via1.enclosure")
        #expect(diagnostic.kind == "minimumEnclosure")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - -0.2) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1.2, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["via1_bad", "m1_cover"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumExtensionViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "active",
                        layer: "active",
                        xMin: 1,
                        yMin: 0,
                        xMax: 2,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "poly",
                        layer: "poly",
                        xMin: 0.95,
                        yMin: 0,
                        xMax: 2.08,
                        yMax: 1,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "poly.active.extension",
                        kind: .minimumExtension,
                        layer: "poly",
                        value: 0.1,
                        enclosedLayer: "active",
                        extensionDirection: .horizontal
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
        #expect(diagnostic.ruleID == "poly.active.extension")
        #expect(diagnostic.kind == "minimumExtension")
        #expect(diagnostic.layer == "poly")
        #expect(abs((diagnostic.measured ?? 0) - 0.05) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.unit == "micrometer")
        #expect(diagnostic.region?.x == 0.95)
        #expect(diagnostic.region?.y == 0)
        #expect(abs((diagnostic.region?.width ?? 0) - 1.13) < 0.000001)
        #expect(diagnostic.region?.height == 1)
        #expect(diagnostic.relatedShapeIDs == ["active", "poly"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("direction=horizontal"))
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumEnclosedAreaViolationFails() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "left", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 3),
                    NativeDRCRectangle(id: "right", layer: "met1", xMin: 1.2, yMin: 0, xMax: 2.2, yMax: 3),
                    NativeDRCRectangle(id: "bottom", layer: "met1", xMin: 0, yMin: 0, xMax: 2.2, yMax: 1),
                    NativeDRCRectangle(id: "top", layer: "met1", xMin: 0, yMin: 1.2, xMax: 2.2, yMax: 3),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.enclosedArea",
                        kind: .minimumEnclosedArea,
                        layer: "met1",
                        value: 0.1
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
        #expect(diagnostic.ruleID == "met1.enclosedArea")
        #expect(diagnostic.kind == "minimumEnclosedArea")
        #expect(diagnostic.layer == "met1")
        #expect(abs((diagnostic.measured ?? 0) - 0.04) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.unit == "micrometer^2")
        let region = try #require(diagnostic.region)
        #expect(abs(region.x - 1) < 0.000001)
        #expect(abs(region.y - 1) < 0.000001)
        #expect(abs(region.width - 0.2) < 0.000001)
        #expect(abs(region.height - 0.2) < 0.000001)
        #expect(diagnostic.relatedShapeIDs == ["bottom", "left", "right", "top"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func minimumEnclosedAreaIgnoresExteriorOpenings() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "left", layer: "met1", xMin: 0, yMin: 0, xMax: 1, yMax: 3),
                    NativeDRCRectangle(id: "right", layer: "met1", xMin: 1.2, yMin: 0, xMax: 2.2, yMax: 3),
                    NativeDRCRectangle(id: "top", layer: "met1", xMin: 0, yMin: 1.2, xMax: 2.2, yMax: 3),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.enclosedArea",
                        kind: .minimumEnclosedArea,
                        layer: "met1",
                        value: 0.1
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

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NativeDRCBackendTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeLayout(_ layout: NativeDRCLayout, in directory: URL) throws -> URL {
        let url = directory.appending(path: "layout.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(layout)
        try data.write(to: url)
        return url
    }
}
