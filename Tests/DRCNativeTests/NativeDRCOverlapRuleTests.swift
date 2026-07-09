import Foundation
import Testing
import DRCCore
import DRCNative

@Suite("Native DRC overlap rules")
struct NativeDRCOverlapRuleTests {
    @Test func forbiddenOverlapViolationFails() async throws {
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
        let directory = try makeNativeDRCTemporaryDirectory()
        let layoutURL = try writeNativeDRCLayout(
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
}
