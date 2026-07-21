import CircuiteFoundation
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
public struct LayoutGDSDRCBackend: DRCCancellableBackend {
    public let backendID = "native-gds"

    public init() {}

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
        let input = try Self.loadExecutionInput(for: request)
        try Self.validateTechnologyReadiness(input.tech, request: request)
        try await checkCancellation(cancellationCheck)
        let layoutResult = Self.collectResult(
            document: input.document,
            tech: input.tech,
            topCell: input.topCell
        )
        try await checkCancellation(cancellationCheck)
        let diagnostics = Self.makeDiagnostics(from: layoutResult)
        let logPath = try Self.writeRunLogIfNeeded(
            violationCount: layoutResult.violations.count,
            diagnostics: diagnostics,
            topCellName: input.topCell.name,
            request: request
        )
        let result = makeResult(
            request: request,
            technologyURL: input.technologyURL,
            diagnostics: diagnostics,
            layoutDiagnostics: layoutResult.diagnostics,
            logPath: logPath
        )
        return DRCExecutionResult(
            request: request,
            result: result,
            repairHintGeometry: Self.repairHintGeometry(from: input.topCell),
            provenance: try DRCExecutionProvenance.make(
                request: request,
                result: result,
                inputArtifacts: inputArtifacts,
                invocation: ExecutionInvocation.inProcess(
                    entryPoint: "LayoutGDSDRCBackend.run"
                ),
                startedAt: startedAt,
                completedAt: Date()
            )
        )
    }

    private func checkCancellation(
        _ cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws {
        if Task.isCancelled {
            throw DRCError.cancelled("Native GDS DRC execution was cancelled.")
        }
        if let cancellationCheck, try await cancellationCheck() {
            throw DRCError.cancelled("Native GDS DRC execution was cancelled.")
        }
    }

    private struct ExecutionInput {
        let technologyURL: URL
        let tech: LayoutTechDatabase
        let document: LayoutDocument
        let topCell: LayoutCell
    }

    private static func loadExecutionInput(for request: DRCRequest) throws -> ExecutionInput {
        guard let technologyURL = request.technologyURL else {
            throw DRCError.invalidInput(
                "The GDS backend needs a technology rule deck (technologyURL: LayoutTechDatabase JSON)."
            )
        }
        let tech = try loadTechnology(from: technologyURL)
        let document = try loadMaterializedDocument(for: request, tech: tech)
        let topCell = try Self.resolveTopCell(
            in: document,
            requestedTopCell: request.topCell,
            format: request.layoutFormat,
            layoutURL: request.layoutURL
        )

        return ExecutionInput(
            technologyURL: technologyURL,
            tech: tech,
            document: document,
            topCell: topCell
        )
    }

    private static func loadTechnology(from technologyURL: URL) throws -> LayoutTechDatabase {
        do {
            return try JSONDecoder().decode(
                LayoutTechDatabase.self,
                from: try Data(contentsOf: technologyURL)
            )
        } catch {
            throw DRCError.invalidInput(
                "Could not load technology deck '\(technologyURL.lastPathComponent)': \(error.localizedDescription)"
            )
        }
    }

    private static func validateTechnologyReadiness(
        _ tech: LayoutTechDatabase,
        request: DRCRequest
    ) throws {
        guard request.options.requireAntennaRules else {
            return
        }
        guard !tech.antennaRules.isEmpty else {
            throw DRCError.invalidInput(
                "Antenna rule coverage is required, but the technology deck contains no antennaRules. The run is blocked instead of being reported as zero antenna violations."
            )
        }
    }

    private static func loadMaterializedDocument(
        for request: DRCRequest,
        tech: LayoutTechDatabase
    ) throws -> LayoutDocument {
        do {
            let rawDocument = try Self.loadDocument(
                from: request.layoutURL,
                format: request.layoutFormat,
                tech: tech
            )
            return rawDocument
        } catch {
            throw DRCError.invalidInput(
                "Could not read layout '\(request.layoutURL.lastPathComponent)': \(error.localizedDescription)"
            )
        }
    }

    private static func collectResult(
        document: LayoutDocument,
        tech: LayoutTechDatabase,
        topCell: LayoutCell
    ) -> LayoutDRCResult {
        LayoutDRCService()
            .run(
                document: document,
                tech: tech,
                cellID: topCell.id,
                geometryMode: .exactOnly
            )
    }

    private static func makeDiagnostics(from result: LayoutDRCResult) -> [DRCDiagnostic] {
        let violationDiagnostics = result.violations.map { violation in
            Self.makeDiagnostic(from: violation)
        }
        let layoutDiagnostics = result.diagnostics.map { diagnostic in
            DRCDiagnostic(
                severity: diagnostic.severity == .error ? .error : .warning,
                message: diagnostic.message,
                ruleID: diagnostic.code,
                kind: "layout-diagnostic",
                rawLine: "\(diagnostic.code): \(diagnostic.message)"
            )
        }
        return violationDiagnostics + layoutDiagnostics
    }

    private static func makeDiagnostic(from violation: LayoutViolation) -> DRCDiagnostic {
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

    private static func writeRunLogIfNeeded(
        violationCount: Int,
        diagnostics: [DRCDiagnostic],
        topCellName: String,
        request: DRCRequest
    ) throws -> String {
        guard let workingDirectory = request.workingDirectory else {
            return ""
        }

        let logURL = workingDirectory.appending(path: "drc-native-gds-\(UUID().uuidString).log")
        let log = (["\(violationCount) violation(s) on \(topCellName)"]
            + diagnostics.map(\.rawLine)).joined(separator: "\n") + "\n"
        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
        try log.write(to: logURL, atomically: true, encoding: .utf8)
        return logURL.path(percentEncoded: false)
    }

    private func makeResult(
        request: DRCRequest,
        technologyURL: URL,
        diagnostics: [DRCDiagnostic],
        layoutDiagnostics: [LayoutDRCDiagnostic],
        logPath: String
    ) -> DRCResult {
        // `success` means the check RAN; the verdict lives in the
        // diagnostics (DRCResult.passed folds both).
        DRCResult(
            backendID: backendID,
            toolName: "LayoutVerify",
            success: true,
            // The backend completed the verification pass even when the
            // kernel reports a blocking layout diagnostic. `completed` is
            // reserved for execution interruption; design failures belong in
            // the typed diagnostic/verdict channel.
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
