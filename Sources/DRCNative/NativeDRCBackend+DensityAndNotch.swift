import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateMaximumDensity(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        fallbackRectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite density threshold")
        }
        return try densityWindows(
            rule: rule,
            rectangles: rectangles,
            fallbackRectangles: fallbackRectangles
        ).compactMap { window in
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

    func evaluateMinimumDensity(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        fallbackRectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value >= 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a non-negative finite density threshold")
        }
        return try densityWindows(
            rule: rule,
            rectangles: rectangles,
            fallbackRectangles: fallbackRectangles
        ).compactMap { window in
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

    func evaluateMinimumNotch(
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

    func evaluateMinimumEnclosedArea(
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

    private func densityWindows(
        rule: NativeDRCRule,
        rectangles: [NativeDRCRectangle],
        fallbackRectangles: [NativeDRCRectangle]
    ) throws -> [DRCRegion] {
        let bounds = densityBounds(rectangles: rectangles, fallbackRectangles: fallbackRectangles)
        if bounds == nil && (rule.windowWidth == nil || rule.windowHeight == nil) {
            return []
        }
        guard let windowWidth = rule.windowWidth,
              let windowHeight = rule.windowHeight else {
            return bounds.map { [$0] } ?? []
        }
        guard windowWidth.isFinite, windowHeight.isFinite, windowWidth > 0, windowHeight > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires positive finite density window dimensions")
        }
        let stepX = rule.stepX ?? windowWidth
        let stepY = rule.stepY ?? windowHeight
        guard stepX.isFinite, stepY.isFinite, stepX > 0, stepY > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires positive finite density window steps")
        }

        let originX = rule.windowOriginX ?? bounds?.x ?? 0
        let originY = rule.windowOriginY ?? bounds?.y ?? 0
        let maxX = bounds.map { $0.x + $0.width } ?? (originX + windowWidth)
        let maxY = bounds.map { $0.y + $0.height } ?? (originY + windowHeight)
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

    private func densityBounds(
        rectangles: [NativeDRCRectangle],
        fallbackRectangles: [NativeDRCRectangle]
    ) -> DRCRegion? {
        let boundsRectangles = rectangles.isEmpty ? fallbackRectangles : rectangles
        guard let first = boundsRectangles.first else {
            return nil
        }
        return boundsRectangles.dropFirst().reduce(into: first.region) { partial, rectangle in
            partial = partial.enclosing(rectangle.region)
        }
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
