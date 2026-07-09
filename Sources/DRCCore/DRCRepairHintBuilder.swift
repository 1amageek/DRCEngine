import Foundation

public struct DRCRepairHintBuilder: Sendable {
    public init() {}

    public func build(reportURL: URL) throws -> DRCRepairHintReport {
        do {
            let data = try Data(contentsOf: reportURL)
            let result = try JSONDecoder().decode(DRCExecutionResult.self, from: data)
            return build(result: result, reportURL: reportURL)
        } catch {
            throw DRCError.invalidInput("Unable to load DRC repair hint input: \(error.localizedDescription)")
        }
    }

    public func build(
        result: DRCExecutionResult,
        reportURL: URL? = nil
    ) -> DRCRepairHintReport {
        let activeDiagnostics = result.result.diagnostics.enumerated().filter {
            $0.element.severity == .error && !$0.element.isWaived
        }
        let embeddedLayoutContext = RepairHintLayoutContext.load(from: result.repairHintGeometry)
        let needsLayoutContext = activeDiagnostics.contains { pair in
            requiresLayoutContext(for: pair.element)
        }
        let fileLayoutContext: RepairHintLayoutContextLoadResult
        if embeddedLayoutContext.context == nil && needsLayoutContext {
            fileLayoutContext = RepairHintLayoutContext.load(from: result.request.layoutURL)
        } else {
            fileLayoutContext = RepairHintLayoutContextLoadResult(context: nil)
        }
        let layoutContext = embeddedLayoutContext.context ?? fileLayoutContext.context
        var reportDiagnostics = embeddedLayoutContext.diagnostics
        if embeddedLayoutContext.context == nil && needsLayoutContext {
            reportDiagnostics.append(contentsOf: fileLayoutContext.diagnostics)
        }
        var unsupportedIndexes: [Int] = []
        let hints = activeDiagnostics.compactMap { pair -> DRCRepairHint? in
            let index = pair.offset
            let diagnostic = pair.element
            guard let hint = repairHint(
                for: diagnostic,
                sourceDiagnosticIndex: index,
                layoutContext: layoutContext
            ) else {
                unsupportedIndexes.append(index)
                reportDiagnostics.append(unsupportedDiagnostic(
                    for: diagnostic,
                    sourceDiagnosticIndex: index,
                    layoutContext: layoutContext
                ))
                return nil
            }
            return hint
        }
        return DRCRepairHintReport(
            status: hints.isEmpty && !activeDiagnostics.isEmpty ? "no-actionable-hints" : "ready",
            reportURL: reportURL ?? result.reportURL,
            backendID: result.result.backendID,
            topCell: result.request.topCell,
            activeDiagnosticCount: activeDiagnostics.count,
            hintCount: hints.count,
            hints: hints,
            unsupportedDiagnosticIndexes: unsupportedIndexes,
            diagnostics: reportDiagnostics
        )
    }

    private func repairHint(
        for diagnostic: DRCDiagnostic,
        sourceDiagnosticIndex: Int,
        layoutContext: RepairHintLayoutContext?
    ) -> DRCRepairHint? {
        let operationID = operationID(for: diagnostic)
        guard operationID != "layout-command-replay" else {
            return nil
        }

        let normalizedKind = normalizedKind(for: diagnostic)
        var numericParameters = baseNumericParameters(for: diagnostic)
        var stringParameters = baseStringParameters(for: diagnostic)
        if operationTargetsExistingShape(operationID),
           let shapeID = targetShapeID(
                for: diagnostic,
                operationID: operationID,
                normalizedKind: normalizedKind
           ) {
            stringParameters["shapeID"] = shapeID
        }
        if operationID == "layout.add-rect", let region = diagnostic.region {
            let rect = addRectGeometry(for: diagnostic, region: region)
            numericParameters["originX"] = rect.x
            numericParameters["originY"] = rect.y
            numericParameters["width"] = rect.width
            numericParameters["height"] = rect.height
            if shouldFillEnclosedArea(for: normalizedKind) {
                stringParameters["fillPurpose"] = "minimumEnclosedArea"
                if let measured = diagnostic.measured {
                    numericParameters["enclosedArea"] = measured
                }
                if let required = diagnostic.required {
                    numericParameters["requiredEnclosedArea"] = required
                }
            }
            if shouldFillMinimumDensity(for: normalizedKind) {
                stringParameters["fillPurpose"] = "minimumDensity"
                numericParameters["densityWindowX"] = region.x
                numericParameters["densityWindowY"] = region.y
                numericParameters["densityWindowWidth"] = region.width
                numericParameters["densityWindowHeight"] = region.height
                numericParameters["densityWindowArea"] = region.width * region.height
                if let measured = diagnostic.measured {
                    numericParameters["measuredDensity"] = measured
                }
                if let required = diagnostic.required {
                    numericParameters["requiredDensity"] = required
                }
                if let fillArea = densityFillArea(for: diagnostic, region: region) {
                    numericParameters["targetFillArea"] = fillArea
                }
            }
        }
        if operationID == "layout.add-via" {
            addViaParameters(
                diagnostic: diagnostic,
                numericParameters: &numericParameters,
                stringParameters: &stringParameters
            )
        }
        if operationID == "layout.resize-shape" {
            if let extensionGuidance = minimumExtensionResizeGuidance(
                for: diagnostic,
                layoutContext: layoutContext
            ) {
                numericParameters["deltaMinX"] = extensionGuidance.deltaMinX
                numericParameters["deltaMinY"] = extensionGuidance.deltaMinY
                numericParameters["deltaMaxX"] = extensionGuidance.deltaMaxX
                numericParameters["deltaMaxY"] = extensionGuidance.deltaMaxY
                numericParameters["requiredExtension"] = extensionGuidance.requiredExtension
                numericParameters["measuredNegativeSideExtension"] = extensionGuidance.negativeSideExtension
                numericParameters["measuredPositiveSideExtension"] = extensionGuidance.positiveSideExtension
                numericParameters["negativeSideExtensionDelta"] = extensionGuidance.negativeSideDelta
                numericParameters["positiveSideExtensionDelta"] = extensionGuidance.positiveSideDelta
                stringParameters["shapeID"] = extensionGuidance.extendingShapeID
                stringParameters["extendingShapeID"] = extensionGuidance.extendingShapeID
                stringParameters["enclosedShapeID"] = extensionGuidance.enclosedShapeID
                stringParameters["extensionDirection"] = extensionGuidance.direction
                stringParameters["extensionAxis"] = extensionGuidance.direction
            } else {
                let growth = resizeGrowth(for: diagnostic)
                numericParameters["deltaMinX"] = 0
                numericParameters["deltaMinY"] = 0
                numericParameters["deltaMaxX"] = growth.width
                numericParameters["deltaMaxY"] = growth.height
            }
        }
        if operationID == "layout.translate-shape" {
            numericParameters["minimumSeparationDelta"] = max(0, (diagnostic.required ?? 0) - (diagnostic.measured ?? 0))
            guard let translation = translationGuidance(for: diagnostic, layoutContext: layoutContext) else {
                return nil
            }
            numericParameters["deltaX"] = translation.deltaX
            numericParameters["deltaY"] = translation.deltaY
            numericParameters["translationDistance"] = translation.distance
            stringParameters["translationAxis"] = translation.axis
            stringParameters["translationReason"] = translation.reason
            stringParameters["anchorShapeID"] = translation.anchorShapeID
            if let overlapWidth = translation.overlapWidth {
                numericParameters["overlapWidth"] = overlapWidth
            }
            if let overlapHeight = translation.overlapHeight {
                numericParameters["overlapHeight"] = overlapHeight
            }
            if let overlapArea = translation.overlapArea {
                numericParameters["overlapArea"] = overlapArea
            }
        }
        if operationID == "layout.split-shape" {
            stringParameters["axis"] = splitAxis(for: diagnostic)
        }

        return DRCRepairHint(
            hintID: hintID(for: diagnostic, index: sourceDiagnosticIndex),
            sourceDiagnosticIndex: sourceDiagnosticIndex,
            operationID: operationID,
            confidence: confidence(for: operationID, diagnostic: diagnostic),
            ruleID: diagnostic.ruleID,
            kind: diagnostic.kind,
            layer: diagnostic.layer,
            targetShapeIDs: diagnostic.relatedShapeIDs,
            relatedViaIDs: diagnostic.relatedViaIDs,
            relatedNetIDs: diagnostic.relatedNetIDs,
            region: diagnostic.region,
            measured: diagnostic.measured,
            required: diagnostic.required,
            numericParameters: numericParameters,
            stringParameters: stringParameters,
            verificationGates: verificationGates(for: operationID),
            rationale: rationale(for: operationID, diagnostic: diagnostic)
        )
    }

    private func operationID(for diagnostic: DRCDiagnostic) -> String {
        let normalized = normalizedKind(for: diagnostic)
        if normalized.contains("cut") || normalized.contains("via") {
            return "layout.add-via"
        }
        if shouldFillEnclosedArea(for: normalized), diagnostic.region != nil {
            return "layout.add-rect"
        }
        if shouldFillMinimumDensity(for: normalized), diagnostic.region != nil {
            return "layout.add-rect"
        }
        if shouldFillNotch(for: normalized), diagnostic.region != nil {
            return "layout.add-rect"
        }
        if shouldTranslateOverlap(for: normalized), diagnostic.relatedShapeIDs.count >= 2 {
            return "layout.translate-shape"
        }
        if shouldDeleteShape(for: normalized), !diagnostic.relatedShapeIDs.isEmpty {
            return "layout.delete-shape"
        }
        if shouldSplitShape(for: normalized), !diagnostic.relatedShapeIDs.isEmpty {
            return "layout.split-shape"
        }
        if normalized.contains("width")
            || normalized.contains("area")
            || normalized.contains("enclosure")
            || normalized.contains("extension") {
            if !diagnostic.relatedShapeIDs.isEmpty {
                return "layout.resize-shape"
            }
            if diagnostic.region != nil {
                return "layout.add-rect"
            }
        }
        if !diagnostic.relatedShapeIDs.isEmpty {
            return "layout.translate-shape"
        }
        return "layout-command-replay"
    }

    private func requiresLayoutContext(for diagnostic: DRCDiagnostic) -> Bool {
        operationID(for: diagnostic) == "layout.translate-shape"
    }

    private func unsupportedDiagnostic(
        for diagnostic: DRCDiagnostic,
        sourceDiagnosticIndex: Int,
        layoutContext: RepairHintLayoutContext?
    ) -> DRCRepairHintDiagnostic {
        let operationID = operationID(for: diagnostic)
        if operationID == "layout.translate-shape" {
            if layoutContext == nil {
                return DRCRepairHintDiagnostic(
                    severity: "warning",
                    code: "drc.repair_hint.geometry_context_missing",
                    message: "Repair hint translation requires layout geometry, but no readable geometry context was available.",
                    sourceDiagnosticIndex: sourceDiagnosticIndex,
                    suggestedActions: [
                        "rerun-drc-with-repair-hint-geometry",
                        "provide-readable-native-layout-json"
                    ]
                )
            }
            return DRCRepairHintDiagnostic(
                severity: "warning",
                code: "drc.repair_hint.translation_guidance_unavailable",
                message: "Repair hint translation could not determine an executable delta from the diagnostic geometry.",
                sourceDiagnosticIndex: sourceDiagnosticIndex,
                suggestedActions: [
                    "inspect-related-shape-ids",
                    "provide-overlapping-or-spaced-shape-geometry"
                ]
            )
        }
        return DRCRepairHintDiagnostic(
            severity: "warning",
            code: "drc.repair_hint.unsupported_diagnostic",
            message: "The DRC diagnostic does not map to an executable layout repair operation.",
            sourceDiagnosticIndex: sourceDiagnosticIndex,
            suggestedActions: [
                "inspect-drc-diagnostic-kind",
                "add-repair-hint-mapping"
            ]
        )
    }

    private func baseNumericParameters(for diagnostic: DRCDiagnostic) -> [String: Double] {
        var parameters: [String: Double] = [:]
        if let measured = diagnostic.measured {
            parameters["measured"] = measured
        }
        if let required = diagnostic.required {
            parameters["required"] = required
        }
        if let count = diagnostic.count {
            parameters["count"] = Double(count)
        }
        return parameters
    }

    private func baseStringParameters(for diagnostic: DRCDiagnostic) -> [String: String] {
        var parameters: [String: String] = [:]
        if let ruleID = diagnostic.ruleID {
            parameters["ruleID"] = ruleID
        }
        if let kind = diagnostic.kind {
            parameters["kind"] = kind
        }
        if let layer = diagnostic.layer {
            parameters["layer"] = layer
        }
        if let unit = diagnostic.unit {
            parameters["unit"] = unit
        }
        return parameters
    }

    private func addViaParameters(
        diagnostic: DRCDiagnostic,
        numericParameters: inout [String: Double],
        stringParameters: inout [String: String]
    ) {
        if let region = diagnostic.region {
            numericParameters["positionX"] = region.x + region.width / 2.0
            numericParameters["positionY"] = region.y + region.height / 2.0
        }
        if let measured = diagnostic.measured,
           let required = diagnostic.required {
            numericParameters["existingCutCount"] = measured
            numericParameters["requiredCutCount"] = required
            numericParameters["missingCutCount"] = max(0, required - measured)
        }
        if let layer = diagnostic.layer,
           stringParameters["viaDefinitionID"] == nil {
            stringParameters["viaDefinitionID"] = inferredViaDefinitionID(from: layer)
            stringParameters["cutLayer"] = layer
        }
        if !diagnostic.relatedViaIDs.isEmpty {
            stringParameters["existingCutIDs"] = diagnostic.relatedViaIDs.joined(separator: ",")
        }
    }

    private func inferredViaDefinitionID(from layer: String) -> String {
        let trimmed = layer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "VIA1"
        }
        return trimmed.uppercased()
    }

    private func hintID(for diagnostic: DRCDiagnostic, index: Int) -> String {
        let rule = diagnostic.ruleID ?? diagnostic.kind ?? "diagnostic"
        return "drc-repair-\(index)-\(sanitize(rule))"
    }

    private func sanitize(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(Character(scalar)) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "diagnostic" : collapsed
    }

    private func normalizedKind(for diagnostic: DRCDiagnostic) -> String {
        [diagnostic.kind, diagnostic.ruleID, diagnostic.message]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    private func shouldDeleteShape(for normalizedKind: String) -> Bool {
        if normalizedKind.contains("density") {
            return normalizedKind.contains("max") || normalizedKind.contains("maximum")
        }
        return normalizedKind.contains("excess")
            || normalizedKind.contains("redundant")
            || normalizedKind.contains("floatingfill")
            || normalizedKind.contains("floating-fill")
    }

    private func shouldFillNotch(for normalizedKind: String) -> Bool {
        normalizedKind.contains("notch")
            || normalizedKind.contains("slot")
    }

    private func shouldFillEnclosedArea(for normalizedKind: String) -> Bool {
        normalizedKind.contains("enclosedarea")
            || normalizedKind.contains("enclosed area")
    }

    private func shouldFillMinimumDensity(for normalizedKind: String) -> Bool {
        normalizedKind.contains("minimumdensity")
            || normalizedKind.contains("minimum density")
            || (normalizedKind.contains("min") && normalizedKind.contains("density"))
    }

    private func shouldTranslateOverlap(for normalizedKind: String) -> Bool {
        normalizedKind.contains("differentnetoverlap")
            || normalizedKind.contains("different-net overlap")
            || normalizedKind.contains("forbiddenoverlap")
            || normalizedKind.contains("forbidden overlap")
            || normalizedKind.contains("overlap short")
    }

    private func addRectGeometry(
        for diagnostic: DRCDiagnostic,
        region: DRCRegion
    ) -> DRCRegion {
        guard shouldFillMinimumDensity(for: normalizedKind(for: diagnostic)),
              let fillArea = densityFillArea(for: diagnostic, region: region),
              fillArea > 0,
              region.width > 0,
              region.height > 0 else {
            return region
        }
        let clampedFillArea = min(fillArea, region.width * region.height)
        let side = sqrt(clampedFillArea)
        let width = min(region.width, max(side, 0))
        let height = min(region.height, width > 0 ? clampedFillArea / width : region.height)
        return DRCRegion(
            x: region.x + (region.width - width) / 2.0,
            y: region.y + (region.height - height) / 2.0,
            width: width,
            height: height
        )
    }

    private func densityFillArea(
        for diagnostic: DRCDiagnostic,
        region: DRCRegion
    ) -> Double? {
        guard let measured = diagnostic.measured,
              let required = diagnostic.required else {
            return nil
        }
        let missingDensity = max(0, required - measured)
        return missingDensity * region.width * region.height
    }

    private func shouldSplitShape(for normalizedKind: String) -> Bool {
        normalizedKind.contains("notch")
            || normalizedKind.contains("slot")
            || normalizedKind.contains("minstep")
            || normalizedKind.contains("minimumstep")
            || normalizedKind.contains("jog")
    }

    private func operationTargetsExistingShape(_ operationID: String) -> Bool {
        operationID == "layout.translate-shape"
            || operationID == "layout.resize-shape"
            || operationID == "layout.delete-shape"
            || operationID == "layout.split-shape"
    }

    private func targetShapeID(
        for diagnostic: DRCDiagnostic,
        operationID: String,
        normalizedKind: String
    ) -> String? {
        if operationID == "layout.resize-shape",
           normalizedKind.contains("extension"),
           diagnostic.relatedShapeIDs.count >= 2 {
            return diagnostic.relatedShapeIDs[1]
        }
        return diagnostic.relatedShapeIDs.first
    }

    private func splitAxis(for diagnostic: DRCDiagnostic) -> String {
        let normalized = normalizedKind(for: diagnostic)
        if normalized.contains("horizontal") || normalized.contains("y-") || normalized.contains("y_") {
            return "horizontal"
        }
        return "vertical"
    }

    private func translationGuidance(
        for diagnostic: DRCDiagnostic,
        layoutContext: RepairHintLayoutContext?
    ) -> RepairHintTranslation? {
        guard let layoutContext,
              diagnostic.relatedShapeIDs.count >= 2,
              let moving = layoutContext.rectangle(id: diagnostic.relatedShapeIDs[0]),
              let anchor = layoutContext.rectangle(id: diagnostic.relatedShapeIDs[1]) else {
            return nil
        }
        let normalized = normalizedKind(for: diagnostic)
        if normalized.contains("overlap") {
            return overlapTranslation(moving: moving, anchor: anchor)
        }
        return spacingTranslation(diagnostic: diagnostic, moving: moving, anchor: anchor)
    }

    private func spacingTranslation(
        diagnostic: DRCDiagnostic,
        moving: RepairHintRectangle,
        anchor: RepairHintRectangle
    ) -> RepairHintTranslation? {
        let measured = diagnostic.measured ?? moving.spacing(to: anchor)
        let required = diagnostic.required ?? measured
        let missing = max(0, required - measured)
        guard missing > 0 else {
            return nil
        }

        if moving.xMax <= anchor.xMin && moving.overlapsY(with: anchor) {
            return RepairHintTranslation(
                deltaX: -missing,
                deltaY: 0,
                axis: "horizontal",
                distance: missing,
                reason: "minimumSpacing",
                anchorShapeID: anchor.id
            )
        }
        if anchor.xMax <= moving.xMin && moving.overlapsY(with: anchor) {
            return RepairHintTranslation(
                deltaX: missing,
                deltaY: 0,
                axis: "horizontal",
                distance: missing,
                reason: "minimumSpacing",
                anchorShapeID: anchor.id
            )
        }
        if moving.yMax <= anchor.yMin && moving.overlapsX(with: anchor) {
            return RepairHintTranslation(
                deltaX: 0,
                deltaY: -missing,
                axis: "vertical",
                distance: missing,
                reason: "minimumSpacing",
                anchorShapeID: anchor.id
            )
        }
        if anchor.yMax <= moving.yMin && moving.overlapsX(with: anchor) {
            return RepairHintTranslation(
                deltaX: 0,
                deltaY: missing,
                axis: "vertical",
                distance: missing,
                reason: "minimumSpacing",
                anchorShapeID: anchor.id
            )
        }

        let centerDX = moving.centerX - anchor.centerX
        let centerDY = moving.centerY - anchor.centerY
        let length = sqrt(centerDX * centerDX + centerDY * centerDY)
        guard length > 0 else {
            return nil
        }
        return RepairHintTranslation(
            deltaX: missing * centerDX / length,
            deltaY: missing * centerDY / length,
            axis: "diagonal",
            distance: missing,
            reason: "minimumSpacing",
            anchorShapeID: anchor.id
        )
    }

    private func overlapTranslation(
        moving: RepairHintRectangle,
        anchor: RepairHintRectangle
    ) -> RepairHintTranslation? {
        guard let overlap = moving.overlap(with: anchor),
              overlap.width > 0,
              overlap.height > 0 else {
            return nil
        }
        let overlapArea = overlap.width * overlap.height
        if overlap.width <= overlap.height {
            let direction = moving.centerX <= anchor.centerX ? -1.0 : 1.0
            return RepairHintTranslation(
                deltaX: direction * overlap.width,
                deltaY: 0,
                axis: "horizontal",
                distance: overlap.width,
                reason: "overlapSeparation",
                anchorShapeID: anchor.id,
                overlapWidth: overlap.width,
                overlapHeight: overlap.height,
                overlapArea: overlapArea
            )
        }
        let direction = moving.centerY <= anchor.centerY ? -1.0 : 1.0
        return RepairHintTranslation(
            deltaX: 0,
            deltaY: direction * overlap.height,
            axis: "vertical",
            distance: overlap.height,
            reason: "overlapSeparation",
            anchorShapeID: anchor.id,
            overlapWidth: overlap.width,
            overlapHeight: overlap.height,
            overlapArea: overlapArea
        )
    }

    private func resizeGrowth(for diagnostic: DRCDiagnostic) -> (width: Double, height: Double) {
        let measured = diagnostic.measured ?? 0
        let required = diagnostic.required ?? measured
        let missing = max(0.0, required - measured)
        guard missing > 0 else {
            return (width: 0.0, height: 0.0)
        }
        let normalized = normalizedKind(for: diagnostic)
        if normalized.contains("area") || normalized.contains("enclosure") || normalized.contains("extension") {
            if normalized.contains("area") {
                let measuredSide = sqrt(max(0.0, measured))
                let requiredSide = sqrt(max(0.0, required))
                let sideGrowth = max(0.0, requiredSide - measuredSide)
                return (width: sideGrowth, height: sideGrowth)
            }
            return (width: missing / 2.0, height: missing / 2.0)
        }
        return (width: missing, height: 0.0)
    }

    private func minimumExtensionResizeGuidance(
        for diagnostic: DRCDiagnostic,
        layoutContext: RepairHintLayoutContext?
    ) -> RepairHintExtensionResize? {
        guard normalizedKind(for: diagnostic).contains("extension"),
              diagnostic.relatedShapeIDs.count >= 2,
              let required = diagnostic.required,
              required > 0,
              let direction = extensionDirection(for: diagnostic),
              let layoutContext,
              let enclosed = layoutContext.rectangle(id: diagnostic.relatedShapeIDs[0]),
              let extending = layoutContext.rectangle(id: diagnostic.relatedShapeIDs[1]) else {
            return nil
        }

        switch direction {
        case "horizontal":
            let negativeSideExtension = enclosed.xMin - extending.xMin
            let positiveSideExtension = extending.xMax - enclosed.xMax
            let negativeSideDelta = max(0, required - negativeSideExtension)
            let positiveSideDelta = max(0, required - positiveSideExtension)
            return RepairHintExtensionResize(
                enclosedShapeID: enclosed.id,
                extendingShapeID: extending.id,
                direction: direction,
                requiredExtension: required,
                negativeSideExtension: negativeSideExtension,
                positiveSideExtension: positiveSideExtension,
                negativeSideDelta: negativeSideDelta,
                positiveSideDelta: positiveSideDelta,
                deltaMinX: -negativeSideDelta,
                deltaMinY: 0,
                deltaMaxX: positiveSideDelta,
                deltaMaxY: 0
            )
        case "vertical":
            let negativeSideExtension = enclosed.yMin - extending.yMin
            let positiveSideExtension = extending.yMax - enclosed.yMax
            let negativeSideDelta = max(0, required - negativeSideExtension)
            let positiveSideDelta = max(0, required - positiveSideExtension)
            return RepairHintExtensionResize(
                enclosedShapeID: enclosed.id,
                extendingShapeID: extending.id,
                direction: direction,
                requiredExtension: required,
                negativeSideExtension: negativeSideExtension,
                positiveSideExtension: positiveSideExtension,
                negativeSideDelta: negativeSideDelta,
                positiveSideDelta: positiveSideDelta,
                deltaMinX: 0,
                deltaMinY: -negativeSideDelta,
                deltaMaxX: 0,
                deltaMaxY: positiveSideDelta
            )
        default:
            return nil
        }
    }

    private func extensionDirection(for diagnostic: DRCDiagnostic) -> String? {
        let text = [diagnostic.rawLine, diagnostic.message, diagnostic.kind, diagnostic.ruleID]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        if text.contains("direction=horizontal") || text.contains(" horizontal") || text.contains("horizontally") {
            return "horizontal"
        }
        if text.contains("direction=vertical") || text.contains(" vertical") || text.contains("vertically") {
            return "vertical"
        }
        return nil
    }

    private func confidence(for operationID: String, diagnostic: DRCDiagnostic) -> String {
        switch operationID {
        case "layout.resize-shape":
            diagnostic.relatedShapeIDs.isEmpty ? "low" : "high"
        case "layout.translate-shape":
            diagnostic.relatedShapeIDs.count >= 2 ? "medium" : "low"
        case "layout.add-rect":
            diagnostic.region == nil ? "low" : "medium"
        case "layout.delete-shape":
            "medium"
        case "layout.add-via":
            diagnostic.region == nil || diagnostic.layer == nil ? "low" : "medium"
        case "layout.split-shape":
            "low"
        default:
            "low"
        }
    }

    private func verificationGates(for operationID: String) -> [String] {
        var gates = ["native-drc", "artifact-integrity"]
        if operationID == "layout.translate-shape"
            || operationID == "layout.resize-shape"
            || operationID == "layout.delete-shape"
            || operationID == "layout.split-shape"
            || operationID == "layout.add-rect"
            || operationID == "layout.add-via" {
            gates.append("native-lvs")
        }
        return gates
    }

    private func rationale(for operationID: String, diagnostic: DRCDiagnostic) -> String {
        let rule = diagnostic.ruleID ?? diagnostic.kind ?? "DRC diagnostic"
        let measured = stringValue(diagnostic.measured)
        let required = stringValue(diagnostic.required)
        return "\(rule) maps to \(operationID) because the diagnostic exposes \(diagnostic.relatedShapeIDs.count) related shape ID(s), measured=\(measured), required=\(required)."
    }

    private func stringValue(_ value: Double?) -> String {
        guard let value else {
            return "n/a"
        }
        return "\(value)"
    }
}

private struct RepairHintLayoutContext: Sendable {
    private let rectanglesByID: [String: RepairHintRectangle]

    init(rectangles: [RepairHintRectangle]) {
        var rectanglesByID: [String: RepairHintRectangle] = [:]
        for rectangle in rectangles {
            rectanglesByID[rectangle.id] = rectangle
        }
        self.rectanglesByID = rectanglesByID
    }

    static func load(from url: URL) -> RepairHintLayoutContextLoadResult {
        guard url.pathExtension.lowercased() == "json" else {
            return RepairHintLayoutContextLoadResult(context: nil)
        }
        do {
            let data = try Data(contentsOf: url)
            let layout = try JSONDecoder().decode(RepairHintNativeLayout.self, from: data)
            return RepairHintLayoutContextLoadResult(context: RepairHintLayoutContext(rectangles: layout.rectangles))
        } catch {
            return RepairHintLayoutContextLoadResult(
                context: nil,
                diagnostics: [
                    DRCRepairHintDiagnostic(
                        severity: "warning",
                        code: "drc.repair_hint.layout_context_unreadable",
                        message: "Unable to load repair-hint layout geometry: \(error.localizedDescription)",
                        source: url.path(percentEncoded: false),
                        suggestedActions: [
                            "provide-readable-native-layout-json",
                            "rerun-drc-with-repair-hint-geometry"
                        ]
                    )
                ]
            )
        }
    }

    static func load(from context: DRCRepairHintGeometryContext?) -> RepairHintLayoutContextLoadResult {
        guard let context else {
            return RepairHintLayoutContextLoadResult(context: nil)
        }
        return RepairHintLayoutContextLoadResult(context: RepairHintLayoutContext(rectangles: context.rectangles.map {
            RepairHintRectangle(
                id: $0.id,
                xMin: $0.xMin,
                yMin: $0.yMin,
                xMax: $0.xMax,
                yMax: $0.yMax
            )
        }))
    }

    func rectangle(id: String) -> RepairHintRectangle? {
        rectanglesByID[id]
    }
}

private struct RepairHintLayoutContextLoadResult: Sendable {
    let context: RepairHintLayoutContext?
    let diagnostics: [DRCRepairHintDiagnostic]

    init(
        context: RepairHintLayoutContext?,
        diagnostics: [DRCRepairHintDiagnostic] = []
    ) {
        self.context = context
        self.diagnostics = diagnostics
    }
}

private struct RepairHintNativeLayout: Decodable {
    let rectangles: [RepairHintRectangle]
}

private struct RepairHintRectangle: Sendable, Decodable {
    let id: String
    let xMin: Double
    let yMin: Double
    let xMax: Double
    let yMax: Double

    var centerX: Double {
        (xMin + xMax) / 2.0
    }

    var centerY: Double {
        (yMin + yMax) / 2.0
    }

    func spacing(to other: RepairHintRectangle) -> Double {
        let xGap = max(0, max(other.xMin - xMax, xMin - other.xMax))
        let yGap = max(0, max(other.yMin - yMax, yMin - other.yMax))
        if xGap == 0 {
            return yGap
        }
        if yGap == 0 {
            return xGap
        }
        return sqrt(xGap * xGap + yGap * yGap)
    }

    func overlapsX(with other: RepairHintRectangle) -> Bool {
        max(xMin, other.xMin) < min(xMax, other.xMax)
    }

    func overlapsY(with other: RepairHintRectangle) -> Bool {
        max(yMin, other.yMin) < min(yMax, other.yMax)
    }

    func overlap(with other: RepairHintRectangle) -> (width: Double, height: Double)? {
        let width = min(xMax, other.xMax) - max(xMin, other.xMin)
        let height = min(yMax, other.yMax) - max(yMin, other.yMin)
        guard width > 0, height > 0 else {
            return nil
        }
        return (width, height)
    }
}

private struct RepairHintTranslation: Sendable {
    let deltaX: Double
    let deltaY: Double
    let axis: String
    let distance: Double
    let reason: String
    let anchorShapeID: String
    let overlapWidth: Double?
    let overlapHeight: Double?
    let overlapArea: Double?

    init(
        deltaX: Double,
        deltaY: Double,
        axis: String,
        distance: Double,
        reason: String,
        anchorShapeID: String,
        overlapWidth: Double? = nil,
        overlapHeight: Double? = nil,
        overlapArea: Double? = nil
    ) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.axis = axis
        self.distance = distance
        self.reason = reason
        self.anchorShapeID = anchorShapeID
        self.overlapWidth = overlapWidth
        self.overlapHeight = overlapHeight
        self.overlapArea = overlapArea
    }
}

private struct RepairHintExtensionResize: Sendable {
    let enclosedShapeID: String
    let extendingShapeID: String
    let direction: String
    let requiredExtension: Double
    let negativeSideExtension: Double
    let positiveSideExtension: Double
    let negativeSideDelta: Double
    let positiveSideDelta: Double
    let deltaMinX: Double
    let deltaMinY: Double
    let deltaMaxX: Double
    let deltaMaxY: Double
}
