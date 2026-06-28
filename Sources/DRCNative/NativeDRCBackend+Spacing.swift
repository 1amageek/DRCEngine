import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateMinimumSpacing(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        var diagnostics: [DRCDiagnostic] = []
        for firstIndex in rectangles.indices {
            for secondIndex in rectangles.index(after: firstIndex)..<rectangles.endIndex {
                let first = rectangles[firstIndex]
                let second = rectangles[secondIndex]
                guard spacingRule(rule, appliesTo: first, and: second) else {
                    continue
                }
                guard try wideSpacingRule(rule, appliesTo: first, and: second) else {
                    continue
                }
                guard try spacingGeometry(rule, appliesTo: first, and: second) else {
                    continue
                }
                let spacing = first.spacing(to: second)
                guard !first.overlaps(second),
                      spacing < rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Rectangles \(first.id) and \(second.id) on \(first.layer) violate minimum spacing \(rule.value)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumSpacing",
                    layer: first.layer,
                    measured: spacing,
                    required: rule.value,
                    unit: unit,
                    region: first.region.enclosing(second.region),
                    relatedShapeIDs: [first.id, second.id],
                    suggestedFix: "Move the shapes apart to at least \(rule.value) \(unit) spacing.",
                    rawLine: "MIN_SPACING layer=\(first.layer) netScope=\(spacingNetScope(for: rule).rawValue)\(spacingGeometryRawLineSuffix(for: rule)) ids=\(first.id),\(second.id)"
                ))
            }
        }
        return diagnostics
    }

    func evaluateMinimumSpacing(
        rule: NativeDRCRule,
        primaryRectangles: [NativeDRCRectangle],
        secondaryRectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        var diagnostics: [DRCDiagnostic] = []
        guard let secondaryLayer = rule.secondaryLayer else {
            return diagnostics
        }
        for first in primaryRectangles {
            for second in secondaryRectangles {
                guard spacingRule(rule, appliesTo: first, and: second) else {
                    continue
                }
                guard try wideSpacingRule(rule, appliesTo: first, and: second) else {
                    continue
                }
                guard try spacingGeometry(rule, appliesTo: first, and: second) else {
                    continue
                }
                let spacing = first.spacing(to: second)
                guard spacing < rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Rectangles \(first.id) on \(first.layer) and \(second.id) on \(second.layer) violate minimum layer-pair spacing \(rule.value)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumSpacing",
                    layer: "\(rule.layer),\(secondaryLayer)",
                    measured: spacing,
                    required: rule.value,
                    unit: unit,
                    region: first.region.enclosing(second.region),
                    relatedShapeIDs: [first.id, second.id],
                    suggestedFix: "Move the \(first.layer) and \(second.layer) shapes apart to at least \(rule.value) \(unit) spacing.",
                    rawLine: "MIN_SPACING layers=\(rule.layer),\(secondaryLayer) netScope=\(spacingNetScope(for: rule).rawValue)\(spacingGeometryRawLineSuffix(for: rule)) ids=\(first.id),\(second.id)"
                ))
            }
        }
        return diagnostics
    }

    func evaluateMinimumEndOfLineSpacing(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite end-of-line spacing threshold")
        }
        guard let endOfLineWidth = rule.endOfLineWidth,
              endOfLineWidth.isFinite,
              endOfLineWidth > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite endOfLineWidth")
        }

        let edges = rectangles.flatMap { endOfLineEdges(for: $0, maximumWidth: endOfLineWidth) }
        var diagnostics: [DRCDiagnostic] = []
        for edge in edges {
            for blocker in rectangles where blocker.id != edge.rectangle.id {
                guard spacingRule(rule, appliesTo: edge.rectangle, and: blocker) else {
                    continue
                }
                guard let spacing = endOfLineSpacing(from: edge, to: blocker),
                      spacing < rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "End-of-line edge \(edge.name) on \(edge.rectangle.id) violates minimum spacing \(rule.value) to \(blocker.id)",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumEndOfLineSpacing",
                    layer: rule.layer,
                    measured: spacing,
                    required: rule.value,
                    unit: unit,
                    region: edge.rectangle.region.enclosing(blocker.region),
                    relatedShapeIDs: [edge.rectangle.id, blocker.id],
                    relatedNetIDs: relatedNetIDs(edge.rectangle.netID, blocker.netID),
                    suggestedFix: "Move the end-of-line edge away from nearby \(rule.layer) geometry to at least \(rule.value) \(unit).",
                    rawLine: "MIN_EOL_SPACING layer=\(rule.layer) edge=\(edge.rectangle.id):\(edge.name) netScope=\(spacingNetScope(for: rule).rawValue) blocker=\(blocker.id)"
                ))
            }
        }
        return diagnostics
    }

    private func endOfLineEdges(
        for rectangle: NativeDRCRectangle,
        maximumWidth: Double
    ) -> [EndOfLineEdge] {
        var edges: [EndOfLineEdge] = []
        if rectangle.width <= maximumWidth {
            edges.append(EndOfLineEdge(rectangle: rectangle, name: "bottom", direction: .bottom))
            edges.append(EndOfLineEdge(rectangle: rectangle, name: "top", direction: .top))
        }
        if rectangle.height <= maximumWidth {
            edges.append(EndOfLineEdge(rectangle: rectangle, name: "left", direction: .left))
            edges.append(EndOfLineEdge(rectangle: rectangle, name: "right", direction: .right))
        }
        return edges
    }

    private func endOfLineSpacing(
        from edge: EndOfLineEdge,
        to blocker: NativeDRCRectangle
    ) -> Double? {
        let rectangle = edge.rectangle
        switch edge.direction {
        case .bottom:
            guard blocker.yMax <= rectangle.yMin,
                  intervalsOverlap(rectangle.xMin, rectangle.xMax, blocker.xMin, blocker.xMax) else {
                return nil
            }
            return rectangle.yMin - blocker.yMax
        case .top:
            guard blocker.yMin >= rectangle.yMax,
                  intervalsOverlap(rectangle.xMin, rectangle.xMax, blocker.xMin, blocker.xMax) else {
                return nil
            }
            return blocker.yMin - rectangle.yMax
        case .left:
            guard blocker.xMax <= rectangle.xMin,
                  intervalsOverlap(rectangle.yMin, rectangle.yMax, blocker.yMin, blocker.yMax) else {
                return nil
            }
            return rectangle.xMin - blocker.xMax
        case .right:
            guard blocker.xMin >= rectangle.xMax,
                  intervalsOverlap(rectangle.yMin, rectangle.yMax, blocker.yMin, blocker.yMax) else {
                return nil
            }
            return blocker.xMin - rectangle.xMax
        }
    }

    func intervalsOverlap(
        _ firstLower: Double,
        _ firstUpper: Double,
        _ secondLower: Double,
        _ secondUpper: Double
    ) -> Bool {
        max(firstLower, secondLower) < min(firstUpper, secondUpper)
    }

    private func spacingRule(
        _ rule: NativeDRCRule,
        appliesTo first: NativeDRCRectangle,
        and second: NativeDRCRectangle
    ) -> Bool {
        switch spacingNetScope(for: rule) {
        case .all:
            return true
        case .sameNet:
            guard let firstNet = first.netID,
                  let secondNet = second.netID else {
                return false
            }
            return firstNet == secondNet
        case .differentNet:
            guard let firstNet = first.netID,
                  let secondNet = second.netID else {
                return true
            }
            return firstNet != secondNet
        }
    }

    private func spacingNetScope(for rule: NativeDRCRule) -> NativeDRCRule.SpacingNetScope {
        rule.spacingNetScope ?? .all
    }

    private func wideSpacingRule(
        _ rule: NativeDRCRule,
        appliesTo first: NativeDRCRectangle,
        and second: NativeDRCRectangle
    ) throws -> Bool {
        guard let threshold = rule.wideWidthThreshold else {
            return true
        }
        guard threshold.isFinite, threshold > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite wideWidthThreshold")
        }
        return min(first.width, first.height) >= threshold
            || min(second.width, second.height) >= threshold
    }

    private func spacingGeometry(
        _ rule: NativeDRCRule,
        appliesTo first: NativeDRCRectangle,
        and second: NativeDRCRectangle
    ) throws -> Bool {
        let direction = rule.spacingDirection ?? .either
        let minimumParallelRunLength = try minimumParallelRunLength(for: rule)
        guard rule.spacingDirection != nil || minimumParallelRunLength != nil else {
            return true
        }

        let relations = spacingRelations(between: first, and: second)
        let matchingRelations = relations.filter { relation in
            switch direction {
            case .either:
                return true
            case .horizontal:
                return relation.direction == .horizontal
            case .vertical:
                return relation.direction == .vertical
            }
        }
        guard !matchingRelations.isEmpty else {
            return false
        }
        guard let minimumParallelRunLength else {
            return true
        }
        return matchingRelations.contains { $0.parallelRunLength >= minimumParallelRunLength }
    }

    private func minimumParallelRunLength(for rule: NativeDRCRule) throws -> Double? {
        guard let minimumParallelRunLength = rule.minimumParallelRunLength else {
            return nil
        }
        guard minimumParallelRunLength.isFinite, minimumParallelRunLength > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite minimumParallelRunLength")
        }
        return minimumParallelRunLength
    }

    private func spacingRelations(
        between first: NativeDRCRectangle,
        and second: NativeDRCRectangle
    ) -> [SpacingRelation] {
        let xGap = max(0, max(second.xMin - first.xMax, first.xMin - second.xMax))
        let yGap = max(0, max(second.yMin - first.yMax, first.yMin - second.yMax))
        let xOverlap = min(first.xMax, second.xMax) - max(first.xMin, second.xMin)
        let yOverlap = min(first.yMax, second.yMax) - max(first.yMin, second.yMin)
        var relations: [SpacingRelation] = []
        if yGap == 0, yOverlap > 0 {
            relations.append(SpacingRelation(direction: .horizontal, spacing: xGap, parallelRunLength: yOverlap))
        }
        if xGap == 0, xOverlap > 0 {
            relations.append(SpacingRelation(direction: .vertical, spacing: yGap, parallelRunLength: xOverlap))
        }
        return relations
    }

    private func spacingGeometryRawLineSuffix(for rule: NativeDRCRule) -> String {
        var fields: [String] = []
        if let spacingDirection = rule.spacingDirection {
            fields.append("direction=\(spacingDirection.rawValue)")
        }
        if let minimumParallelRunLength = rule.minimumParallelRunLength {
            fields.append("minPRL=\(minimumParallelRunLength)")
        }
        if let wideWidthThreshold = rule.wideWidthThreshold {
            fields.append("wideWidthThreshold=\(wideWidthThreshold)")
        }
        return fields.isEmpty ? "" : " " + fields.joined(separator: " ")
    }

}
