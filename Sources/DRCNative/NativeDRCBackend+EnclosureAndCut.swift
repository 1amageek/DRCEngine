import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateMinimumEnclosure(
        rule: NativeDRCRule,
        enclosingRectangles: [NativeDRCRectangle],
        enclosedRectangles: [NativeDRCRectangle],
        enclosedLayer: String,
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite enclosure threshold")
        }
        return enclosedRectangles.compactMap { enclosed -> DRCDiagnostic? in
            let target = enclosureTargetRegion(for: enclosed, margin: rule.value)
            guard !unionCoversEnclosureTarget(target, with: enclosingRectangles) else {
                return nil
            }

            let measured = measuredUnionEnclosureMargin(
                around: enclosed,
                enclosingRectangles: enclosingRectangles,
                requiredMargin: rule.value
            )
            let relatedEnclosingRectangles = relatedEnclosureRectangles(
                enclosingRectangles,
                target: target,
                enclosed: enclosed
            )
            let region = enclosureDiagnosticRegion(
                target: target,
                enclosed: enclosed,
                relatedEnclosingRectangles: relatedEnclosingRectangles
            )
            let relatedShapeIDs = [enclosed.id] + relatedEnclosingRectangles.map(\.id)
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(enclosed.id) on \(enclosedLayer) violates composite \(rule.layer) minimum enclosure \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "minimumEnclosure",
                layer: rule.layer,
                measured: measured,
                required: rule.value,
                unit: unit,
                region: region,
                relatedShapeIDs: relatedShapeIDs,
                relatedNetIDs: relatedEnclosureNetIDs(enclosed: enclosed, enclosing: relatedEnclosingRectangles),
                suggestedFix: "Expand the union of \(rule.layer) geometry around \(enclosedLayer) to at least \(rule.value) \(unit) on every side.",
                rawLine: "MIN_ENCLOSURE layer=\(rule.layer) enclosedLayer=\(enclosedLayer) mode=union id=\(enclosed.id)"
            )
        }
    }

    private func enclosureTargetRegion(
        for enclosed: NativeDRCRectangle,
        margin: Double
    ) -> DRCRegion {
        DRCRegion(
            x: enclosed.xMin - margin,
            y: enclosed.yMin - margin,
            width: enclosed.width + margin * 2,
            height: enclosed.height + margin * 2
        )
    }

    private func unionCoversEnclosureTarget(
        _ target: DRCRegion,
        with enclosingRectangles: [NativeDRCRectangle]
    ) -> Bool {
        guard target.width >= 0, target.height >= 0 else {
            return false
        }
        let targetArea = target.width * target.height
        guard targetArea > 0 else {
            return false
        }
        let clippedRectangles = enclosingRectangles.compactMap { rectangle in
            rectangle.clippedDensityRectangle(to: target)
        }
        guard !clippedRectangles.isEmpty else {
            return false
        }
        let coveredArea = unionArea(of: clippedRectangles)
        return coveredArea + 1e-9 >= targetArea
    }

    private func measuredUnionEnclosureMargin(
        around enclosed: NativeDRCRectangle,
        enclosingRectangles: [NativeDRCRectangle],
        requiredMargin: Double
    ) -> Double {
        guard unionCoversEnclosureTarget(enclosureTargetRegion(for: enclosed, margin: 0), with: enclosingRectangles) else {
            return enclosingRectangles
                .map { $0.enclosureMargin(around: enclosed) }
                .max() ?? 0
        }
        guard requiredMargin > 0 else {
            return 0
        }

        var lowerBound = 0.0
        var upperBound = requiredMargin
        for _ in 0..<48 {
            let midpoint = (lowerBound + upperBound) / 2
            if unionCoversEnclosureTarget(enclosureTargetRegion(for: enclosed, margin: midpoint), with: enclosingRectangles) {
                lowerBound = midpoint
            } else {
                upperBound = midpoint
            }
        }
        return lowerBound
    }

    private func relatedEnclosureRectangles(
        _ enclosingRectangles: [NativeDRCRectangle],
        target: DRCRegion,
        enclosed: NativeDRCRectangle
    ) -> [NativeDRCRectangle] {
        let related = enclosingRectangles.filter { rectangle in
            rectangle.intersectionArea(with: target) > 0
        }
        if !related.isEmpty {
            return related
        }
        return enclosingRectangles
            .map { rectangle in
                (rectangle: rectangle, margin: rectangle.enclosureMargin(around: enclosed))
            }
            .max { $0.margin < $1.margin }
            .map { [$0.rectangle] } ?? []
    }

    private func enclosureDiagnosticRegion(
        target: DRCRegion,
        enclosed: NativeDRCRectangle,
        relatedEnclosingRectangles: [NativeDRCRectangle]
    ) -> DRCRegion {
        relatedEnclosingRectangles
            .map(\.region)
            .reduce(enclosed.region.enclosing(target)) { partial, region in
                partial.enclosing(region)
            }
    }

    private func relatedEnclosureNetIDs(
        enclosed: NativeDRCRectangle,
        enclosing: [NativeDRCRectangle]
    ) -> [String] {
        Array(Set(([enclosed.netID] + enclosing.map(\.netID)).compactMap { $0 })).sorted()
    }

    func evaluateMinimumExtension(
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
            let coverage = extensionCoverageMeasurement(
                direction: direction,
                extendingRectangles: extendingRectangles,
                enclosed: enclosed
            )
            let measured = coverage?.measurement ?? 0
            guard measured < rule.value else {
                return nil
            }

            let relatedExtendingRectangles = coverage?.rectangles ?? []
            let region = relatedExtendingRectangles
                .map(\.region)
                .reduce(enclosed.region) { partial, region in partial.enclosing(region) }
            var relatedShapeIDs = [enclosed.id]
            relatedShapeIDs.append(contentsOf: relatedExtendingRectangles.map(\.id))
            let relatedNetIDs = Array(Set(([enclosed.netID] + relatedExtendingRectangles.map(\.netID)).compactMap { $0 })).sorted()
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

    private func extensionCoverageMeasurement(
        direction: NativeDRCRule.ExtensionDirection,
        extendingRectangles: [NativeDRCRectangle],
        enclosed: NativeDRCRectangle
    ) -> (measurement: Double, rectangles: [NativeDRCRectangle])? {
        let coverageMin: Double
        let coverageMax: Double
        switch direction {
        case .horizontal:
            coverageMin = enclosed.yMin
            coverageMax = enclosed.yMax
        case .vertical:
            coverageMin = enclosed.xMin
            coverageMax = enclosed.xMax
        }
        let candidates = extendingRectangles.compactMap { extending -> ExtensionCoverageCandidate? in
            guard let measurement = extensionMeasurement(
                direction: direction,
                extending: extending,
                enclosed: enclosed
            ) else {
                return nil
            }
            let interval = extensionCoverageInterval(
                direction: direction,
                extending: extending,
                enclosed: enclosed
            )
            let clippedMin = max(interval.lowerBound, coverageMin)
            let clippedMax = min(interval.upperBound, coverageMax)
            guard clippedMin < clippedMax else {
                return nil
            }
            return ExtensionCoverageCandidate(
                rectangle: extending,
                lowerBound: clippedMin,
                upperBound: clippedMax,
                measurement: measurement
            )
        }
        guard !candidates.isEmpty else {
            return nil
        }
        let breakpoints = Array(Set(
            [coverageMin, coverageMax] + candidates.flatMap { [$0.lowerBound, $0.upperBound] }
        )).sorted()
        guard breakpoints.count >= 2 else {
            return nil
        }

        var measured = Double.greatestFiniteMagnitude
        var contributingRectangles: [NativeDRCRectangle] = []
        for index in 0..<(breakpoints.count - 1) {
            let segmentMin = breakpoints[index]
            let segmentMax = breakpoints[index + 1]
            guard segmentMin < segmentMax else {
                continue
            }
            let covering = candidates.filter {
                $0.lowerBound <= segmentMin && $0.upperBound >= segmentMax
            }
            guard let best = covering.max(by: { $0.measurement < $1.measurement }) else {
                return nil
            }
            measured = min(measured, best.measurement)
            contributingRectangles.append(best.rectangle)
        }
        guard measured.isFinite, measured != Double.greatestFiniteMagnitude else {
            return nil
        }
        var seenIDs = Set<String>()
        let uniqueRectangles = contributingRectangles.filter { rectangle in
            seenIDs.insert(rectangle.id).inserted
        }
        return (measured, uniqueRectangles)
    }

    private func extensionCoverageInterval(
        direction: NativeDRCRule.ExtensionDirection,
        extending: NativeDRCRectangle,
        enclosed: NativeDRCRectangle
    ) -> Range<Double> {
        switch direction {
        case .horizontal:
            return max(extending.yMin, enclosed.yMin)..<min(extending.yMax, enclosed.yMax)
        case .vertical:
            return max(extending.xMin, enclosed.xMin)..<min(extending.xMax, enclosed.xMax)
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

    private struct ExtensionCoverageCandidate: Sendable, Hashable {
        let rectangle: NativeDRCRectangle
        let lowerBound: Double
        let upperBound: Double
        let measurement: Double
    }

    func evaluateMinimumCut(
        rule: NativeDRCRule,
        cutRectangles: [NativeDRCRectangle],
        rectanglesByLayer: [String: [NativeDRCRectangle]]
    ) throws -> [DRCDiagnostic] {
        let context = try NativeDRCMinimumCutContext(
            rule: rule,
            cutRectangles: cutRectangles,
            rectanglesByLayer: rectanglesByLayer
        )
        return context.violations().map { violation in
            makeMinimumCutDiagnostic(violation: violation, context: context)
        }
    }

    private func makeMinimumCutDiagnostic(
        violation: NativeDRCMinimumCutViolation,
        context: NativeDRCMinimumCutContext
    ) -> DRCDiagnostic {
        let rule = context.rule
        return DRCDiagnostic(
            severity: .error,
            message: "\(violation.netDescription) between \(context.lowerLayer) and \(context.upperLayer) has \(violation.connectingCuts.count) \(rule.layer) cut(s), below minimum \(context.requiredCutCount)",
            ruleID: rule.id,
            count: 1,
            kind: "minimumCut",
            layer: rule.layer,
            measured: Double(violation.connectingCuts.count),
            required: Double(context.requiredCutCount),
            unit: "cut",
            region: violation.region,
            relatedShapeIDs: violation.relatedShapeIDs,
            relatedViaIDs: violation.relatedViaIDs,
            relatedNetIDs: violation.relatedNetIDs,
            suggestedFix: "Add \(context.requiredCutCount - violation.connectingCuts.count) \(rule.layer) cut(s) for \(violation.fixSubject) or relax the minimum cut rule.",
            rawLine: "MIN_CUT layer=\(rule.layer) lowerLayer=\(context.lowerLayer) upperLayer=\(context.upperLayer) net=\(violation.rawNetValue) cuts=\(violation.relatedViaIDs.joined(separator: ","))"
        )
    }
}
