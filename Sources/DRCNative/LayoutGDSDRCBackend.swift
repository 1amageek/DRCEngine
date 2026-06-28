import Foundation
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech
import LayoutVerify

/// Native DRC on standard mask inputs plus a `LayoutTechDatabase`
/// JSON rule deck. The backend accepts GDSII, OASIS, CIF, and DXF
/// through the shared mask-data import path. The full LayoutVerify check
/// suite runs in-process:
/// width/spacing with merged-region semantics, enclosure, density,
/// antenna, and connectivity. This is the same kernel used by the
/// layout editor's live DRC.
public struct LayoutGDSDRCBackend: DRCBackend {
    public let backendID = "native-gds"

    public init() {}

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        guard let technologyURL = request.technologyURL else {
            throw DRCError.invalidInput(
                "The GDS backend needs a technology rule deck (technologyURL: LayoutTechDatabase JSON)."
            )
        }
        let tech: LayoutTechDatabase
        do {
            tech = try JSONDecoder().decode(
                LayoutTechDatabase.self,
                from: try Data(contentsOf: technologyURL)
            )
        } catch {
            throw DRCError.invalidInput(
                "Could not load technology deck '\(technologyURL.lastPathComponent)': \(error.localizedDescription)"
            )
        }

        let document: LayoutDocument
        do {
            let rawDocument = try Self.loadDocument(
                from: request.layoutURL,
                format: request.layoutFormat,
                tech: tech
            )
            document = Self.materializeDerivedLayers(in: rawDocument, tech: tech)
        } catch {
            throw DRCError.invalidInput(
                "Could not read layout '\(request.layoutURL.lastPathComponent)': \(error.localizedDescription)"
            )
        }
        let topCell = try Self.resolveTopCell(
            in: document,
            requestedTopCell: request.topCell,
            format: request.layoutFormat,
            layoutURL: request.layoutURL
        )

        let violations = LayoutDRCService()
            .run(document: document, tech: tech, cellID: topCell.id)
            .violations
        let diagnostics = violations.map { violation in
            DRCDiagnostic(
                severity: violation.severity == .error ? .error : .warning,
                message: violation.message,
                ruleID: violation.ruleID,
                count: 1,
                kind: violation.kind.rawValue,
                layer: violation.layer.map { "\($0.name):\($0.purpose)" },
                measured: violation.measured,
                required: violation.required,
                unit: violation.unit,
                region: DRCRegion(
                    x: violation.region.origin.x,
                    y: violation.region.origin.y,
                    width: violation.region.size.width,
                    height: violation.region.size.height
                ),
                relatedShapeIDs: violation.shapeIDs.map(\.uuidString),
                relatedViaIDs: violation.viaIDs.map(\.uuidString),
                relatedPinIDs: violation.pinIDs.map(\.uuidString),
                relatedNetIDs: violation.netIDs.map(\.uuidString),
                suggestedFix: violation.suggestedFix,
                rawLine: "\(violation.kind.rawValue) @ (\(violation.region.origin.x), \(violation.region.origin.y)) \(violation.region.size.width)x\(violation.region.size.height)"
            )
        }

        var logPath = ""
        if let workingDirectory = request.workingDirectory {
            let logURL = workingDirectory.appending(path: "drc-native-gds-\(UUID().uuidString).log")
            let log = (["\(violations.count) violation(s) on \(request.topCell)"]
                + diagnostics.map(\.rawLine)).joined(separator: "\n") + "\n"
            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )
            try log.write(to: logURL, atomically: true, encoding: .utf8)
            logPath = logURL.path(percentEncoded: false)
        }

        // `success` means the check RAN; the verdict lives in the
        // diagnostics (DRCResult.passed folds both).
        let result = DRCResult(
            backendID: backendID,
            toolName: "LayoutVerify",
            success: true,
            completed: true,
            logPath: logPath,
            diagnostics: diagnostics,
            provenance: DRCToolProvenance(
                executablePath: "in-process",
                pdkRoot: technologyURL.path(percentEncoded: false),
                rcFilePath: "not-applicable",
                driverScriptPath: "not-applicable",
                timeoutSeconds: request.options.timeoutSeconds
            )
        )
        return DRCExecutionResult(
            request: request,
            result: result,
            repairHintGeometry: Self.repairHintGeometry(from: topCell)
        )
    }

    private struct DerivedLayerCandidate {
        var rect: LayoutRect
        var sourceShapeIDs: [UUID]
        var netID: UUID?
    }

    private static func materializeDerivedLayers(
        in document: LayoutDocument,
        tech: LayoutTechDatabase
    ) -> LayoutDocument {
        guard !tech.derivedLayerRules.isEmpty else { return document }
        var updated = document
        for index in updated.cells.indices {
            updated.cells[index].shapes.removeAll { $0.properties["derivedLayerRuleID"] != nil }
            for rule in tech.derivedLayerRules {
                updated.cells[index].shapes.append(
                    contentsOf: materializedShapes(for: rule, in: updated.cells[index])
                )
            }
        }
        return updated
    }

    private static func materializedShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        switch rule.operation {
        case .intersection:
            return materializedIntersectionShapes(for: rule, in: cell)
        case .union:
            return materializedUnionShapes(for: rule, in: cell)
        case .difference:
            return materializedDifferenceShapes(for: rule, in: cell)
        case .grow:
            return materializedOffsetShapes(for: rule, in: cell, distanceSign: 1)
        case .shrink:
            return materializedOffsetShapes(for: rule, in: cell, distanceSign: -1)
        case .bloatAll:
            return materializedBloatAllShapes(for: rule, in: cell)
        case .cellBoundary:
            return materializedCellBoundaryShapes(for: rule, in: cell)
        }
    }

    private static func materializedIntersectionShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        guard let firstLayer = rule.sourceLayers.first,
              rule.sourceLayers.count >= 2 else {
            return []
        }
        let grouped = Dictionary(grouping: cell.shapes, by: \.layer)
        guard let firstShapes = grouped[firstLayer], !firstShapes.isEmpty else {
            return []
        }
        var candidates = firstShapes.compactMap { shape -> DerivedLayerCandidate? in
            guard let rect = rect(for: shape.geometry) else { return nil }
            return DerivedLayerCandidate(
                rect: rect,
                sourceShapeIDs: [shape.id],
                netID: shape.netID
            )
        }
        guard !candidates.isEmpty else { return [] }

        for layer in rule.sourceLayers.dropFirst() {
            guard let layerShapes = grouped[layer], !layerShapes.isEmpty else {
                return []
            }
            var nextCandidates: [DerivedLayerCandidate] = []
            for candidate in candidates {
                for shape in layerShapes {
                    guard let sourceRect = rect(for: shape.geometry),
                          let rect = intersection(candidate.rect, sourceRect) else {
                        continue
                    }
                    nextCandidates.append(DerivedLayerCandidate(
                        rect: rect,
                        sourceShapeIDs: candidate.sourceShapeIDs + [shape.id],
                        netID: mergedNetID(candidate.netID, shape.netID)
                    ))
                }
            }
            candidates = nextCandidates
            if candidates.isEmpty { return [] }
        }

        return candidates.map { candidate in
            derivedShape(rule: rule, candidate: candidate)
        }
    }

    private static func materializedUnionShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        let grouped = Dictionary(grouping: cell.shapes, by: \.layer)
        return rule.sourceLayers.flatMap { layer -> [LayoutShape] in
            (grouped[layer] ?? []).compactMap { shape in
                guard let rect = rect(for: shape.geometry) else { return nil }
                return derivedShape(
                    rule: rule,
                    candidate: DerivedLayerCandidate(
                        rect: rect,
                        sourceShapeIDs: [shape.id],
                        netID: shape.netID
                    )
                )
            }
        }
    }

    private static func materializedDifferenceShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        guard let firstLayer = rule.sourceLayers.first,
              rule.sourceLayers.count >= 2 else {
            return []
        }
        let grouped = Dictionary(grouping: cell.shapes, by: \.layer)
        guard let baseShapes = grouped[firstLayer], !baseShapes.isEmpty else {
            return []
        }
        let cutterShapes = rule.sourceLayers.dropFirst().flatMap { grouped[$0] ?? [] }
        guard !cutterShapes.isEmpty else {
            return baseShapes.compactMap { shape in
                guard let rect = rect(for: shape.geometry) else { return nil }
                return derivedShape(
                    rule: rule,
                    candidate: DerivedLayerCandidate(
                        rect: rect,
                        sourceShapeIDs: [shape.id],
                        netID: shape.netID
                    )
                )
            }
        }

        var materialized: [LayoutShape] = []
        for baseShape in baseShapes {
            guard let baseRect = rect(for: baseShape.geometry) else { continue }
            var candidates = [
                DerivedLayerCandidate(
                    rect: baseRect,
                    sourceShapeIDs: [baseShape.id],
                    netID: baseShape.netID
                ),
            ]
            for cutterShape in cutterShapes {
                guard let cutterRect = rect(for: cutterShape.geometry) else { continue }
                var nextCandidates: [DerivedLayerCandidate] = []
                for candidate in candidates {
                    let pieces = subtract(cutterRect, from: candidate.rect)
                    nextCandidates.append(contentsOf: pieces.map { piece in
                        DerivedLayerCandidate(
                            rect: piece,
                            sourceShapeIDs: candidate.sourceShapeIDs + [cutterShape.id],
                            netID: candidate.netID
                        )
                    })
                }
                candidates = nextCandidates
                if candidates.isEmpty { break }
            }
            materialized.append(contentsOf: candidates.map { derivedShape(rule: rule, candidate: $0) })
        }
        return materialized
    }

    private static func materializedOffsetShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell,
        distanceSign: Double
    ) -> [LayoutShape] {
        guard let distance = rule.operationDistance,
              distance.isFinite,
              distance >= 0 else {
            return []
        }
        let grouped = Dictionary(grouping: cell.shapes, by: \.layer)
        return rule.sourceLayers.flatMap { layer -> [LayoutShape] in
            (grouped[layer] ?? []).compactMap { shape in
                guard let rect = rect(for: shape.geometry),
                      let offsetRect = offset(rect, by: distance * distanceSign) else {
                    return nil
                }
                return derivedShape(
                    rule: rule,
                    candidate: DerivedLayerCandidate(
                        rect: offsetRect,
                        sourceShapeIDs: [shape.id],
                        netID: shape.netID
                    )
                )
            }
        }
    }

    private static func materializedBloatAllShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        guard let primarySourceLayerCount = rule.primarySourceLayerCount,
              primarySourceLayerCount > 0,
              primarySourceLayerCount < rule.sourceLayers.count else {
            return []
        }

        let grouped = Dictionary(grouping: cell.shapes, by: \.layer)
        let seedLayers = rule.sourceLayers.prefix(primarySourceLayerCount)
        let guideLayers = rule.sourceLayers.dropFirst(primarySourceLayerCount)
        let seedShapes = seedLayers.flatMap { grouped[$0] ?? [] }
        let guideShapes = guideLayers.flatMap { grouped[$0] ?? [] }
        let seedCandidates = seedShapes.compactMap { shape -> DerivedLayerCandidate? in
            guard let rect = rect(for: shape.geometry) else { return nil }
            return DerivedLayerCandidate(rect: rect, sourceShapeIDs: [shape.id], netID: shape.netID)
        }
        let guideCandidates = guideShapes.compactMap { shape -> DerivedLayerCandidate? in
            guard let rect = rect(for: shape.geometry) else { return nil }
            return DerivedLayerCandidate(rect: rect, sourceShapeIDs: [shape.id], netID: shape.netID)
        }
        guard !seedCandidates.isEmpty, !guideCandidates.isEmpty else {
            return []
        }

        var selected = Array(repeating: false, count: guideCandidates.count)
        var selectedSourceShapeIDs = guideCandidates.map(\.sourceShapeIDs)
        var queue: [Int] = []
        for index in guideCandidates.indices {
            let touchingSeedIDs = seedCandidates
                .filter { touchesOrOverlaps($0.rect, guideCandidates[index].rect) }
                .flatMap(\.sourceShapeIDs)
            guard !touchingSeedIDs.isEmpty else { continue }
            selected[index] = true
            selectedSourceShapeIDs[index] = uniqueShapeIDs(guideCandidates[index].sourceShapeIDs + touchingSeedIDs)
            queue.append(index)
        }

        var cursor = 0
        while cursor < queue.count {
            let selectedIndex = queue[cursor]
            cursor += 1
            for candidateIndex in guideCandidates.indices where !selected[candidateIndex] {
                guard touchesOrOverlaps(
                    guideCandidates[selectedIndex].rect,
                    guideCandidates[candidateIndex].rect
                ) else {
                    continue
                }
                selected[candidateIndex] = true
                selectedSourceShapeIDs[candidateIndex] = uniqueShapeIDs(
                    guideCandidates[candidateIndex].sourceShapeIDs + selectedSourceShapeIDs[selectedIndex]
                )
                queue.append(candidateIndex)
            }
        }

        return guideCandidates.indices
            .filter { selected[$0] }
            .map { index in
                var candidate = guideCandidates[index]
                candidate.sourceShapeIDs = selectedSourceShapeIDs[index]
                return derivedShape(rule: rule, candidate: candidate)
            }
    }

    private static func materializedCellBoundaryShapes(
        for rule: LayoutDerivedLayerRule,
        in cell: LayoutCell
    ) -> [LayoutShape] {
        guard rule.sourceLayers.isEmpty,
              let rect = fixedBoundaryRect(in: cell) else {
            return []
        }
        return [
            derivedShape(
                rule: rule,
                candidate: DerivedLayerCandidate(
                    rect: rect,
                    sourceShapeIDs: [],
                    netID: nil
                )
            )
        ]
    }

    private static func derivedShape(
        rule: LayoutDerivedLayerRule,
        candidate: DerivedLayerCandidate
    ) -> LayoutShape {
        LayoutShape(
            layer: rule.targetLayer,
            netID: candidate.netID,
            geometry: .rect(candidate.rect),
            properties: [
                "derivedLayerRuleID": rule.id,
                "derivedSourceShapeIDs": candidate.sourceShapeIDs.map(\.uuidString).joined(separator: ","),
            ]
        )
    }

    private static func subtract(_ cutter: LayoutRect, from base: LayoutRect) -> [LayoutRect] {
        guard let overlap = intersection(base, cutter) else {
            return [base]
        }
        var pieces: [LayoutRect] = []
        appendRect(
            minX: base.minX,
            minY: base.minY,
            maxX: overlap.minX,
            maxY: base.maxY,
            to: &pieces
        )
        appendRect(
            minX: overlap.maxX,
            minY: base.minY,
            maxX: base.maxX,
            maxY: base.maxY,
            to: &pieces
        )
        appendRect(
            minX: overlap.minX,
            minY: base.minY,
            maxX: overlap.maxX,
            maxY: overlap.minY,
            to: &pieces
        )
        appendRect(
            minX: overlap.minX,
            minY: overlap.maxY,
            maxX: overlap.maxX,
            maxY: base.maxY,
            to: &pieces
        )
        return pieces
    }

    private static func appendRect(
        minX: Double,
        minY: Double,
        maxX: Double,
        maxY: Double,
        to pieces: inout [LayoutRect]
    ) {
        guard maxX - minX > 0.000000001, maxY - minY > 0.000000001 else {
            return
        }
        pieces.append(LayoutRect(
            origin: LayoutPoint(x: minX, y: minY),
            size: LayoutSize(width: maxX - minX, height: maxY - minY)
        ))
    }

    private static func offset(_ rect: LayoutRect, by distance: Double) -> LayoutRect? {
        let offsetRect: LayoutRect
        if distance >= 0 {
            offsetRect = rect.expanded(by: distance, distance)
        } else {
            offsetRect = rect.inset(by: -distance, -distance)
        }
        guard offsetRect.size.width > 0.000000001,
              offsetRect.size.height > 0.000000001 else {
            return nil
        }
        return offsetRect
    }

    private static func rect(for geometry: LayoutGeometry) -> LayoutRect? {
        switch geometry {
        case .rect(let rect):
            return rect
        case .polygon(let polygon):
            return axisAlignedRect(for: polygon)
        case .path:
            return nil
        }
    }

    private static func axisAlignedRect(for polygon: LayoutPolygon) -> LayoutRect? {
        var points = polygon.points
        if let first = points.first, points.last == first {
            points.removeLast()
        }
        guard points.count == 4 else { return nil }
        let bounds = LayoutGeometryAnalysis.boundingBox(for: polygon)
        let corners = [
            LayoutPoint(x: bounds.minX, y: bounds.minY),
            LayoutPoint(x: bounds.maxX, y: bounds.minY),
            LayoutPoint(x: bounds.maxX, y: bounds.maxY),
            LayoutPoint(x: bounds.minX, y: bounds.maxY),
        ]
        guard corners.allSatisfy({ corner in
            points.contains { point in
                abs(point.x - corner.x) < 0.000000001 &&
                    abs(point.y - corner.y) < 0.000000001
            }
        }) else {
            return nil
        }
        return bounds
    }

    private static func intersection(_ first: LayoutRect, _ second: LayoutRect) -> LayoutRect? {
        let minX = max(first.minX, second.minX)
        let minY = max(first.minY, second.minY)
        let maxX = min(first.maxX, second.maxX)
        let maxY = min(first.maxY, second.maxY)
        guard minX < maxX, minY < maxY else { return nil }
        return LayoutRect(
            origin: LayoutPoint(x: minX, y: minY),
            size: LayoutSize(width: maxX - minX, height: maxY - minY)
        )
    }

    private static func touchesOrOverlaps(_ first: LayoutRect, _ second: LayoutRect) -> Bool {
        !(second.maxX < first.minX
            || second.minX > first.maxX
            || second.maxY < first.minY
            || second.minY > first.maxY)
    }

    private static func uniqueShapeIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        var unique: [UUID] = []
        for id in ids where seen.insert(id).inserted {
            unique.append(id)
        }
        return unique
    }

    private static func mergedNetID(_ first: UUID?, _ second: UUID?) -> UUID? {
        switch (first, second) {
        case (.none, .none):
            return nil
        case (.some(let id), .none), (.none, .some(let id)):
            return id
        case (.some(let lhs), .some(let rhs)):
            return lhs == rhs ? lhs : nil
        }
    }

    private static func fixedBoundaryRect(in cell: LayoutCell) -> LayoutRect? {
        let keys = [
            "FIXED_BBOX",
            "fixed_bbox",
            "fixedBBox",
            "fixedBoundingBox",
            "lsi.fixedBBox",
        ]
        for key in keys {
            guard let rawValue = cell.properties[key],
                  let rect = rect(fromFixedBoundaryValue: rawValue) else {
                continue
            }
            return rect
        }
        return nil
    }

    private static func rect(fromFixedBoundaryValue rawValue: String) -> LayoutRect? {
        let normalized = rawValue.map { character -> Character in
            character.isNumber || character == "." || character == "-" || character == "+" || character == "e" || character == "E"
                ? character
                : " "
        }
        let values = String(normalized)
            .split(separator: " ")
            .compactMap { Double($0) }
        guard values.count == 4,
              values.allSatisfy({ $0.isFinite }) else {
            return nil
        }
        let x = values[0]
        let y = values[1]
        let third = values[2]
        let fourth = values[3]
        if third > x, fourth > y {
            return LayoutRect(
                origin: LayoutPoint(x: x, y: y),
                size: LayoutSize(width: third - x, height: fourth - y)
            )
        }
        guard third > 0, fourth > 0 else {
            return nil
        }
        return LayoutRect(
            origin: LayoutPoint(x: x, y: y),
            size: LayoutSize(width: third, height: fourth)
        )
    }

    private static func repairHintGeometry(from cell: LayoutCell) -> DRCRepairHintGeometryContext {
        DRCRepairHintGeometryContext(
            source: "standard-layout",
            topCell: cell.name,
            rectangles: cell.shapes.map { shape in
                let bounds = LayoutGeometryAnalysis.boundingBox(for: shape.geometry)
                return DRCRepairHintGeometryRectangle(
                    id: shape.id.uuidString,
                    layer: "\(shape.layer.name):\(shape.layer.purpose)",
                    netID: shape.netID?.uuidString,
                    xMin: bounds.minX,
                    yMin: bounds.minY,
                    xMax: bounds.maxX,
                    yMax: bounds.maxY
                )
            }
        )
    }

    private static func loadDocument(
        from url: URL,
        format: DRCLayoutFormat?,
        tech: LayoutTechDatabase
    ) throws -> LayoutDocument {
        let converter = MaskDataFormatConverter(tech: tech)
        switch format ?? .auto {
        case .auto:
            let inferredFormat = inferredFormat(from: url)
            if inferredFormat == .nativeJSON {
                return try LayoutDocumentSerializer().decodeDocument(Data(contentsOf: url))
            }
            if inferredFormat == .magicLayout {
                throw DRCError.invalidInput("Magic layout input is only supported by the magic backend.")
            }
            let data = try Data(contentsOf: url)
            return try converter.importFromData(data)
        case .gds:
            return try converter.importDocument(from: url, format: .gds)
        case .oasis:
            return try converter.importDocument(from: url, format: .oasis)
        case .cif:
            return try converter.importDocument(from: url, format: .cif)
        case .dxf:
            return try converter.importDocument(from: url, format: .dxf)
        case .nativeJSON:
            return try LayoutDocumentSerializer().decodeDocument(Data(contentsOf: url))
        case .magicLayout:
            throw DRCError.invalidInput("Magic layout input is only supported by the magic backend.")
        }
    }

    private static func resolveTopCell(
        in document: LayoutDocument,
        requestedTopCell: String,
        format: DRCLayoutFormat?,
        layoutURL: URL
    ) throws -> LayoutCell {
        if let topCell = document.cells.first(where: { $0.name == requestedTopCell }) {
            return topCell
        }
        if allowsSingleCellNameFallback(format: format, layoutURL: layoutURL) {
            if let topCellID = document.topCellID,
               let topCell = document.cell(withID: topCellID) {
                return topCell
            }
            if document.cells.count == 1,
               let topCell = document.cells.first {
                return topCell
            }
        }
        throw DRCError.invalidInput(
            "Top cell '\(requestedTopCell)' is not in the layout (cells: \(document.cells.map(\.name).joined(separator: ", ")))."
        )
    }

    private static func allowsSingleCellNameFallback(format: DRCLayoutFormat?, layoutURL: URL) -> Bool {
        switch format ?? inferredFormat(from: layoutURL) {
        case .cif, .dxf, .nativeJSON:
            return true
        case .auto, .gds, .oasis, .magicLayout, .none:
            return false
        }
    }

    private static func inferredFormat(from url: URL) -> DRCLayoutFormat? {
        switch url.pathExtension.lowercased() {
        case "cif":
            return .cif
        case "dxf":
            return .dxf
        case "json":
            return .nativeJSON
        case "mag":
            return .magicLayout
        default:
            return nil
        }
    }
}
