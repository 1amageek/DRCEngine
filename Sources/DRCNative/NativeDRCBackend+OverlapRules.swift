import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateExactOverlap(
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

    func evaluateDifferentNetOverlap(
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

    func evaluateForbiddenOverlap(
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

    func requiredSecondaryLayer(for rule: NativeDRCRule, kind: String) throws -> String {
        guard let secondaryLayer = rule.secondaryLayer,
              !secondaryLayer.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) requires secondaryLayer for \(kind)")
        }
        return secondaryLayer
    }
}
