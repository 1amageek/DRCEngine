import Foundation
import Testing
import DRCCore
import DRCNative

@Suite("Native DRC backend")
struct NativeDRCBackendTests {
    @Test func scalarAntennaRuleIsRejected() async throws {
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
                        xMax: 1,
                        yMax: 1
                    ),
                ],
                rules: [NativeDRCRule(
                    id: "met1.antenna",
                    kind: .maximumAntennaRatio,
                    layer: "met1",
                    value: 10
                )]
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC antenna rule met1.antenna requires antennaModel and antennaLayers."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        }
    }

    @Test func invalidRectangleGeometryIsRejectedBeforeRuleEvaluation() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "wire",
                        layer: "met1",
                        xMin: 1,
                        yMin: 0,
                        xMax: 1,
                        yMax: 1
                    ),
                ],
                rules: [NativeDRCRule(
                    id: "met1.width",
                    kind: .minimumWidth,
                    layer: "met1",
                    value: 0.5
                )]
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC rectangle wire must have finite coordinates and positive dimensions."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        }
    }

    @Test func duplicateRuleIDsAreRejectedBeforeDiagnosticsAreProduced() async throws {
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
                        xMax: 1,
                        yMax: 1
                    ),
                ],
                rules: [
                    NativeDRCRule(id: "duplicate", kind: .minimumWidth, layer: "met1", value: 0.5),
                    NativeDRCRule(id: "duplicate", kind: .minimumArea, layer: "met1", value: 0.5),
                ]
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC rule ID is duplicated: duplicate."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        }
    }

    @Test func emptyRuleDeckIsInvalidInput() async throws {
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
                        xMax: 1,
                        yMax: 1
                    ),
                ],
                rules: []
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC rule deck is empty for technology unit-test-tech. Provide at least one physical rule."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native")
            ))
        }
    }

    @Test func antennaReadinessGateRejectsEmbeddedDeckWithoutAntennaRule() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [NativeDRCRectangle(
                    id: "wire",
                    layer: "met1",
                    xMin: 0,
                    yMin: 0,
                    xMax: 1,
                    yMax: 1
                )],
                rules: [NativeDRCRule(
                    id: "met1.width",
                    kind: .minimumWidth,
                    layer: "met1",
                    value: 0.1
                )]
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC antenna readiness is not established for technology unit-test-tech: the rule deck contains no maximumAntennaRatio rule."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native"),
                options: DRCOptions(requireAntennaRules: true)
            ))
        }
    }

    @Test func antennaReadinessGateRejectsMissingAnnotationCompleteness() async throws {
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
                        xMax: 2,
                        yMax: 1,
                        netID: "out"
                    ),
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "poly",
                        xMin: 0,
                        yMin: 2,
                        xMax: 1,
                        yMax: 3,
                        netID: "out",
                        antennaGateArea: 1
                    ),
                ],
                rules: [NativeDRCRule(
                    id: "met1.antenna",
                    kind: .maximumAntennaRatio,
                    layer: "met1",
                    value: 10,
                    gateLayer: "poly",
                    antennaModel: .partial,
                    antennaLayers: [NativeDRCAntennaLayer(
                        layer: "met1",
                        measurement: .surface,
                        ratioGate: 10
                    )]
                )]
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC antenna readiness is not established for technology unit-test-tech: antennaMetadata is missing."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native"),
                options: DRCOptions(requireAntennaRules: true)
            ))
        }
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
                        gateLayer: "poly",
                        antennaModel: .partial,
                        antennaLayers: [NativeDRCAntennaLayer(
                            layer: "met1",
                            measurement: .surface,
                            ratioGate: 5
                        )]
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
        #expect(result.provenance.producer.identifier == "layout-verify")
        #expect(result.provenance.producer.version == DRCExecutionProvenance.nativeImplementationVersion)
        #expect(result.provenance.producer.build?.count == 64)
        #expect(result.provenance.inputs.count == 1)
        #expect(result.provenance.inputs[0].byteCount > 0)
        #expect(result.provenance.invocation?.entryPoint == "NativeDRCBackend.run")
        #expect(result.provenance.environment != nil)
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
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
        #expect(diagnostic.ruleID == "met2.antenna")
        #expect(diagnostic.kind == "maximumAntennaEffectiveRatio")
        #expect(diagnostic.layer == "met2")
        #expect(abs((diagnostic.measured ?? 0) - 1.2) < 0.000001)
        #expect(diagnostic.required == 1)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 8, height: 2))
        #expect(diagnostic.relatedShapeIDs == ["m1_wire", "m2_wire", "gate"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.suggestedFix != nil)
    }

    @Test func detailedSurfaceAntennaUsesPerLayerRatioGate() async throws {
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
                        xMax: 10,
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
                        antennaGateArea: 2
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.detailed",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 5,
                        gateLayer: "poly",
                        antennaModel: .partial,
                        antennaLayers: [NativeDRCAntennaLayer(
                            layer: "met1",
                            measurement: .surface,
                            ratioGate: 5
                        )]
                    ),
                ],
                antennaMetadata: NativeDRCAntennaMetadata(
                    gateAreasComplete: true,
                    diffusionAreasComplete: true,
                    processStepsComplete: true,
                    cutConnectivityComplete: true,
                    source: "unit-test"
                )
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native"),
            options: DRCOptions(requireAntennaRules: true)
        ))

        #expect(!result.result.passed)
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.measured == 10)
        #expect(diagnostic.required == 5)
    }

    @Test func antennaReadinessGateRejectsMissingGateAnnotationOnConductorNet() async throws {
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
                        xMax: 2,
                        yMax: 1,
                        netID: "out"
                    ),
                ],
                rules: [NativeDRCRule(
                    id: "met1.antenna",
                    kind: .maximumAntennaRatio,
                    layer: "met1",
                    value: 10,
                    antennaModel: .partial,
                    antennaLayers: [NativeDRCAntennaLayer(
                        layer: "met1",
                        measurement: .surface,
                        ratioGate: 10
                    )]
                )],
                antennaMetadata: NativeDRCAntennaMetadata(
                    gateAreasComplete: true,
                    diffusionAreasComplete: true,
                    processStepsComplete: true,
                    cutConnectivityComplete: true,
                    source: "unit-test"
                )
            ),
            in: directory
        )

        await #expect(throws: DRCError.invalidInput(
            "Native DRC antenna readiness is not established for technology unit-test-tech: net out has conductor geometry for rule met1.antenna but no gate-area annotation."
        )) {
            _ = try await NativeDRCBackend().run(DRCRequest(
                layoutURL: layoutURL,
                topCell: "inv",
                backendSelection: DRCBackendSelection(backendID: "native"),
                options: DRCOptions(requireAntennaRules: true)
            ))
        }
    }

    @Test func detailedSidewallAntennaUsesUnionPerimeter() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "wire.left", layer: "met1", xMin: 0, yMin: 0, xMax: 2, yMax: 1, netID: "out"),
                    NativeDRCRectangle(id: "wire.right", layer: "met1", xMin: 2, yMin: 0, xMax: 4, yMax: 1, netID: "out"),
                    NativeDRCRectangle(id: "gate", layer: "poly", xMin: 0, yMin: 3, xMax: 1, yMax: 4, netID: "out", antennaGateArea: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.sidewall",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 9,
                        gateLayer: "poly",
                        antennaModel: .partial,
                        antennaLayers: [NativeDRCAntennaLayer(
                            layer: "met1",
                            measurement: .sidewall,
                            ratioGate: 9,
                            thickness: 1
                        )]
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
        #expect(diagnostic.measured == 10)
        #expect(diagnostic.required == 9)
    }

    @Test func detailedCumulativeAntennaAggregatesProcessLayers() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "m1", layer: "met1", xMin: 0, yMin: 0, xMax: 3, yMax: 1, netID: "out"),
                    NativeDRCRectangle(id: "m2", layer: "met2", xMin: 0, yMin: 2, xMax: 4, yMax: 3, netID: "out"),
                    NativeDRCRectangle(id: "gate", layer: "poly", xMin: 0, yMin: 4, xMax: 1, yMax: 5, netID: "out", antennaGateArea: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met2.antenna.cumulative",
                        kind: .maximumAntennaRatio,
                        layer: "met2",
                        value: 4,
                        gateLayer: "poly",
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 4),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 4),
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
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.kind == "maximumAntennaEffectiveRatio")
        #expect(abs((diagnostic.measured ?? 0) - 1.75) < 0.000001)
        #expect(diagnostic.required == 1)
    }

    @Test func detailedAntennaAppliesFiniteDiffusionCorrection() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "wire", layer: "met1", xMin: 0, yMin: 0, xMax: 50, yMax: 1, netID: "out"),
                    NativeDRCRectangle(id: "diff", layer: "active", xMin: 0, yMin: 2, xMax: 1, yMax: 3, netID: "out", antennaDiffusionArea: 10),
                    NativeDRCRectangle(id: "gate", layer: "poly", xMin: 0, yMin: 4, xMax: 1, yMax: 5, netID: "out", antennaGateArea: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.diffusion",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 10,
                        gateLayer: "poly",
                        antennaModel: .partial,
                        antennaLayers: [NativeDRCAntennaLayer(
                            layer: "met1",
                            measurement: .surface,
                            ratioGate: 10,
                            diffusionRatioConstant: 20,
                            diffusionRatioPerArea: 1
                        )]
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
        #expect(diagnostic.kind == "maximumAntennaEffectiveRatio")
        #expect(abs((diagnostic.measured ?? 0) - 1.25) < 0.000001)
        #expect(diagnostic.required == 1)
    }

    @Test func detailedAntennaNoneDiffusionCorrectionSkipsDiffusionNet() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(id: "wire", layer: "met1", xMin: 0, yMin: 0, xMax: 50, yMax: 1, netID: "out"),
                    NativeDRCRectangle(id: "diff", layer: "active", xMin: 0, yMin: 2, xMax: 1, yMax: 3, netID: "out", antennaDiffusionArea: 10),
                    NativeDRCRectangle(id: "gate", layer: "poly", xMin: 0, yMin: 4, xMax: 1, yMax: 5, netID: "out", antennaGateArea: 1),
                ],
                rules: [
                    NativeDRCRule(
                        id: "met1.antenna.none",
                        kind: .maximumAntennaRatio,
                        layer: "met1",
                        value: 10,
                        gateLayer: "poly",
                        antennaModel: .partial,
                        antennaLayers: [NativeDRCAntennaLayer(
                            layer: "met1",
                            measurement: .surface,
                            ratioGate: 10,
                            diffusionCorrection: .none
                        )]
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
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        processStep: "m1",
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
                        layer: "met2",
                        value: 5,
                        gateLayer: "poly",
                        processStep: "m1",
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
        #expect(diagnostic.ruleID == "met1.antenna.processStep")
        #expect(diagnostic.kind == "maximumAntennaRatio")
        #expect(diagnostic.layer == "met2")
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
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ],
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ],
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
                        antennaCutConnections: [
                            NativeDRCAntennaCutConnection(layer: "contact", lowerLayer: "poly", upperLayer: "met1"),
                            NativeDRCAntennaCutConnection(layer: "via1", lowerLayer: "met1", upperLayer: "met2"),
                        ],
                        antennaModel: .cumulative,
                        antennaLayers: [
                            NativeDRCAntennaLayer(layer: "met1", measurement: .surface, ratioGate: 5),
                            NativeDRCAntennaLayer(layer: "met2", measurement: .surface, ratioGate: 5),
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
        #expect(diagnostic.kind == "maximumAntennaEffectiveRatio")
        #expect(diagnostic.layer == "met2")
        #expect(abs((diagnostic.measured ?? 0) - 1.6) < 0.000001)
        #expect(diagnostic.required == 1)
        #expect(diagnostic.unit == "ratio")
        #expect(diagnostic.relatedShapeIDs == ["m1_wire", "m2_wire", "contact", "via1", "gate"])
        #expect(diagnostic.relatedViaIDs == ["contact", "via1"])
        #expect(diagnostic.relatedNetIDs == ["out"])
        #expect(diagnostic.message.contains("through contact,via1"))
        #expect(diagnostic.rawLine.contains("cuts=contact,via1"))
        #expect(diagnostic.suggestedFix?.contains("cut stack") == true)
    }

    @Test func partialAntennaCutStageUsesLowerConnectivityWithoutUpperMetal() async throws {
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
                        xMax: 2,
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
                rules: [NativeDRCRule(
                    id: "via1.antenna.partial",
                    kind: .maximumAntennaRatio,
                    layer: "via1",
                    value: 1,
                    gateLayer: "poly",
                    antennaCutConnections: [
                        NativeDRCAntennaCutConnection(
                            layer: "via1",
                            lowerLayer: "poly",
                            upperLayer: "met2"
                        ),
                    ],
                    antennaModel: .partial,
                    antennaLayers: [NativeDRCAntennaLayer(
                        layer: "via1",
                        measurement: .surface,
                        ratioGate: 1
                    )]
                )],
                antennaMetadata: NativeDRCAntennaMetadata(
                    gateAreasComplete: true,
                    diffusionAreasComplete: true,
                    processStepsComplete: true,
                    cutConnectivityComplete: true,
                    source: "unit-test"
                )
            ),
            in: directory
        )

        let result = try await NativeDRCBackend().run(DRCRequest(
            layoutURL: layoutURL,
            topCell: "inv",
            backendSelection: DRCBackendSelection(backendID: "native"),
            options: DRCOptions(requireAntennaRules: true)
        ))

        #expect(!result.result.passed)
        #expect(result.result.diagnostics.first?.ruleID == "via1.antenna.partial")
        #expect(result.result.diagnostics.first?.relatedViaIDs == ["via1"])
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

    @Test func minimumCutMissingAllCutsFails() async throws {
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
        #expect(result.result.diagnostics.count == 1)
        let diagnostic = result.result.diagnostics[0]
        #expect(diagnostic.ruleID == "via1.minimumCut")
        #expect(diagnostic.kind == "minimumCut")
        #expect(diagnostic.layer == "via1")
        #expect(diagnostic.measured == 0)
        #expect(diagnostic.required == 1)
        #expect(diagnostic.relatedShapeIDs == ["lower", "upper"])
        #expect(diagnostic.relatedViaIDs.isEmpty)
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.suggestedFix?.contains("Add 1 via1 cut") == true)
        #expect(diagnostic.rawLine.contains("cuts="))
    }

    @Test func minimumEnclosurePassesWithCompositeUnionCover() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_left",
                        layer: "met1",
                        xMin: 0.4,
                        yMin: 0.4,
                        xMax: 1.0,
                        yMax: 1.6,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "m1_right",
                        layer: "met1",
                        xMin: 1.0,
                        yMin: 0.4,
                        xMax: 1.6,
                        yMax: 1.6,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 0.5,
                        yMin: 0.5,
                        xMax: 1.5,
                        yMax: 1.5,
                        netID: "sig"
                    ),
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

        #expect(result.result.passed)
        #expect(result.result.diagnostics.isEmpty)
    }

    @Test func minimumEnclosureReportsCompositeUnionDeficit() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "m1_left",
                        layer: "met1",
                        xMin: 0.5,
                        yMin: 0.5,
                        xMax: 1.0,
                        yMax: 1.5,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "m1_right",
                        layer: "met1",
                        xMin: 1.0,
                        yMin: 0.5,
                        xMax: 1.5,
                        yMax: 1.5,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "via1",
                        layer: "via1",
                        xMin: 0.5,
                        yMin: 0.5,
                        xMax: 1.5,
                        yMax: 1.5,
                        netID: "sig"
                    ),
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
        #expect(abs((diagnostic.measured ?? 0) - 0.0) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.unit == "micrometer")
        let region = try #require(diagnostic.region)
        #expect(abs(region.x - 0.4) < 0.000001)
        #expect(abs(region.y - 0.4) < 0.000001)
        #expect(abs(region.width - 1.2) < 0.000001)
        #expect(abs(region.height - 1.2) < 0.000001)
        #expect(diagnostic.relatedShapeIDs == ["via1", "m1_left", "m1_right"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("mode=union"))
        #expect(diagnostic.suggestedFix?.contains("union") == true)
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
        #expect(diagnostic.region == DRCRegion(x: 0, y: 0, width: 1.3, height: 1))
        #expect(diagnostic.relatedShapeIDs == ["via1_bad", "m1_cover"])
        #expect(diagnostic.rawLine.contains("mode=union"))
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

    @Test func minimumExtensionIgnoresPartialOverlapThatDoesNotCoverEnclosedInterval() async throws {
        let directory = try makeTemporaryDirectory()
        let layoutURL = try writeLayout(
            NativeDRCLayout(
                technologyID: "unit-test-tech",
                topCell: "inv",
                rectangles: [
                    NativeDRCRectangle(
                        id: "gate",
                        layer: "active",
                        xMin: 4,
                        yMin: 0,
                        xMax: 5,
                        yMax: 1,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "unrelated-strip",
                        layer: "poly",
                        xMin: 0,
                        yMin: 0,
                        xMax: 20,
                        yMax: 0.5,
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
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.ruleID == "poly.active.extension")
        #expect(diagnostic.kind == "minimumExtension")
        #expect(diagnostic.measured == 0)
        #expect(diagnostic.relatedShapeIDs == ["gate"])
    }

    @Test func verticalMinimumExtensionReportsMissingEndcap() async throws {
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
                        yMin: 1,
                        xMax: 2,
                        yMax: 2,
                        netID: "sig"
                    ),
                    NativeDRCRectangle(
                        id: "poly",
                        layer: "poly",
                        xMin: 1,
                        yMin: 0.96,
                        xMax: 2,
                        yMax: 2.05,
                        netID: "sig"
                    ),
                ],
                rules: [
                    NativeDRCRule(
                        id: "poly.active.vertical-extension",
                        kind: .minimumExtension,
                        layer: "poly",
                        value: 0.1,
                        enclosedLayer: "active",
                        extensionDirection: .vertical
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
        let diagnostic = try #require(result.result.diagnostics.first)
        #expect(diagnostic.ruleID == "poly.active.vertical-extension")
        #expect(diagnostic.kind == "minimumExtension")
        #expect(diagnostic.layer == "poly")
        #expect(abs((diagnostic.measured ?? 0) - 0.04) < 0.000001)
        #expect(diagnostic.required == 0.1)
        #expect(diagnostic.relatedShapeIDs == ["active", "poly"])
        #expect(diagnostic.relatedNetIDs == ["sig"])
        #expect(diagnostic.rawLine.contains("direction=vertical"))
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
