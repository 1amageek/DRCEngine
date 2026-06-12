import Foundation
import DRCCore

public struct PureSwiftDRCBackend: DRCBackend {
    public let backendID = "pure-swift"
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        let data: Data
        do {
            data = try Data(contentsOf: request.layoutURL)
        } catch {
            throw DRCError.invalidInput("Pure Swift DRC could not read layout: \(error.localizedDescription)")
        }

        let layout: PureSwiftDRCLayout
        do {
            layout = try decoder.decode(PureSwiftDRCLayout.self, from: data)
        } catch {
            throw DRCError.invalidInput("Pure Swift DRC expects canonical layout JSON: \(error.localizedDescription)")
        }
        guard layout.topCell == request.topCell else {
            throw DRCError.invalidInput("Requested top cell \(request.topCell) does not match layout top cell \(layout.topCell)")
        }

        let diagnostics = evaluate(layout: layout)
        let logPath = request.workingDirectory?
            .appending(path: "drc-pure-swift-\(UUID().uuidString).log")
            .path(percentEncoded: false)
            ?? ""
        let result = DRCResult(
            backendID: backendID,
            toolName: "PureSwiftDRC",
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
        return DRCExecutionResult(request: request, result: result)
    }

    private func evaluate(layout: PureSwiftDRCLayout) -> [DRCDiagnostic] {
        var diagnostics: [DRCDiagnostic] = []
        let rectanglesByLayer = Dictionary(grouping: layout.rectangles, by: \.layer)

        for rule in layout.rules {
            guard let rectangles = rectanglesByLayer[rule.layer] else { continue }
            switch rule.kind {
            case .minimumWidth:
                diagnostics.append(contentsOf: evaluateMinimumWidth(rule: rule, rectangles: rectangles))
            case .minimumSpacing:
                diagnostics.append(contentsOf: evaluateMinimumSpacing(rule: rule, rectangles: rectangles))
            }
        }

        return diagnostics
    }

    private func evaluateMinimumWidth(
        rule: PureSwiftDRCRule,
        rectangles: [PureSwiftDRCRectangle]
    ) -> [DRCDiagnostic] {
        rectangles.compactMap { rectangle in
            guard rectangle.width < rule.value || rectangle.height < rule.value else {
                return nil
            }
            return DRCDiagnostic(
                severity: .error,
                message: "Rectangle \(rectangle.id) on \(rectangle.layer) violates minimum width \(rule.value)",
                ruleID: rule.id,
                count: 1,
                rawLine: "MIN_WIDTH layer=\(rectangle.layer) id=\(rectangle.id)"
            )
        }
    }

    private func evaluateMinimumSpacing(
        rule: PureSwiftDRCRule,
        rectangles: [PureSwiftDRCRectangle]
    ) -> [DRCDiagnostic] {
        var diagnostics: [DRCDiagnostic] = []
        for firstIndex in rectangles.indices {
            for secondIndex in rectangles.index(after: firstIndex)..<rectangles.endIndex {
                let first = rectangles[firstIndex]
                let second = rectangles[secondIndex]
                guard !first.overlaps(second),
                      first.spacing(to: second) < rule.value else {
                    continue
                }
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "Rectangles \(first.id) and \(second.id) on \(first.layer) violate minimum spacing \(rule.value)",
                    ruleID: rule.id,
                    count: 1,
                    rawLine: "MIN_SPACING layer=\(first.layer) ids=\(first.id),\(second.id)"
                ))
            }
        }
        return diagnostics
    }
}

public struct PureSwiftDRCLayout: Sendable, Hashable, Codable {
    public let technologyID: String
    public let topCell: String
    public let unit: String
    public let rectangles: [PureSwiftDRCRectangle]
    public let rules: [PureSwiftDRCRule]

    public init(
        technologyID: String,
        topCell: String,
        unit: String = "micrometer",
        rectangles: [PureSwiftDRCRectangle],
        rules: [PureSwiftDRCRule]
    ) {
        self.technologyID = technologyID
        self.topCell = topCell
        self.unit = unit
        self.rectangles = rectangles
        self.rules = rules
    }
}

public struct PureSwiftDRCRectangle: Sendable, Hashable, Codable {
    public let id: String
    public let layer: String
    public let xMin: Double
    public let yMin: Double
    public let xMax: Double
    public let yMax: Double

    public init(id: String, layer: String, xMin: Double, yMin: Double, xMax: Double, yMax: Double) {
        self.id = id
        self.layer = layer
        self.xMin = xMin
        self.yMin = yMin
        self.xMax = xMax
        self.yMax = yMax
    }

    public var width: Double {
        xMax - xMin
    }

    public var height: Double {
        yMax - yMin
    }

    public func overlaps(_ other: PureSwiftDRCRectangle) -> Bool {
        xMin < other.xMax && xMax > other.xMin && yMin < other.yMax && yMax > other.yMin
    }

    public func spacing(to other: PureSwiftDRCRectangle) -> Double {
        let xGap = max(0, max(other.xMin - xMax, xMin - other.xMax))
        let yGap = max(0, max(other.yMin - yMax, yMin - other.yMax))
        if xGap == 0 {
            return yGap
        }
        if yGap == 0 {
            return xGap
        }
        return (xGap * xGap + yGap * yGap).squareRoot()
    }
}

public struct PureSwiftDRCRule: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case minimumWidth
        case minimumSpacing
    }

    public let id: String
    public let kind: Kind
    public let layer: String
    public let value: Double

    public init(id: String, kind: Kind, layer: String, value: Double) {
        self.id = id
        self.kind = kind
        self.layer = layer
        self.value = value
    }
}
