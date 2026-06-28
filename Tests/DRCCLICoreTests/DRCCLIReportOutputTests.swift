import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    @Test func legacyCorpusReportDecodesWithDerivedQualification() throws {
        let data = Data("""
        {
          "schemaVersion" : 1,
          "passed" : true,
          "caseCount" : 0,
          "matchedCaseCount" : 0,
          "budgetExceededCaseCount" : 0,
          "totalDurationSeconds" : 0,
          "caseResults" : []
        }
        """.utf8)

        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: data)

        #expect(report.summary.passRate == 1)
        #expect(report.qualification.qualified)
        #expect(report.qualification.policy == .strict)
    }

    @Test func cliOutputIncludesStructuredDiagnostics() {
        let diagnostic = DRCDiagnostic(
            severity: .error,
            message: "Minimum width violation",
            ruleID: "met1.width",
            kind: "minimumWidth",
            layer: "met1",
            measured: 0.1,
            required: 0.5,
            unit: "micrometer",
            region: DRCRegion(x: 0, y: 0, width: 0.1, height: 1),
            relatedShapeIDs: ["thin"],
            suggestedFix: "Increase the narrow dimension.",
            rawLine: "MIN_WIDTH layer=met1 id=thin"
        )
        let output = DRCCLIOutput(result: DRCExecutionResult(
            request: DRCRequest(layoutURL: URL(filePath: "/tmp/layout.json"), topCell: "inv"),
            result: DRCResult(
                backendID: "native",
                toolName: "NativeDRC",
                success: true,
                completed: true,
                logPath: "",
                diagnostics: [diagnostic]
            ),
            waiverReport: DRCWaiverApplicationReport(
                waivedDiagnosticCount: 0,
                appliedWaivers: [],
                unusedWaiverIDs: ["unused"]
            )
        ))

        #expect(output.status == "failed")
        #expect(output.diagnosticSummary.errorCount == 1)
        #expect(output.runSummary.activeViolationCount == 1)
        #expect(output.runSummary.waivedViolationCount == 0)
        #expect(output.runSummary.violationBuckets.first?.ruleID == "met1.width")
        #expect(output.runSummary.violationBuckets.first?.representativeRegion == DRCRegion(x: 0, y: 0, width: 0.1, height: 1))
        #expect(output.runSummary.violationBuckets.first?.relatedShapeIDs == ["thin"])
        #expect(output.diagnostics == [diagnostic])
        #expect(output.waiverReport?.unusedWaiverIDs == ["unused"])
    }

    @Test func legacyExecutionResultDecodesWithoutRepairHintGeometry() throws {
        let data = Data("""
        {
          "request" : {
            "layoutURL" : "file:///tmp/layout.json",
            "topCell" : "inv",
            "backendSelection" : {
              "backendID" : "native"
            },
            "options" : {
              "timeoutSeconds" : 300,
              "additionalEnvironment" : {}
            }
          },
          "result" : {
            "backendID" : "native",
            "toolName" : "NativeDRC",
            "success" : true,
            "completed" : true,
            "logPath" : "",
            "diagnostics" : []
          }
        }
        """.utf8)

        let result = try JSONDecoder().decode(DRCExecutionResult.self, from: data)

        #expect(result.request.topCell == "inv")
        #expect(result.result.backendID == "native")
        #expect(result.repairHintGeometry == nil)
    }

    @Test func repairHintBuilderMapsDiagnosticsToLayoutOperations() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let layoutURL = root.appending(path: "layout.json")
        try """
        {
          "technologyID" : "test",
          "topCell" : "inv",
          "unit" : "micrometer",
          "rectangles" : [
            { "id" : "thin", "layer" : "met1", "xMin" : 0, "yMin" : 0, "xMax" : 0.1, "yMax" : 1 },
            { "id" : "left", "layer" : "met1", "xMin" : 0, "yMin" : 0, "xMax" : 0.4, "yMax" : 1 },
            { "id" : "right", "layer" : "met1", "xMin" : 0.5, "yMin" : 0, "xMax" : 0.9, "yMax" : 1 },
            { "id" : "notched", "layer" : "met1", "xMin" : 1, "yMin" : 1, "xMax" : 2, "yMax" : 2 },
            { "id" : "lower", "layer" : "met1", "xMin" : 0, "yMin" : 0, "xMax" : 2, "yMax" : 2, "netID" : "sig" },
            { "id" : "upper", "layer" : "met2", "xMin" : 0, "yMin" : 0, "xMax" : 2, "yMax" : 2, "netID" : "sig" },
            { "id" : "cut-a", "layer" : "via1", "xMin" : 0.5, "yMin" : 0.5, "xMax" : 1.5, "yMax" : 1.5, "netID" : "sig" },
            { "id" : "sparse", "layer" : "met1", "xMin" : 0, "yMin" : 0, "xMax" : 0.25, "yMax" : 0.25 },
            { "id" : "short-left", "layer" : "met1", "xMin" : 0, "yMin" : 0, "xMax" : 1, "yMax" : 1, "netID" : "a" },
            { "id" : "short-right", "layer" : "met1", "xMin" : 0.8, "yMin" : 0.2, "xMax" : 1.4, "yMax" : 0.8, "netID" : "b" }
          ],
          "rules" : []
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)

        let result = DRCExecutionResult(
            request: DRCRequest(layoutURL: layoutURL, topCell: "inv"),
            result: DRCResult(
                backendID: "native",
                toolName: "NativeDRC",
                success: true,
                completed: true,
                logPath: "",
                diagnostics: [
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum width violation",
                        ruleID: "met1.width",
                        kind: "minimumWidth",
                        layer: "met1",
                        measured: 0.1,
                        required: 0.5,
                        unit: "micrometer",
                        region: DRCRegion(x: 0, y: 0, width: 0.1, height: 1),
                        relatedShapeIDs: ["thin"],
                        suggestedFix: "Increase the narrow dimension.",
                        rawLine: "MIN_WIDTH layer=met1 id=thin"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum spacing violation",
                        ruleID: "met1.spacing",
                        kind: "minimumSpacing",
                        layer: "met1",
                        measured: 0.1,
                        required: 0.5,
                        unit: "micrometer",
                        region: DRCRegion(x: 0.4, y: 0, width: 0.1, height: 1),
                        relatedShapeIDs: ["left", "right"],
                        rawLine: "MIN_SPACING layer=met1 ids=left,right"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum notch violation",
                        ruleID: "met1.notch",
                        kind: "minimumNotch",
                        layer: "met1",
                        measured: 0.1,
                        required: 0.5,
                        unit: "micrometer",
                        region: DRCRegion(x: 1, y: 1, width: 0.1, height: 0.5),
                        relatedShapeIDs: ["notched"],
                        rawLine: "MIN_NOTCH layer=met1 id=notched"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum cut violation",
                        ruleID: "via1.minimumCut",
                        kind: "minimumCut",
                        layer: "via1",
                        measured: 1,
                        required: 2,
                        unit: "cut",
                        region: DRCRegion(x: 0, y: 0, width: 2, height: 2),
                        relatedShapeIDs: ["lower", "upper", "cut-a"],
                        relatedViaIDs: ["cut-a"],
                        relatedNetIDs: ["sig"],
                        rawLine: "MIN_CUT layer=via1 lowerLayer=met1 upperLayer=met2 net=sig cuts=cut-a"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum enclosed area violation",
                        ruleID: "met1.enclosedArea",
                        kind: "minimumEnclosedArea",
                        layer: "met1",
                        measured: 0.04,
                        required: 0.1,
                        unit: "micrometer^2",
                        region: DRCRegion(x: 1, y: 1, width: 0.2, height: 0.2),
                        relatedShapeIDs: ["left", "right", "bottom", "top"],
                        rawLine: "MIN_ENCLOSED_AREA layer=met1 region=1,1,0.2,0.2"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum density violation",
                        ruleID: "met1.minimumDensity",
                        kind: "minimumDensity",
                        layer: "met1",
                        measured: 0.0625,
                        required: 0.2,
                        unit: "ratio",
                        region: DRCRegion(x: 0, y: 0, width: 1, height: 1),
                        relatedShapeIDs: ["sparse"],
                        rawLine: "MIN_DENSITY layer=met1 window=0,0,1,1"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Different net overlap violation",
                        ruleID: "met1.differentNetOverlap",
                        kind: "differentNetOverlap",
                        layer: "met1",
                        measured: 0.12,
                        required: 0,
                        unit: "micrometer^2",
                        region: DRCRegion(x: 0.8, y: 0.2, width: 0.2, height: 0.6),
                        relatedShapeIDs: ["short-left", "short-right"],
                        relatedNetIDs: ["a", "b"],
                        rawLine: "DIFFERENT_NET_OVERLAP layer=met1 ids=short-left,short-right nets=a,b"
                    ),
                    DRCDiagnostic(
                        severity: .error,
                        message: "Waived width violation",
                        ruleID: "met1.width",
                        kind: "minimumWidth",
                        layer: "met1",
                        measured: 0.1,
                        required: 0.5,
                        unit: "micrometer",
                        relatedShapeIDs: ["waived"],
                        waiverID: "waive-width",
                        waiverReason: "Known fixture waiver",
                        rawLine: "MIN_WIDTH layer=met1 id=waived"
                    ),
                ]
            )
        )

        let report = DRCRepairHintBuilder().build(result: result)

        #expect(report.status == "ready")
        #expect(report.activeDiagnosticCount == 7)
        #expect(report.hintCount == 7)
        #expect(report.unsupportedDiagnosticIndexes.isEmpty)

        let width = try #require(report.hints.first { $0.ruleID == "met1.width" })
        #expect(width.operationID == "layout.resize-shape")
        #expect(width.confidence == "high")
        #expect(width.stringParameters["shapeID"] == "thin")
        #expect(abs((width.numericParameters["deltaMaxX"] ?? -1) - 0.4) < 0.000001)
        #expect(width.numericParameters["deltaMaxY"] == 0)
        #expect(width.verificationGates.contains("native-drc"))

        let spacing = try #require(report.hints.first { $0.ruleID == "met1.spacing" })
        #expect(spacing.operationID == "layout.translate-shape")
        #expect(spacing.confidence == "medium")
        #expect(spacing.stringParameters["shapeID"] == "left")
        #expect(spacing.stringParameters["anchorShapeID"] == "right")
        #expect(spacing.stringParameters["translationAxis"] == "horizontal")
        #expect(spacing.stringParameters["translationReason"] == "minimumSpacing")
        #expect(abs((spacing.numericParameters["minimumSeparationDelta"] ?? -1) - 0.4) < 0.000001)
        #expect(abs((spacing.numericParameters["deltaX"] ?? -1) - -0.4) < 0.000001)
        #expect(spacing.numericParameters["deltaY"] == 0)
        #expect(abs((spacing.numericParameters["translationDistance"] ?? -1) - 0.4) < 0.000001)
        #expect(spacing.verificationGates.contains("native-lvs"))

        let notch = try #require(report.hints.first { $0.ruleID == "met1.notch" })
        #expect(notch.operationID == "layout.add-rect")
        #expect(notch.numericParameters["originX"] == 1)
        #expect(notch.numericParameters["width"] == 0.1)
        #expect(notch.verificationGates.contains("native-lvs"))

        let minimumCut = try #require(report.hints.first { $0.ruleID == "via1.minimumCut" })
        #expect(minimumCut.operationID == "layout.add-via")
        #expect(minimumCut.confidence == "medium")
        #expect(minimumCut.relatedViaIDs == ["cut-a"])
        #expect(minimumCut.stringParameters["viaDefinitionID"] == "VIA1")
        #expect(minimumCut.stringParameters["cutLayer"] == "via1")
        #expect(minimumCut.stringParameters["existingCutIDs"] == "cut-a")
        #expect(minimumCut.numericParameters["positionX"] == 1)
        #expect(minimumCut.numericParameters["positionY"] == 1)
        #expect(minimumCut.numericParameters["existingCutCount"] == 1)
        #expect(minimumCut.numericParameters["requiredCutCount"] == 2)
        #expect(minimumCut.numericParameters["missingCutCount"] == 1)
        #expect(minimumCut.verificationGates.contains("native-lvs"))

        let enclosedArea = try #require(report.hints.first { $0.ruleID == "met1.enclosedArea" })
        #expect(enclosedArea.operationID == "layout.add-rect")
        #expect(enclosedArea.stringParameters["fillPurpose"] == "minimumEnclosedArea")
        #expect(enclosedArea.stringParameters["layer"] == "met1")
        #expect(enclosedArea.numericParameters["originX"] == 1)
        #expect(enclosedArea.numericParameters["originY"] == 1)
        #expect(enclosedArea.numericParameters["width"] == 0.2)
        #expect(enclosedArea.numericParameters["height"] == 0.2)
        #expect(enclosedArea.numericParameters["enclosedArea"] == 0.04)
        #expect(enclosedArea.numericParameters["requiredEnclosedArea"] == 0.1)
        #expect(enclosedArea.verificationGates.contains("native-lvs"))

        let minimumDensity = try #require(report.hints.first { $0.ruleID == "met1.minimumDensity" })
        #expect(minimumDensity.operationID == "layout.add-rect")
        #expect(minimumDensity.stringParameters["fillPurpose"] == "minimumDensity")
        #expect(minimumDensity.numericParameters["densityWindowX"] == 0)
        #expect(minimumDensity.numericParameters["densityWindowY"] == 0)
        #expect(minimumDensity.numericParameters["densityWindowWidth"] == 1)
        #expect(minimumDensity.numericParameters["densityWindowHeight"] == 1)
        #expect(minimumDensity.numericParameters["densityWindowArea"] == 1)
        #expect(minimumDensity.numericParameters["measuredDensity"] == 0.0625)
        #expect(minimumDensity.numericParameters["requiredDensity"] == 0.2)
        #expect(abs((minimumDensity.numericParameters["targetFillArea"] ?? -1) - 0.1375) < 0.000001)
        #expect(abs((minimumDensity.numericParameters["width"] ?? -1) - sqrt(0.1375)) < 0.000001)
        #expect(abs((minimumDensity.numericParameters["height"] ?? -1) - sqrt(0.1375)) < 0.000001)
        #expect(minimumDensity.verificationGates.contains("native-lvs"))

        let overlapShort = try #require(report.hints.first { $0.ruleID == "met1.differentNetOverlap" })
        #expect(overlapShort.operationID == "layout.translate-shape")
        #expect(overlapShort.stringParameters["shapeID"] == "short-left")
        #expect(overlapShort.stringParameters["anchorShapeID"] == "short-right")
        #expect(overlapShort.stringParameters["translationAxis"] == "horizontal")
        #expect(overlapShort.stringParameters["translationReason"] == "overlapSeparation")
        #expect(abs((overlapShort.numericParameters["deltaX"] ?? -1) - -0.19999999999999996) < 0.000001)
        #expect(overlapShort.numericParameters["deltaY"] == 0)
        #expect(abs((overlapShort.numericParameters["translationDistance"] ?? -1) - 0.19999999999999996) < 0.000001)
        #expect(abs((overlapShort.numericParameters["overlapWidth"] ?? -1) - 0.19999999999999996) < 0.000001)
        #expect(abs((overlapShort.numericParameters["overlapHeight"] ?? -1) - 0.6000000000000001) < 0.000001)
        #expect(abs((overlapShort.numericParameters["overlapArea"] ?? -1) - 0.12) < 0.000001)
        #expect(overlapShort.verificationGates.contains("native-lvs"))

        let encoded = try JSONEncoder().encode(minimumCut)
        let decoded = try JSONDecoder().decode(DRCRepairHint.self, from: encoded)
        #expect(decoded.relatedViaIDs == ["cut-a"])
    }

    @Test func legacyRepairHintDecodesWithoutRelatedViaIDs() throws {
        let data = Data("""
        {
          "hintID" : "legacy-drc-repair",
          "sourceDiagnosticIndex" : 0,
          "operationID" : "layout.resize-shape",
          "confidence" : "high",
          "ruleID" : "met1.width",
          "kind" : "minimumWidth",
          "layer" : "met1",
          "targetShapeIDs" : ["thin"],
          "relatedNetIDs" : ["sig"],
          "measured" : 0.1,
          "required" : 0.5,
          "numericParameters" : {
            "deltaMaxX" : 0.4
          },
          "stringParameters" : {
            "shapeID" : "thin"
          },
          "verificationGates" : [
            "native-drc",
            "artifact-integrity"
          ],
          "rationale" : "legacy artifact"
        }
        """.utf8)

        let hint = try JSONDecoder().decode(DRCRepairHint.self, from: data)

        #expect(hint.relatedViaIDs.isEmpty)
        #expect(hint.targetShapeIDs == ["thin"])
        #expect(hint.relatedNetIDs == ["sig"])
    }

    @Test func repairHintsCLIReadsSavedReportAndReturnsSuccess() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let reportURL = root.appending(path: "drc-report.json")
        try writeJSON(DRCExecutionResult(
            request: DRCRequest(layoutURL: URL(filePath: "/tmp/layout.json"), topCell: "inv"),
            result: DRCResult(
                backendID: "native",
                toolName: "NativeDRC",
                success: true,
                completed: true,
                logPath: "",
                diagnostics: [
                    DRCDiagnostic(
                        severity: .error,
                        message: "Minimum width violation",
                        ruleID: "met1.width",
                        kind: "minimumWidth",
                        layer: "met1",
                        measured: 0.1,
                        required: 0.5,
                        unit: "micrometer",
                        relatedShapeIDs: ["thin"],
                        rawLine: "MIN_WIDTH layer=met1 id=thin"
                    ),
                ]
            )
        ), to: reportURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--repair-hints-from-report", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let report = try DRCRepairHintBuilder().build(reportURL: reportURL)
        #expect(report.hints.map(\.operationID) == ["layout.resize-shape"])
    }
}
