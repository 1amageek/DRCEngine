import CircuiteFoundation
import Foundation
import DRCCore

public struct NativeDRCBackend: DRCCancellableBackend {
    public let backendID = "native"
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request, cancellationCheck: nil)
    }

    public func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult {
        let startedAt = Date()
        let inputArtifacts = try DRCExecutionProvenance.captureInputArtifacts(for: request)
        try await checkCancellation(cancellationCheck)
        let layout = try loadLayout(for: request)
        try await checkCancellation(cancellationCheck)
        try validateTopCell(request.topCell, layout: layout)
        try validateLayout(layout)
        try validateRuleDeck(layout)
        try validateAntennaReadiness(layout, options: request.options)
        let diagnostics = try await evaluate(layout: layout, cancellationCheck: cancellationCheck)
        try await checkCancellation(cancellationCheck)
        let logPath = try writeRunLogIfRequested(diagnostics: diagnostics, request: request)
        return try makeExecutionResult(
            request: request,
            layout: layout,
            diagnostics: diagnostics,
            logPath: logPath,
            startedAt: startedAt,
            inputArtifacts: inputArtifacts
        )
    }

    private func checkCancellation(
        _ cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws {
        if Task.isCancelled {
            throw DRCError.cancelled("Native DRC execution was cancelled.")
        }
        if let cancellationCheck, try await cancellationCheck() {
            throw DRCError.cancelled("Native DRC execution was cancelled.")
        }
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

    private func validateAntennaReadiness(_ layout: NativeDRCLayout, options: DRCOptions) throws {
        guard options.requireAntennaRules else {
            return
        }
        let antennaRules = layout.rules.filter { $0.kind == .maximumAntennaRatio }
        guard !antennaRules.isEmpty else {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): the rule deck contains no maximumAntennaRatio rule."
            )
        }
        guard let metadata = layout.antennaMetadata else {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): antennaMetadata is missing."
            )
        }
        guard metadata.gateAreasComplete else {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): gate-area metadata is incomplete."
            )
        }
        try validateAntennaGateCoverage(layout: layout, rules: antennaRules)
        if antennaRules.contains(where: { $0.antennaLayers != nil }), !metadata.diffusionAreasComplete {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): diffusion-area metadata is incomplete for detailed antenna rules."
            )
        }
        if antennaRules.contains(where: { $0.processStep != nil }), !metadata.processStepsComplete {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): process-step metadata is incomplete."
            )
        }
        if antennaRules.contains(where: { ($0.antennaCutConnections?.isEmpty == false) }), !metadata.cutConnectivityComplete {
            throw DRCError.invalidInput(
                "Native DRC antenna readiness is not established for technology \(layout.technologyID): antenna cut-connectivity metadata is incomplete."
            )
        }
    }

    private func validateAntennaGateCoverage(
        layout: NativeDRCLayout,
        rules: [NativeDRCRule]
    ) throws {
        for rule in rules {
            let antennaLayerNames = rule.antennaLayers?.map(\.layer) ?? []
            let candidateNetIDs = Set(
                layout.rectangles
                    .filter { rectangle in
                        rectangle.netID != nil && antennaLayerNames.contains(rectangle.layer)
                    }
                    .compactMap(\.netID)
            ).sorted()
            for netID in candidateNetIDs {
                let hasGateArea = layout.rectangles.contains { rectangle in
                    rectangle.netID == netID
                        && (rectangle.antennaGateArea ?? 0) > 0
                        && (rule.gateLayer == nil || rectangle.layer == rule.gateLayer)
                }
                guard hasGateArea else {
                    throw DRCError.invalidInput(
                        "Native DRC antenna readiness is not established for technology \(layout.technologyID): net \(netID) has conductor geometry for rule \(rule.id) but no gate-area annotation."
                    )
                }
            }
        }
    }

    private func validateLayout(_ layout: NativeDRCLayout) throws {
        guard !layout.technologyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCError.invalidInput("Native DRC layout technologyID must not be empty.")
        }
        guard !layout.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCError.invalidInput("Native DRC layout unit must not be empty.")
        }

        var rectangleIDs: Set<String> = []
        for rectangle in layout.rectangles {
            guard !rectangle.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("Native DRC rectangle IDs must not be empty.")
            }
            guard rectangleIDs.insert(rectangle.id).inserted else {
                throw DRCError.invalidInput("Native DRC rectangle ID is duplicated: \(rectangle.id).")
            }
            guard !rectangle.layer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("Native DRC rectangle \(rectangle.id) has an empty layer.")
            }
            guard rectangle.xMin.isFinite,
                  rectangle.yMin.isFinite,
                  rectangle.xMax.isFinite,
                  rectangle.yMax.isFinite,
                  rectangle.xMax > rectangle.xMin,
                  rectangle.yMax > rectangle.yMin else {
                throw DRCError.invalidInput(
                    "Native DRC rectangle \(rectangle.id) must have finite coordinates and positive dimensions."
                )
            }
            if let antennaGateArea = rectangle.antennaGateArea,
               !antennaGateArea.isFinite || antennaGateArea < 0 {
                throw DRCError.invalidInput(
                    "Native DRC rectangle \(rectangle.id) has an invalid antennaGateArea."
                )
            }
            if let antennaDiffusionArea = rectangle.antennaDiffusionArea,
               !antennaDiffusionArea.isFinite || antennaDiffusionArea < 0 {
                throw DRCError.invalidInput(
                    "Native DRC rectangle \(rectangle.id) has an invalid antennaDiffusionArea."
                )
            }
            if let antennaProcessStep = rectangle.antennaProcessStep,
               antennaProcessStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DRCError.invalidInput(
                    "Native DRC rectangle \(rectangle.id) has an empty antennaProcessStep."
                )
            }
        }

        var ruleIDs: Set<String> = []
        for rule in layout.rules {
            guard !rule.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("Native DRC rule IDs must not be empty.")
            }
            guard ruleIDs.insert(rule.id).inserted else {
                throw DRCError.invalidInput("Native DRC rule ID is duplicated: \(rule.id).")
            }
            guard !rule.layer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("Native DRC rule \(rule.id) has an empty layer.")
            }
            guard rule.value.isFinite else {
                throw DRCError.invalidInput("Native DRC rule \(rule.id) has a non-finite value.")
            }
            let optionalValues = [
                rule.windowWidth,
                rule.windowHeight,
                rule.stepX,
                rule.stepY,
                rule.windowOriginX,
                rule.windowOriginY,
                rule.endOfLineWidth,
                rule.minimumParallelRunLength,
                rule.wideWidthThreshold,
            ].compactMap { $0 }
            guard optionalValues.allSatisfy(\.isFinite) else {
                throw DRCError.invalidInput("Native DRC rule \(rule.id) has a non-finite parameter.")
            }
            let referencedLayers = [
                rule.enclosedLayer,
                rule.gateLayer,
                rule.secondaryLayer,
                rule.lowerLayer,
                rule.upperLayer,
            ].compactMap { $0 }
            guard referencedLayers.allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else {
                throw DRCError.invalidInput("Native DRC rule \(rule.id) has an empty layer reference.")
            }
            if let processStep = rule.processStep,
               processStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DRCError.invalidInput("Native DRC rule \(rule.id) has an empty processStep.")
            }
            if rule.antennaModel != nil, rule.kind != .maximumAntennaRatio {
                throw DRCError.invalidInput(
                    "Native DRC rule \(rule.id) uses antennaModel on a non-antenna rule."
                )
            }
            if rule.antennaModel != nil, rule.antennaLayers == nil {
                throw DRCError.invalidInput(
                    "Native DRC rule \(rule.id) requires antennaLayers when antennaModel is set."
                )
            }
            if rule.antennaLayers != nil, rule.antennaModel == nil {
                throw DRCError.invalidInput(
                    "Native DRC rule \(rule.id) requires antennaModel when antennaLayers is set."
                )
            }
            if rule.kind == .maximumAntennaRatio {
                guard rule.antennaModel != nil, rule.antennaLayers != nil else {
                    throw DRCError.invalidInput(
                        "Native DRC antenna rule \(rule.id) requires antennaModel and antennaLayers."
                    )
                }
            }
            if let antennaLayers = rule.antennaLayers {
                guard !antennaLayers.isEmpty else {
                    throw DRCError.invalidInput("Native DRC rule \(rule.id) has an empty antennaLayers list.")
                }
                var antennaLayerIDs: Set<String> = []
                for antennaLayer in antennaLayers {
                    guard !antennaLayer.layer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw DRCError.invalidInput("Native DRC rule \(rule.id) has an empty antenna layer.")
                    }
                    guard antennaLayerIDs.insert(antennaLayer.layer).inserted else {
                        throw DRCError.invalidInput(
                            "Native DRC rule \(rule.id) repeats antenna layer \(antennaLayer.layer)."
                        )
                    }
                    guard antennaLayer.ratioGate.isFinite, antennaLayer.ratioGate > 0 else {
                        throw DRCError.invalidInput(
                            "Native DRC rule \(rule.id) has an invalid antenna ratioGate for \(antennaLayer.layer)."
                        )
                    }
                    if antennaLayer.measurement == .sidewall {
                        guard let thickness = antennaLayer.thickness,
                              thickness.isFinite,
                              thickness > 0 else {
                            throw DRCError.invalidInput(
                                "Native DRC rule \(rule.id) requires a positive sidewall thickness for \(antennaLayer.layer)."
                            )
                        }
                    }
                    if antennaLayer.diffusionRatioPerArea != nil,
                       antennaLayer.diffusionRatioConstant == nil {
                        throw DRCError.invalidInput(
                            "Native DRC rule \(rule.id) requires diffusionRatioConstant when diffusionRatioPerArea is set."
                        )
                    }
                    if let thickness = antennaLayer.thickness {
                        guard thickness.isFinite, thickness > 0 else {
                            throw DRCError.invalidInput(
                                "Native DRC rule \(rule.id) has an invalid antenna thickness for \(antennaLayer.layer)."
                            )
                        }
                    }
                    let correctionValues = [
                        antennaLayer.diffusionRatioConstant,
                        antennaLayer.diffusionRatioPerArea,
                    ].compactMap { $0 }
                    guard correctionValues.allSatisfy(\.isFinite), correctionValues.allSatisfy({ $0 >= 0 }) else {
                        throw DRCError.invalidInput(
                            "Native DRC rule \(rule.id) has invalid antenna diffusion correction values."
                        )
                    }
                }
                guard antennaLayers.contains(where: { $0.layer == rule.layer }) else {
                    throw DRCError.invalidInput(
                        "Native DRC rule \(rule.id) must include its stage layer \(rule.layer) in antennaLayers."
                    )
                }
                guard let stageLayer = antennaLayers.first(where: { $0.layer == rule.layer }),
                      rule.value == stageLayer.ratioGate else {
                    throw DRCError.invalidInput(
                        "Native DRC antenna rule \(rule.id) value must equal its stage-layer ratioGate."
                    )
                }
            }
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
        logPath: String,
        startedAt: Date,
        inputArtifacts: [ArtifactReference]
    ) throws -> DRCExecutionResult {
        let result = makeResult(
            layout: layout,
            diagnostics: diagnostics,
            logPath: logPath,
            timeoutSeconds: request.options.timeoutSeconds
        )
        return DRCExecutionResult(
            request: request,
            result: result,
            repairHintGeometry: repairHintGeometry(from: layout),
            provenance: try DRCExecutionProvenance.make(
                request: request,
                result: result,
                inputArtifacts: inputArtifacts,
                invocation: ExecutionInvocation.inProcess(
                    entryPoint: "NativeDRCBackend.run"
                ),
                startedAt: startedAt,
                completedAt: Date()
            )
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

    private func evaluate(
        layout: NativeDRCLayout,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> [DRCDiagnostic] {
        let context = EvaluationContext(layout: layout)
        var diagnostics: [DRCDiagnostic] = []
        for rule in layout.rules {
            try await checkCancellation(cancellationCheck)
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
        return try evaluateMaximumAntennaRatio(
            rule: rule,
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
