import Foundation
import DRCCore

public struct NativeDRCBackend: DRCBackend {
    public let backendID = "native"
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        let layout = try loadLayout(for: request)
        try validateTopCell(request.topCell, layout: layout)
        try validateRuleDeck(layout)
        let diagnostics = try evaluate(layout: layout)
        let logPath = try writeRunLogIfRequested(diagnostics: diagnostics, request: request)
        return makeExecutionResult(request: request, layout: layout, diagnostics: diagnostics, logPath: logPath)
    }

    private func loadLayout(for request: DRCRequest) throws -> NativeDRCLayout {
        let data = try readLayoutData(from: request.layoutURL)
        return try decodeLayout(data)
    }

    private func readLayoutData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw DRCError.invalidInput("Native DRC could not read layout: \(error.localizedDescription)")
        }
    }

    private func decodeLayout(_ data: Data) throws -> NativeDRCLayout {
        do {
            return try decoder.decode(NativeDRCLayout.self, from: data)
        } catch {
            throw DRCError.invalidInput("Native DRC expects canonical layout JSON: \(error.localizedDescription)")
        }
    }

    private func validateTopCell(_ requestedTopCell: String, layout: NativeDRCLayout) throws {
        guard layout.topCell == requestedTopCell else {
            throw DRCError.invalidInput("Requested top cell \(requestedTopCell) does not match layout top cell \(layout.topCell)")
        }
    }

    private func validateRuleDeck(_ layout: NativeDRCLayout) throws {
        guard !layout.rules.isEmpty else {
            throw DRCError.invalidInput(
                "Native DRC rule deck is empty for technology \(layout.technologyID). Provide at least one physical rule."
            )
        }
    }

    private func writeRunLogIfRequested(
        diagnostics: [DRCDiagnostic],
        request: DRCRequest
    ) throws -> String {
        if let workingDirectory = request.workingDirectory {
            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )
            let logURL = workingDirectory.appending(path: "drc-native-\(UUID().uuidString).log")
            try runLogText(diagnostics: diagnostics, topCell: request.topCell)
                .write(to: logURL, atomically: true, encoding: .utf8)
            return logURL.path(percentEncoded: false)
        }
        return ""
    }

    private func runLogText(diagnostics: [DRCDiagnostic], topCell: String) -> String {
        (["\(diagnostics.count) violation(s) on \(topCell)"]
            + diagnostics.map { "\($0.severity): \($0.message)" })
            .joined(separator: "\n") + "\n"
    }

    private func makeExecutionResult(
        request: DRCRequest,
        layout: NativeDRCLayout,
        diagnostics: [DRCDiagnostic],
        logPath: String
    ) -> DRCExecutionResult {
        let result = makeResult(
            layout: layout,
            diagnostics: diagnostics,
            logPath: logPath,
            timeoutSeconds: request.options.timeoutSeconds
        )
        return DRCExecutionResult(
            request: request,
            result: result,
            repairHintGeometry: repairHintGeometry(from: layout)
        )
    }

    private func makeResult(
        layout: NativeDRCLayout,
        diagnostics: [DRCDiagnostic],
        logPath: String,
        timeoutSeconds: Double
    ) -> DRCResult {
        DRCResult(
            backendID: backendID,
            toolName: "NativeDRC",
            success: true,
            completed: true,
            logPath: logPath,
            diagnostics: diagnostics,
            provenance: DRCToolProvenance(
                executablePath: "in-process",
                pdkRoot: layout.technologyID,
                rcFilePath: "not-applicable",
                driverScriptPath: "not-applicable",
                timeoutSeconds: timeoutSeconds
            )
        )
    }

    private func repairHintGeometry(from layout: NativeDRCLayout) -> DRCRepairHintGeometryContext {
        DRCRepairHintGeometryContext(
            source: "native-json",
            topCell: layout.topCell,
            unit: layout.unit,
            rectangles: layout.rectangles.map {
                DRCRepairHintGeometryRectangle(
                    id: $0.id,
                    layer: $0.layer,
                    netID: $0.netID,
                    xMin: $0.xMin,
                    yMin: $0.yMin,
                    xMax: $0.xMax,
                    yMax: $0.yMax
                )
            }
        )
    }

    private struct EvaluationContext {
        var layout: NativeDRCLayout
        var rectanglesByLayer: [String: [NativeDRCRectangle]]

        init(layout: NativeDRCLayout) {
            self.layout = layout
            self.rectanglesByLayer = Dictionary(grouping: layout.rectangles, by: \.layer)
        }
    }

    private func evaluate(layout: NativeDRCLayout) throws -> [DRCDiagnostic] {
        let context = EvaluationContext(layout: layout)
        var diagnostics: [DRCDiagnostic] = []
        for rule in layout.rules {
            diagnostics.append(contentsOf: try evaluate(rule: rule, context: context))
        }
        return diagnostics
    }

    private func evaluate(rule: NativeDRCRule, context: EvaluationContext) throws -> [DRCDiagnostic] {
        switch rule.kind {
        case .manufacturingGrid:
            return try evaluateManufacturingGridRule(rule, context: context)
        case .minimumWidth:
            return evaluateMinimumWidthRule(rule, context: context)
        case .maximumWidth:
            return evaluateMaximumWidthRule(rule, context: context)
        case .forbiddenLayer:
            return evaluateForbiddenLayer(rule: rule, rectangles: context.rectanglesByLayer[rule.layer, default: []])
        case .minimumSpacing:
            return try evaluateMinimumSpacingRule(rule, context: context)
        case .forbiddenOverlap:
            return try evaluateForbiddenOverlapRule(rule, context: context)
        case .exactOverlap:
            return try evaluateExactOverlapRule(rule, context: context)
        case .differentNetOverlap:
            return try evaluateDifferentNetOverlap(
                rule: rule,
                rectangles: context.rectanglesByLayer[rule.layer, default: []],
                unit: context.layout.unit
            )
        case .minimumEndOfLineSpacing:
            return try evaluateMinimumEndOfLineSpacingRule(rule, context: context)
        case .minimumArea:
            return evaluateMinimumAreaRule(rule, context: context)
        case .maximumDensity:
            return try evaluateMaximumDensityRule(rule, context: context)
        case .minimumDensity:
            return try evaluateMinimumDensityRule(rule, context: context)
        case .minimumNotch:
            return try evaluateMinimumNotchRule(rule, context: context)
        case .minimumEnclosedArea:
            return try evaluateMinimumEnclosedAreaRule(rule, context: context)
        case .minimumCut:
            return try evaluateMinimumCut(
                rule: rule,
                cutRectangles: context.rectanglesByLayer[rule.layer, default: []],
                rectanglesByLayer: context.rectanglesByLayer
            )
        case .maximumAntennaRatio:
            return try evaluateMaximumAntennaRatioRule(rule, context: context)
        case .minimumEnclosure:
            return try evaluateMinimumEnclosureRule(rule, context: context)
        case .minimumExtension:
            return try evaluateMinimumExtensionRule(rule, context: context)
        }
    }

    private func layerRectangles(_ rule: NativeDRCRule, context: EvaluationContext) -> [NativeDRCRectangle]? {
        context.rectanglesByLayer[rule.layer]
    }

    private func evaluateManufacturingGridRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return try evaluateManufacturingGrid(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMinimumWidthRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return evaluateMinimumWidth(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMaximumWidthRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return evaluateMaximumWidth(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMinimumSpacingRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        if let secondaryLayer = rule.secondaryLayer, secondaryLayer != rule.layer {
            return try evaluateMinimumSpacing(
                rule: rule,
                primaryRectangles: rectangles,
                secondaryRectangles: context.rectanglesByLayer[secondaryLayer, default: []],
                unit: context.layout.unit
            )
        }
        return try evaluateMinimumSpacing(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateForbiddenOverlapRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        let secondaryLayer = try requiredSecondaryLayer(for: rule, kind: "forbiddenOverlap")
        return try evaluateForbiddenOverlap(
            rule: rule,
            primaryRectangles: context.rectanglesByLayer[rule.layer, default: []],
            secondaryRectangles: context.rectanglesByLayer[secondaryLayer, default: []],
            secondaryLayer: secondaryLayer,
            unit: context.layout.unit
        )
    }

    private func evaluateExactOverlapRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        let secondaryLayer = try requiredSecondaryLayer(for: rule, kind: "exactOverlap")
        return try evaluateExactOverlap(
            rule: rule,
            primaryRectangles: context.rectanglesByLayer[rule.layer, default: []],
            secondaryRectangles: context.rectanglesByLayer[secondaryLayer, default: []],
            secondaryLayer: secondaryLayer,
            unit: context.layout.unit
        )
    }

    private func evaluateMinimumEndOfLineSpacingRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return try evaluateMinimumEndOfLineSpacing(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMinimumAreaRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return evaluateMinimumArea(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMaximumDensityRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        try evaluateMaximumDensity(
            rule: rule,
            rectangles: context.rectanglesByLayer[rule.layer, default: []],
            fallbackRectangles: context.layout.rectangles,
            unit: context.layout.unit
        )
    }

    private func evaluateMinimumDensityRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        try evaluateMinimumDensity(
            rule: rule,
            rectangles: context.rectanglesByLayer[rule.layer, default: []],
            fallbackRectangles: context.layout.rectangles,
            unit: context.layout.unit
        )
    }

    private func evaluateMinimumNotchRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return try evaluateMinimumNotch(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMinimumEnclosedAreaRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        guard let rectangles = layerRectangles(rule, context: context) else { return [] }
        return try evaluateMinimumEnclosedArea(rule: rule, rectangles: rectangles, unit: context.layout.unit)
    }

    private func evaluateMaximumAntennaRatioRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        let conductorLayers = try antennaConductorLayers(for: rule)
        let conductorLayerSet = Set(conductorLayers)
        let rectangles = context.layout.rectangles.filter { conductorLayerSet.contains($0.layer) }
        guard !rectangles.isEmpty else { return [] }
        return try evaluateMaximumAntennaRatio(
            rule: rule,
            conductorRectangles: rectangles,
            allRectangles: context.layout.rectangles,
            unit: context.layout.unit
        )
    }

    private func evaluateMinimumEnclosureRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        let enclosedLayer = try requiredEnclosedLayer(for: rule, kind: "minimumEnclosure")
        return try evaluateMinimumEnclosure(
            rule: rule,
            enclosingRectangles: context.rectanglesByLayer[rule.layer, default: []],
            enclosedRectangles: context.rectanglesByLayer[enclosedLayer, default: []],
            enclosedLayer: enclosedLayer,
            unit: context.layout.unit
        )
    }

    private func evaluateMinimumExtensionRule(
        _ rule: NativeDRCRule,
        context: EvaluationContext
    ) throws -> [DRCDiagnostic] {
        let enclosedLayer = try requiredEnclosedLayer(for: rule, kind: "minimumExtension")
        return try evaluateMinimumExtension(
            rule: rule,
            extendingRectangles: context.rectanglesByLayer[rule.layer, default: []],
            enclosedRectangles: context.rectanglesByLayer[enclosedLayer, default: []],
            enclosedLayer: enclosedLayer,
            unit: context.layout.unit
        )
    }

    private func requiredEnclosedLayer(for rule: NativeDRCRule, kind: String) throws -> String {
        guard let enclosedLayer = rule.enclosedLayer else {
            throw DRCError.invalidInput("Rule \(rule.id) requires enclosedLayer for \(kind)")
        }
        return enclosedLayer
    }
}
