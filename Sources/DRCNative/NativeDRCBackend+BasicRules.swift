import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateMinimumWidth(
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

    func evaluateMaximumWidth(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        unit: String
    ) -> [DRCDiagnostic] {
        rectangles.compactMap { rectangle in
            let measuredWidth = max(rectangle.width, rectangle.height)
            guard measuredWidth > rule.value else {
                return nil
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(rectangle.id) on \(rectangle.layer) violates maximum width \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "maximumWidth",
                layer: rectangle.layer,
                measured: measuredWidth,
                required: rule.value,
                unit: unit,
                region: rectangle.region,
                relatedShapeIDs: [rectangle.id],
                suggestedFix: "Reduce the longest dimension to at most \(rule.value) \(unit).",
                rawLine: "MAX_WIDTH layer=\(rectangle.layer) id=\(rectangle.id)"
            )
        }
    }

    func evaluateForbiddenLayer(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle]
    ) -> [DRCDiagnostic] {
        rectangles.map { rectangle in
            DRCDiagnostic(
                severity: .error,
                message: "Forbidden marker geometry exists on \(rectangle.layer)",
                ruleID: rule.id,
                count: 1,
                kind: "forbiddenLayer",
                layer: rectangle.layer,
                measured: 1,
                required: 0,
                unit: "shape",
                region: rectangle.region,
                relatedShapeIDs: [rectangle.id],
                relatedNetIDs: rectangle.netID.map { [$0] } ?? [],
                suggestedFix: "Remove or repair the source geometry that produced this forbidden marker.",
                rawLine: "FORBIDDEN_LAYER layer=\(rectangle.layer) id=\(rectangle.id)"
            )
        }
    }

    func evaluateManufacturingGrid(
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

    func evaluateMinimumArea(
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
}
