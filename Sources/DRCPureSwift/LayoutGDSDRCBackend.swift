import Foundation
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech
import LayoutVerify

/// Pure Swift DRC on STANDARD inputs: a GDS layout plus a
/// `LayoutTechDatabase` JSON rule deck. The full LayoutVerify check
/// suite runs in-process (width/spacing with merged-region semantics,
/// enclosure, density, antenna, connectivity) — the same kernel the
/// layout editor's live DRC uses, so the standalone engine and the
/// interactive verdicts can never drift apart.
public struct LayoutGDSDRCBackend: DRCBackend {
    public let backendID = "pure-swift-gds"

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

        var document: LayoutDocument
        do {
            document = try GDSFormatConverter(tech: tech)
                .importDocument(from: request.layoutURL, format: .gds)
        } catch {
            throw DRCError.invalidInput(
                "Could not read GDS layout '\(request.layoutURL.lastPathComponent)': \(error.localizedDescription)"
            )
        }
        guard let topCell = document.cells.first(where: { $0.name == request.topCell }) else {
            throw DRCError.invalidInput(
                "Top cell '\(request.topCell)' is not in the layout (cells: \(document.cells.map(\.name).joined(separator: ", ")))."
            )
        }

        let violations = LayoutDRCService()
            .run(document: document, tech: tech, cellID: topCell.id)
            .violations
        let diagnostics = violations.map { violation in
            DRCDiagnostic(
                severity: .error,
                message: violation.message,
                ruleID: violation.ruleID,
                count: 1,
                rawLine: "\(violation.kind) @ (\(violation.region.origin.x), \(violation.region.origin.y)) \(violation.region.size.width)x\(violation.region.size.height)"
            )
        }

        var logPath = ""
        if let workingDirectory = request.workingDirectory {
            let logURL = workingDirectory.appending(path: "drc-pure-swift-gds.log")
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
        return DRCExecutionResult(request: request, result: result)
    }
}
