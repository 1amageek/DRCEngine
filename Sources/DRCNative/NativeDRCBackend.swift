import Foundation
import DRCCore

public struct NativeDRCBackend: DRCBackend {
    public let backendID = "native"
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        let data: Data
        do {
            data = try Data(contentsOf: request.layoutURL)
        } catch {
            throw DRCError.invalidInput("Native DRC could not read layout: \(error.localizedDescription)")
        }

        let layout: NativeDRCLayout
        do {
            layout = try decoder.decode(NativeDRCLayout.self, from: data)
        } catch {
            throw DRCError.invalidInput("Native DRC expects canonical layout JSON: \(error.localizedDescription)")
        }
        guard layout.topCell == request.topCell else {
            throw DRCError.invalidInput("Requested top cell \(request.topCell) does not match layout top cell \(layout.topCell)")
        }

        let diagnostics = try evaluate(layout: layout)
        let logPath: String
        if let workingDirectory = request.workingDirectory {
            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )
            let logURL = workingDirectory.appending(path: "drc-native-\(UUID().uuidString).log")
            let log = (["\(diagnostics.count) violation(s) on \(request.topCell)"]
                + diagnostics.map { "\($0.severity): \($0.message)" })
                .joined(separator: "\n") + "\n"
            try log.write(to: logURL, atomically: true, encoding: .utf8)
            logPath = logURL.path(percentEncoded: false)
        } else {
            logPath = ""
        }
        let result = DRCResult(
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
                timeoutSeconds: request.options.timeoutSeconds
            )
        )
        return DRCExecutionResult(
            request: request,
            result: result,
            repairHintGeometry: repairHintGeometry(from: layout)
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

    private func evaluate(layout: NativeDRCLayout) throws -> [DRCDiagnostic] {
        var diagnostics: [DRCDiagnostic] = []
        let rectanglesByLayer = Dictionary(grouping: layout.rectangles, by: \.layer)

        for rule in layout.rules {
            switch rule.kind {
            case .manufacturingGrid:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: try evaluateManufacturingGrid(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumWidth:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: evaluateMinimumWidth(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumSpacing:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                if let secondaryLayer = rule.secondaryLayer,
                   secondaryLayer != rule.layer {
                    diagnostics.append(contentsOf: try evaluateMinimumSpacing(
                        rule: rule,
                        primaryRectangles: rectangles,
                        secondaryRectangles: rectanglesByLayer[secondaryLayer, default: []],
                        unit: layout.unit
                    ))
                } else {
                    diagnostics.append(contentsOf: try evaluateMinimumSpacing(rule: rule, rectangles: rectangles, unit: layout.unit))
                }
            case .forbiddenOverlap:
                let secondaryLayer = try requiredSecondaryLayer(for: rule, kind: "forbiddenOverlap")
                diagnostics.append(contentsOf: try evaluateForbiddenOverlap(
                    rule: rule,
                    primaryRectangles: rectanglesByLayer[rule.layer, default: []],
                    secondaryRectangles: rectanglesByLayer[secondaryLayer, default: []],
                    secondaryLayer: secondaryLayer,
                    unit: layout.unit
                ))
            case .exactOverlap:
                let secondaryLayer = try requiredSecondaryLayer(for: rule, kind: "exactOverlap")
                diagnostics.append(contentsOf: try evaluateExactOverlap(
                    rule: rule,
                    primaryRectangles: rectanglesByLayer[rule.layer, default: []],
                    secondaryRectangles: rectanglesByLayer[secondaryLayer, default: []],
                    secondaryLayer: secondaryLayer,
                    unit: layout.unit
                ))
            case .differentNetOverlap:
                diagnostics.append(contentsOf: try evaluateDifferentNetOverlap(
                    rule: rule,
                    rectangles: rectanglesByLayer[rule.layer, default: []],
                    unit: layout.unit
                ))
            case .minimumEndOfLineSpacing:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: try evaluateMinimumEndOfLineSpacing(
                    rule: rule,
                    rectangles: rectangles,
                    unit: layout.unit
                ))
            case .minimumArea:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: evaluateMinimumArea(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .maximumDensity:
                guard let rectangles = rectanglesByLayer[rule.layer],
                      !rectangles.isEmpty else { continue }
                diagnostics.append(contentsOf: try evaluateMaximumDensity(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumDensity:
                guard let rectangles = rectanglesByLayer[rule.layer],
                      !rectangles.isEmpty else { continue }
                diagnostics.append(contentsOf: try evaluateMinimumDensity(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumNotch:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: try evaluateMinimumNotch(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumEnclosedArea:
                guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
                diagnostics.append(contentsOf: try evaluateMinimumEnclosedArea(rule: rule, rectangles: rectangles, unit: layout.unit))
            case .minimumCut:
                diagnostics.append(contentsOf: try evaluateMinimumCut(
                    rule: rule,
                    cutRectangles: rectanglesByLayer[rule.layer, default: []],
                    rectanglesByLayer: rectanglesByLayer
                ))
            case .maximumAntennaRatio:
                let conductorLayers = try antennaConductorLayers(for: rule)
                let conductorLayerSet = Set(conductorLayers)
                let rectangles = layout.rectangles.filter { conductorLayerSet.contains($0.layer) }
                guard !rectangles.isEmpty else { continue }
                diagnostics.append(contentsOf: try evaluateMaximumAntennaRatio(
                    rule: rule,
                    conductorRectangles: rectangles,
                    allRectangles: layout.rectangles,
                    unit: layout.unit
                ))
            case .minimumEnclosure:
                guard let enclosedLayer = rule.enclosedLayer else {
                    throw DRCError.invalidInput("Rule \(rule.id) requires enclosedLayer for minimumEnclosure")
                }
                diagnostics.append(contentsOf: evaluateMinimumEnclosure(
                    rule: rule,
                    enclosingRectangles: rectanglesByLayer[rule.layer, default: []],
                    enclosedRectangles: rectanglesByLayer[enclosedLayer, default: []],
                    enclosedLayer: enclosedLayer,
                    unit: layout.unit
                ))
            case .minimumExtension:
                guard let enclosedLayer = rule.enclosedLayer else {
                    throw DRCError.invalidInput("Rule \(rule.id) requires enclosedLayer for minimumExtension")
                }
                diagnostics.append(contentsOf: try evaluateMinimumExtension(
                    rule: rule,
                    extendingRectangles: rectanglesByLayer[rule.layer, default: []],
                    enclosedRectangles: rectanglesByLayer[enclosedLayer, default: []],
                    enclosedLayer: enclosedLayer,
                    unit: layout.unit
                ))
            }
        }

        return diagnostics
    }

    private func evaluateExactOverlap(
        rule: NativeDRCRule,
        primaryRectangles: [NativeDRCRectangle],
        secondaryRectangles: [NativeDRCRectangle],
        secondaryLayer: String,
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite exact-overlap tolerance")
        }
        var diagnostics: [DRCDiagnostic] = []
        for primary in primaryRectangles {
            if secondaryRectangles.contains(where: { exactBounds(primary, matches: $0, tolerance: rule.value) }) {
                continue
            }
            let closestSecondary = closestExactOverlapCandidate(to: primary, in: secondaryRectangles)
            let measured = closestSecondary.map { boundsMismatch(primary, $0) }
            let relatedShapeIDs = closestSecondary.map { [primary.id, $0.id] } ?? [primary.id]
            diagnostics.append(DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(primary.id) on \(primary.layer) does not have exact overlap on \(secondaryLayer)",
                ruleID: rule.id,
                count: 1,
                kind: "exactOverlap",
                layer: "\(rule.layer),\(secondaryLayer)",
                measured: measured,
                required: rule.value,
                unit: unit,
                region: primary.region,
                relatedShapeIDs: relatedShapeIDs,
                relatedNetIDs: relatedNetIDs(primary.netID, closestSecondary?.netID),
                suggestedFix: "Create or resize a \(secondaryLayer) rectangle so its bounds match \(primary.id) within \(rule.value) \(unit).",
                rawLine: "EXACT_OVERLAP layers=\(rule.layer),\(secondaryLayer) primary=\(primary.id)"
            ))
        }
        return diagnostics
    }

    private func exactBounds(
        _ first: NativeDRCRectangle,
        matches second: NativeDRCRectangle,
        tolerance: Double
    ) -> Bool {
        boundsMismatch(first, second) <= tolerance
    }

    private func boundsMismatch(
        _ first: NativeDRCRectangle,
        _ second: NativeDRCRectangle
    ) -> Double {
        [
            abs(first.xMin - second.xMin),
            abs(first.yMin - second.yMin),
            abs(first.xMax - second.xMax),
            abs(first.yMax - second.yMax),
        ].max() ?? 0
    }

    private func closestExactOverlapCandidate(
        to primary: NativeDRCRectangle,
        in secondaryRectangles: [NativeDRCRectangle]
    ) -> NativeDRCRectangle? {
        secondaryRectangles.min { first, second in
            boundsMismatch(primary, first) < boundsMismatch(primary, second)
        }
    }

    private func evaluateDifferentNetOverlap(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite overlap threshold")
        }
        var diagnostics: [DRCDiagnostic] = []
        for firstIndex in rectangles.indices {
            for secondIndex in rectangles.indices where secondIndex > firstIndex {
                let first = rectangles[firstIndex]
                let second = rectangles[secondIndex]
                guard let firstNetID = first.netID,
                      let secondNetID = second.netID,
                      firstNetID != secondNetID,
                      let overlap = first.intersectionRegion(with: second) else {
                    continue
                }
                let overlapArea = overlap.width * overlap.height
                guard overlapArea > rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Layer \(rule.layer) has different-net overlap between \(first.id) and \(second.id)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "differentNetOverlap",
                    layer: rule.layer,
                    measured: overlapArea,
                    required: rule.value,
                    unit: "\(unit)^2",
                    region: overlap,
                    relatedShapeIDs: [first.id, second.id],
                    relatedNetIDs: relatedNetIDs(firstNetID, secondNetID),
                    suggestedFix: "Separate the \(rule.layer) shapes or assign a shared net if the overlap is intentional.",
                    rawLine: "DIFFERENT_NET_OVERLAP layer=\(rule.layer) ids=\(first.id),\(second.id) nets=\(firstNetID),\(secondNetID)"
                ))
            }
        }
        return diagnostics
    }

    private func evaluateForbiddenOverlap(
        rule: NativeDRCRule,
        primaryRectangles: [NativeDRCRectangle],
        secondaryRectangles: [NativeDRCRectangle],
        secondaryLayer: String,
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite overlap threshold")
        }
        var diagnostics: [DRCDiagnostic] = []
        for first in primaryRectangles {
            for second in secondaryRectangles {
                guard let overlap = first.intersectionRegion(with: second) else {
                    continue
                }
                let overlapArea = overlap.width * overlap.height
                guard overlapArea > rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Rectangle \(first.id) on \(first.layer) overlaps forbidden \(secondaryLayer) rectangle \(second.id)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "forbiddenOverlap",
                    layer: "\(rule.layer),\(secondaryLayer)",
                    measured: overlapArea,
                    required: rule.value,
                    unit: "\(unit)^2",
                    region: overlap,
                    relatedShapeIDs: [first.id, second.id],
                    relatedNetIDs: relatedNetIDs(first.netID, second.netID),
                    suggestedFix: "Remove the \(rule.layer)/\(secondaryLayer) overlap or move one shape so the overlap area is at most \(rule.value) \(unit)^2.",
                    rawLine: "FORBIDDEN_OVERLAP layers=\(rule.layer),\(secondaryLayer) ids=\(first.id),\(second.id)"
                ))
            }
        }
        return diagnostics
    }

    private func requiredSecondaryLayer(for rule: NativeDRCRule, kind: String) throws -> String {
        guard let secondaryLayer = rule.secondaryLayer,
              !secondaryLayer.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) requires secondaryLayer for \(kind)")
        }
        return secondaryLayer
    }

    private func evaluateMinimumWidth(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) -> [DRCDiagnostic] {
        rectangles.compactMap { rectangle in
            let measuredWidth = min(rectangle.width, rectangle.height)
            guard measuredWidth < rule.value else {
                return nil
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(rectangle.id) on \(rectangle.layer) violates minimum width \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumWidth",
                layer: rectangle.layer,
                measured: measuredWidth,
                required: rule.value,
                unit: unit,
                region: rectangle.region,
                relatedShapeIDs: [rectangle.id],
                suggestedFix: "Increase the narrow dimension to at least \(rule.value) \(unit).",
                rawLine: "MIN_WIDTH layer=\(rectangle.layer) id=\(rectangle.id)"
            )
        }
    }

    private func evaluateManufacturingGrid(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite manufacturing grid")
        }
        return rectangles.compactMap { rectangle in
            let coordinates = [
                ("xMin", rectangle.xMin),
                ("yMin", rectangle.yMin),
                ("xMax", rectangle.xMax),
                ("yMax", rectangle.yMax),
            ]
            let offsets = coordinates.map { name, value in
                (name: name, offset: gridOffset(value, grid: rule.value))
            }
            let offGridOffsets = offsets.filter { $0.offset > 1e-9 }
            guard !offGridOffsets.isEmpty else {
                return nil
            }
            let measuredOffset = offGridOffsets.map(\.offset).max() ?? 0
            let coordinateNames = offGridOffsets.map(\.name).joined(separator: ",")
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(rectangle.id) on \(rectangle.layer) has coordinates off manufacturing grid \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "manufacturingGrid",
                layer: rectangle.layer,
                measured: measuredOffset,
                required: rule.value,
                unit: unit,
                region: rectangle.region,
                relatedShapeIDs: [rectangle.id],
                relatedNetIDs: rectangle.netID.map { [$0] } ?? [],
                suggestedFix: "Snap \(coordinateNames) for shape \(rectangle.id) to the \(rule.value) \(unit) manufacturing grid.",
                rawLine: "MANUFACTURING_GRID layer=\(rectangle.layer) id=\(rectangle.id) coordinates=\(coordinateNames)"
            )
        }
    }

    private func gridOffset(_ value: Double, grid: Double) -> Double {
        let quotient = value / grid
        let nearest = quotient.rounded() * grid
        return abs(value - nearest)
    }

    func relatedNetIDs(_ first: String?, _ second: String?) -> [String] {
        Array(Set([first, second].compactMap { $0 })).sorted()
    }

    private func evaluateMinimumArea(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) -> [DRCDiagnostic] {
        rectangles.compactMap { rectangle in
            let measuredArea = rectangle.area
            guard measuredArea < rule.value else {
                return nil
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(rectangle.id) on \(rectangle.layer) violates minimum area \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumArea",
                layer: rectangle.layer,
                measured: measuredArea,
                required: rule.value,
                unit: "\(unit)^2",
                region: rectangle.region,
                relatedShapeIDs: [rectangle.id],
                suggestedFix: "Increase the shape area to at least \(rule.value) \(unit)^2.",
                rawLine: "MIN_AREA layer=\(rectangle.layer) id=\(rectangle.id)"
            )
        }
    }

    private func evaluateMaximumDensity(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite density threshold")
        }
        return try densityWindows(rule: rule, rectangles: rectangles).compactMap { window in
            let clippedRectangles = rectangles.compactMap { rectangle in
                rectangle.clippedDensityRectangle(to: window)
            }
            let coveredArea = unionArea(of: clippedRectangles)
            let density = coveredArea / (window.width * window.height)
            guard density > rule.value else {
                return nil
            }
            let relatedShapeIDs = rectangles.filter { $0.intersectionArea(with: window) > 0 }.map(\.id)
            return DRCDiagnostic(
                severity: .error,
                message: "Layer \(rule.layer) exceeds maximum density \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "maximumDensity",
                layer: rule.layer,
                measured: density,
                required: rule.value,
                unit: "ratio",
                region: window,
                relatedShapeIDs: relatedShapeIDs,
                suggestedFix: "Reduce \(rule.layer) coverage in the density window below \(rule.value).",
                rawLine: "MAX_DENSITY layer=\(rule.layer) window=\(window.x),\(window.y),\(window.width),\(window.height)"
            )
        }
    }

    private func evaluateMinimumDensity(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite density threshold")
        }
        return try densityWindows(rule: rule, rectangles: rectangles).compactMap { window in
            let clippedRectangles = rectangles.compactMap { rectangle in
                rectangle.clippedDensityRectangle(to: window)
            }
            let coveredArea = unionArea(of: clippedRectangles)
            let density = coveredArea / (window.width * window.height)
            guard density < rule.value else {
                return nil
            }
            let relatedShapeIDs = rectangles.filter { $0.intersectionArea(with: window) > 0 }.map(\.id)
            return DRCDiagnostic(
                severity: .error,
                message: "Layer \(rule.layer) is below minimum density \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumDensity",
                layer: rule.layer,
                measured: density,
                required: rule.value,
                unit: "ratio",
                region: window,
                relatedShapeIDs: relatedShapeIDs,
                suggestedFix: "Increase \(rule.layer) coverage in the density window to at least \(rule.value).",
                rawLine: "MIN_DENSITY layer=\(rule.layer) window=\(window.x),\(window.y),\(window.width),\(window.height)"
            )
        }
    }

    private func evaluateMinimumNotch(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite notch threshold")
        }
        var diagnostics: [DRCDiagnostic] = []
        for firstIndex in rectangles.indices {
            for secondIndex in rectangles.index(after: firstIndex)..<rectangles.endIndex {
                let first = rectangles[firstIndex]
                let second = rectangles[secondIndex]
                diagnostics.append(contentsOf: evaluateHorizontalMinimumNotch(
                    rule: rule,
                    first: first,
                    second: second,
                    rectangles: rectangles,
                    unit: unit
                ))
                diagnostics.append(contentsOf: evaluateVerticalMinimumNotch(
                    rule: rule,
                    first: first,
                    second: second,
                    rectangles: rectangles,
                    unit: unit
                ))
            }
        }
        return diagnostics
    }

    private func evaluateHorizontalMinimumNotch(
        rule: NativeDRCRule,
        first: NativeDRCRectangle,
        second: NativeDRCRectangle,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) -> [DRCDiagnostic] {
        let ordered = first.xMax <= second.xMin ? (left: first, right: second) : (left: second, right: first)
        let gap = ordered.right.xMin - ordered.left.xMax
        let yMin = max(ordered.left.yMin, ordered.right.yMin)
        let yMax = min(ordered.left.yMax, ordered.right.yMax)
        guard gap > 0,
              gap < rule.value,
              yMax > yMin else {
            return []
        }

        let bridgeIntervals = rectangles.compactMap { rectangle -> NotchBridgeInterval? in
            guard rectangle.id != ordered.left.id,
                  rectangle.id != ordered.right.id,
                  rectangle.layer == rule.layer,
                  rectangle.xMin <= ordered.left.xMax,
                  rectangle.xMax >= ordered.right.xMin else {
                return nil
            }
            let lower = max(rectangle.yMin, yMin)
            let upper = min(rectangle.yMax, yMax)
            guard upper > lower else {
                return nil
            }
            return NotchBridgeInterval(interval: NotchInterval(lower: lower, upper: upper), shapeID: rectangle.id)
        }
        guard !bridgeIntervals.isEmpty else {
            return []
        }

        return uncoveredIntervals(
            in: NotchInterval(lower: yMin, upper: yMax),
            covered: bridgeIntervals.map(\.interval)
        ).map { interval in
            let bridgeShapeIDs = Array(Set(bridgeIntervals.map(\.shapeID))).sorted()
            return DRCDiagnostic(
                severity: .error,
                message: "Layer \(rule.layer) violates minimum notch \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumNotch",
                layer: rule.layer,
                measured: gap,
                required: rule.value,
                unit: unit,
                region: DRCRegion(x: ordered.left.xMax, y: interval.lower, width: gap, height: interval.length),
                relatedShapeIDs: [ordered.left.id, ordered.right.id] + bridgeShapeIDs,
                suggestedFix: "Widen the internal notch on \(rule.layer) to at least \(rule.value) \(unit) or fill it.",
                rawLine: "MIN_NOTCH layer=\(rule.layer) ids=\(ordered.left.id),\(ordered.right.id)"
            )
        }
    }

    private func evaluateVerticalMinimumNotch(
        rule: NativeDRCRule,
        first: NativeDRCRectangle,
        second: NativeDRCRectangle,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) -> [DRCDiagnostic] {
        let ordered = first.yMax <= second.yMin ? (bottom: first, top: second) : (bottom: second, top: first)
        let gap = ordered.top.yMin - ordered.bottom.yMax
        let xMin = max(ordered.bottom.xMin, ordered.top.xMin)
        let xMax = min(ordered.bottom.xMax, ordered.top.xMax)
        guard gap > 0,
              gap < rule.value,
              xMax > xMin else {
            return []
        }

        let bridgeIntervals = rectangles.compactMap { rectangle -> NotchBridgeInterval? in
            guard rectangle.id != ordered.bottom.id,
                  rectangle.id != ordered.top.id,
                  rectangle.layer == rule.layer,
                  rectangle.yMin <= ordered.bottom.yMax,
                  rectangle.yMax >= ordered.top.yMin else {
                return nil
            }
            let lower = max(rectangle.xMin, xMin)
            let upper = min(rectangle.xMax, xMax)
            guard upper > lower else {
                return nil
            }
            return NotchBridgeInterval(interval: NotchInterval(lower: lower, upper: upper), shapeID: rectangle.id)
        }
        guard !bridgeIntervals.isEmpty else {
            return []
        }

        return uncoveredIntervals(
            in: NotchInterval(lower: xMin, upper: xMax),
            covered: bridgeIntervals.map(\.interval)
        ).map { interval in
            let bridgeShapeIDs = Array(Set(bridgeIntervals.map(\.shapeID))).sorted()
            return DRCDiagnostic(
                severity: .error,
                message: "Layer \(rule.layer) violates minimum notch \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumNotch",
                layer: rule.layer,
                measured: gap,
                required: rule.value,
                unit: unit,
                region: DRCRegion(x: interval.lower, y: ordered.bottom.yMax, width: interval.length, height: gap),
                relatedShapeIDs: [ordered.bottom.id, ordered.top.id] + bridgeShapeIDs,
                suggestedFix: "Widen the internal notch on \(rule.layer) to at least \(rule.value) \(unit) or fill it.",
                rawLine: "MIN_NOTCH layer=\(rule.layer) ids=\(ordered.bottom.id),\(ordered.top.id)"
            )
        }
    }

    private func uncoveredIntervals(in base: NotchInterval, covered intervals: [NotchInterval]) -> [NotchInterval] {
        let merged = mergeIntervals(intervals)
        var uncovered: [NotchInterval] = []
        var cursor = base.lower
        for interval in merged {
            let lower = max(interval.lower, base.lower)
            let upper = min(interval.upper, base.upper)
            guard upper > lower else {
                continue
            }
            if lower > cursor {
                uncovered.append(NotchInterval(lower: cursor, upper: lower))
            }
            cursor = max(cursor, upper)
        }
        if cursor < base.upper {
            uncovered.append(NotchInterval(lower: cursor, upper: base.upper))
        }
        return uncovered.filter { $0.length > 0 }
    }

    private func mergeIntervals(_ intervals: [NotchInterval]) -> [NotchInterval] {
        let sortedIntervals = intervals.sorted { $0.lower < $1.lower }
        var merged: [NotchInterval] = []
        for interval in sortedIntervals {
            guard interval.upper > interval.lower else {
                continue
            }
            if let last = merged.last,
               interval.lower <= last.upper {
                merged[merged.count - 1] = NotchInterval(lower: last.lower, upper: max(last.upper, interval.upper))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private func evaluateMinimumEnclosure(
        rule: NativeDRCRule,
        enclosingRectangles: [NativeDRCRectangle],
        enclosedRectangles: [NativeDRCRectangle],
        enclosedLayer: String,
        unit: String
    ) -> [DRCDiagnostic] {
        enclosedRectangles.compactMap { enclosed in
            let bestCandidate = enclosingRectangles
                .map { enclosing in
                    (rectangle: enclosing, margin: enclosing.enclosureMargin(around: enclosed))
                }
                .max { $0.margin < $1.margin }
            let measured = bestCandidate?.margin ?? 0
            guard measured < rule.value else {
                return nil
            }

            let region = bestCandidate?.rectangle.region.enclosing(enclosed.region) ?? enclosed.region
            var relatedShapeIDs = [enclosed.id]
            if let bestCandidate {
                relatedShapeIDs.append(bestCandidate.rectangle.id)
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(enclosed.id) on \(enclosedLayer) violates \(rule.layer) minimum enclosure \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumEnclosure",
                layer: rule.layer,
                measured: measured,
                required: rule.value,
                unit: unit,
                region: region,
                relatedShapeIDs: relatedShapeIDs,
                suggestedFix: "Expand \(rule.layer) around \(enclosedLayer) to at least \(rule.value) \(unit) on every side.",
                rawLine: "MIN_ENCLOSURE layer=\(rule.layer) enclosedLayer=\(enclosedLayer) id=\(enclosed.id)"
            )
        }
    }

    private func evaluateMinimumExtension(
        rule: NativeDRCRule,
        extendingRectangles: [NativeDRCRectangle],
        enclosedRectangles: [NativeDRCRectangle],
        enclosedLayer: String,
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite extension threshold")
        }
        let direction = try extensionDirection(for: rule)

        return enclosedRectangles.compactMap { enclosed in
            let bestCandidate = extendingRectangles
                .compactMap { extending -> (rectangle: NativeDRCRectangle, measurement: Double)? in
                    guard let measurement = extensionMeasurement(
                        direction: direction,
                        extending: extending,
                        enclosed: enclosed
                    ) else {
                        return nil
                    }
                    return (extending, measurement)
                }
                .max { $0.measurement < $1.measurement }
            let measured = bestCandidate?.measurement ?? 0
            guard measured < rule.value else {
                return nil
            }

            let region = bestCandidate?.rectangle.region.enclosing(enclosed.region) ?? enclosed.region
            var relatedShapeIDs = [enclosed.id]
            let relatedNetIDs: [String]
            if let bestCandidate {
                relatedShapeIDs.append(bestCandidate.rectangle.id)
                relatedNetIDs = self.relatedNetIDs(enclosed.netID, bestCandidate.rectangle.netID)
            } else {
                relatedNetIDs = enclosed.netID.map { [$0] } ?? []
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(enclosed.id) on \(enclosedLayer) violates \(rule.layer) \(direction.rawValue) minimum extension \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumExtension",
                layer: rule.layer,
                measured: measured,
                required: rule.value,
                unit: unit,
                region: region,
                relatedShapeIDs: relatedShapeIDs,
                relatedNetIDs: relatedNetIDs,
                suggestedFix: "Extend \(rule.layer) \(direction.rawValue)ly beyond \(enclosedLayer) by at least \(rule.value) \(unit).",
                rawLine: "MIN_EXTENSION layer=\(rule.layer) enclosedLayer=\(enclosedLayer) direction=\(direction.rawValue) id=\(enclosed.id)"
            )
        }
    }

    private func extensionDirection(for rule: NativeDRCRule) throws -> NativeDRCRule.ExtensionDirection {
        guard let direction = rule.extensionDirection else {
            throw DRCError.invalidInput("Rule \(rule.id) requires extensionDirection for minimumExtension")
        }
        return direction
    }

    private func extensionMeasurement(
        direction: NativeDRCRule.ExtensionDirection,
        extending: NativeDRCRectangle,
        enclosed: NativeDRCRectangle
    ) -> Double? {
        switch direction {
        case .horizontal:
            guard intervalsOverlap(extending.yMin, extending.yMax, enclosed.yMin, enclosed.yMax) else {
                return nil
            }
            return min(enclosed.xMin - extending.xMin, extending.xMax - enclosed.xMax)
        case .vertical:
            guard intervalsOverlap(extending.xMin, extending.xMax, enclosed.xMin, enclosed.xMax) else {
                return nil
            }
            return min(enclosed.yMin - extending.yMin, extending.yMax - enclosed.yMax)
        }
    }

    private func evaluateMinimumEnclosedArea(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite enclosed-area threshold")
        }
        guard rectangles.count >= 4 else {
            return []
        }

        let xCoordinates = Array(Set(rectangles.flatMap { [$0.xMin, $0.xMax] })).sorted()
        let yCoordinates = Array(Set(rectangles.flatMap { [$0.yMin, $0.yMax] })).sorted()
        guard xCoordinates.count >= 2, yCoordinates.count >= 2 else {
            return []
        }

        let xCellCount = xCoordinates.count - 1
        let yCellCount = yCoordinates.count - 1
        var occupied = Array(
            repeating: Array(repeating: false, count: yCellCount),
            count: xCellCount
        )

        for xIndex in 0..<xCellCount {
            for yIndex in 0..<yCellCount {
                let cell = DensityRectangle(
                    xMin: xCoordinates[xIndex],
                    yMin: yCoordinates[yIndex],
                    xMax: xCoordinates[xIndex + 1],
                    yMax: yCoordinates[yIndex + 1]
                )
                occupied[xIndex][yIndex] = rectangles.contains { $0.covers(cell) }
            }
        }

        var visited = Array(
            repeating: Array(repeating: false, count: yCellCount),
            count: xCellCount
        )

        func neighbors(of cell: DRCGridCell) -> [DRCGridCell] {
            [
                DRCGridCell(x: cell.x - 1, y: cell.y),
                DRCGridCell(x: cell.x + 1, y: cell.y),
                DRCGridCell(x: cell.x, y: cell.y - 1),
                DRCGridCell(x: cell.x, y: cell.y + 1),
            ].filter { candidate in
                candidate.x >= 0
                    && candidate.x < xCellCount
                    && candidate.y >= 0
                    && candidate.y < yCellCount
            }
        }

        func floodFillExterior(from start: DRCGridCell) {
            guard !occupied[start.x][start.y], !visited[start.x][start.y] else {
                return
            }
            var stack = [start]
            visited[start.x][start.y] = true
            while let current = stack.popLast() {
                for neighbor in neighbors(of: current) where !occupied[neighbor.x][neighbor.y] && !visited[neighbor.x][neighbor.y] {
                    visited[neighbor.x][neighbor.y] = true
                    stack.append(neighbor)
                }
            }
        }

        for xIndex in 0..<xCellCount {
            floodFillExterior(from: DRCGridCell(x: xIndex, y: 0))
            floodFillExterior(from: DRCGridCell(x: xIndex, y: yCellCount - 1))
        }
        for yIndex in 0..<yCellCount {
            floodFillExterior(from: DRCGridCell(x: 0, y: yIndex))
            floodFillExterior(from: DRCGridCell(x: xCellCount - 1, y: yIndex))
        }

        var diagnostics: [DRCDiagnostic] = []
        for xIndex in 0..<xCellCount {
            for yIndex in 0..<yCellCount where !occupied[xIndex][yIndex] && !visited[xIndex][yIndex] {
                var stack = [DRCGridCell(x: xIndex, y: yIndex)]
                visited[xIndex][yIndex] = true
                var cells: [DRCGridCell] = []
                while let current = stack.popLast() {
                    cells.append(current)
                    for neighbor in neighbors(of: current) where !occupied[neighbor.x][neighbor.y] && !visited[neighbor.x][neighbor.y] {
                        visited[neighbor.x][neighbor.y] = true
                        stack.append(neighbor)
                    }
                }

                let area = cells.reduce(0.0) { partial, cell in
                    let width = xCoordinates[cell.x + 1] - xCoordinates[cell.x]
                    let height = yCoordinates[cell.y + 1] - yCoordinates[cell.y]
                    return partial + width * height
                }
                guard area < rule.value else {
                    continue
                }

                let minX = cells.map { xCoordinates[$0.x] }.min() ?? 0
                let maxX = cells.map { xCoordinates[$0.x + 1] }.max() ?? 0
                let minY = cells.map { yCoordinates[$0.y] }.min() ?? 0
                let maxY = cells.map { yCoordinates[$0.y + 1] }.max() ?? 0
                let region = DRCRegion(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                let relatedShapeIDs = rectangles
                    .filter { $0.touches(region) }
                    .map(\.id)
                    .sorted()

                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Layer \(rule.layer) contains enclosed area smaller than \(rule.value)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumEnclosedArea",
                    layer: rule.layer,
                    measured: area,
                    required: rule.value,
                    unit: "\(unit)^2",
                    region: region,
                    relatedShapeIDs: relatedShapeIDs,
                    suggestedFix: "Open the enclosed area or enlarge it to at least \(rule.value) \(unit)^2.",
                    rawLine: "MIN_ENCLOSED_AREA layer=\(rule.layer) region=\(region.x),\(region.y),\(region.width),\(region.height)"
                ))
            }
        }
        return diagnostics
    }

    private func evaluateMinimumCut(
        rule: NativeDRCRule,
        cutRectangles: [NativeDRCRectangle],
        rectanglesByLayer: [String: [NativeDRCRectangle]]
    ) throws -> [DRCDiagnostic] {
        let requiredCutCount = try minimumCutCount(for: rule)
        guard let lowerLayer = rule.lowerLayer,
              !lowerLayer.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) requires lowerLayer for minimumCut")
        }
        guard let upperLayer = rule.upperLayer,
              !upperLayer.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) requires upperLayer for minimumCut")
        }
        guard lowerLayer != upperLayer else {
            throw DRCError.invalidInput("Rule \(rule.id) requires distinct lowerLayer and upperLayer")
        }
        guard !cutRectangles.isEmpty else {
            return []
        }

        let lowerRectangles = rectanglesByLayer[lowerLayer, default: []]
        let upperRectangles = rectanglesByLayer[upperLayer, default: []]
        guard !lowerRectangles.isEmpty, !upperRectangles.isEmpty else {
            return []
        }

        var diagnostics: [DRCDiagnostic] = []
        for lower in lowerRectangles {
            guard let netID = lower.netID else {
                continue
            }
            for upper in upperRectangles where upper.netID == netID && lower.overlaps(upper) {
                let connectingCuts = cutRectangles.filter { cut in
                    cut.netID == netID && cut.overlaps(lower) && cut.overlaps(upper)
                }
                guard !connectingCuts.isEmpty,
                      connectingCuts.count < requiredCutCount else {
                    continue
                }

                let relatedShapeIDs = [lower.id, upper.id] + connectingCuts.map(\.id)
                let region = relatedShapeIDs
                    .compactMap { shapeID in
                        ([lower, upper] + connectingCuts).first { $0.id == shapeID }?.region
                    }
                    .reduce(into: lower.region.enclosing(upper.region)) { partial, region in
                        partial = partial.enclosing(region)
                    }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Net \(netID) between \(lowerLayer) and \(upperLayer) has \(connectingCuts.count) \(rule.layer) cut(s), below minimum \(requiredCutCount)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumCut",
                    layer: rule.layer,
                    measured: Double(connectingCuts.count),
                    required: Double(requiredCutCount),
                    unit: "cut",
                    region: region,
                    relatedShapeIDs: relatedShapeIDs,
                    relatedViaIDs: connectingCuts.map(\.id),
                    relatedNetIDs: [netID],
                    suggestedFix: "Add \(requiredCutCount - connectingCuts.count) \(rule.layer) cut(s) for net \(netID) or relax the minimum cut rule.",
                    rawLine: "MIN_CUT layer=\(rule.layer) lowerLayer=\(lowerLayer) upperLayer=\(upperLayer) net=\(netID) cuts=\(connectingCuts.map(\.id).joined(separator: ","))"
                ))
            }
        }
        return diagnostics
    }

    private func minimumCutCount(for rule: NativeDRCRule) throws -> Int {
        guard rule.value.isFinite,
              rule.value >= 1,
              rule.value.rounded(.towardZero) == rule.value else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive integer minimum cut count")
        }
        return Int(rule.value)
    }

    private func densityWindows(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle]
    ) throws -> [DRCRegion] {
        let bounds = rectangles.map(\.region).reduce(into: rectangles[0].region) { partial, region in
            partial = partial.enclosing(region)
        }
        guard let windowWidth = rule.windowWidth,
              let windowHeight = rule.windowHeight else {
            return [bounds]
        }
        guard windowWidth.isFinite, windowHeight.isFinite, windowWidth > 0, windowHeight > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires positive finite density window dimensions")
        }
        let stepX = rule.stepX ?? windowWidth
        let stepY = rule.stepY ?? windowHeight
        guard stepX.isFinite, stepY.isFinite, stepX > 0, stepY > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires positive finite density window steps")
        }

        let originX = rule.windowOriginX ?? bounds.x
        let originY = rule.windowOriginY ?? bounds.y
        let maxX = bounds.x + bounds.width
        let maxY = bounds.y + bounds.height
        var windows: [DRCRegion] = []
        var y = originY
        while y <= maxY - windowHeight + 0.000000001 {
            var x = originX
            while x <= maxX - windowWidth + 0.000000001 {
                windows.append(DRCRegion(x: x, y: y, width: windowWidth, height: windowHeight))
                x += stepX
            }
            y += stepY
        }
        if windows.isEmpty {
            windows.append(DRCRegion(x: originX, y: originY, width: windowWidth, height: windowHeight))
        }
        return windows
    }

    func unionArea(of rectangles: [DensityRectangle]) -> Double {
        let xCoordinates = Array(Set(rectangles.flatMap { [$0.xMin, $0.xMax] })).sorted()
        guard xCoordinates.count >= 2 else {
            return 0
        }
        var area = 0.0
        for index in 0..<(xCoordinates.count - 1) {
            let xMin = xCoordinates[index]
            let xMax = xCoordinates[index + 1]
            let width = xMax - xMin
            guard width > 0 else {
                continue
            }
            let yIntervals = rectangles.compactMap { rectangle -> (Double, Double)? in
                guard rectangle.xMin < xMax && rectangle.xMax > xMin else {
                    return nil
                }
                return (rectangle.yMin, rectangle.yMax)
            }.sorted { $0.0 < $1.0 }
            area += width * unionLength(of: yIntervals)
        }
        return area
    }

    private func unionLength(of intervals: [(Double, Double)]) -> Double {
        var covered = 0.0
        var current: (Double, Double)?
        for interval in intervals {
            guard interval.1 > interval.0 else {
                continue
            }
            if let existing = current {
                if interval.0 <= existing.1 {
                    current = (existing.0, max(existing.1, interval.1))
                } else {
                    covered += existing.1 - existing.0
                    current = interval
                }
            } else {
                current = interval
            }
        }
        if let current {
            covered += current.1 - current.0
        }
        return covered
    }
}
