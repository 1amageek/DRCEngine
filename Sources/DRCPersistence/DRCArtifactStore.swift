import Foundation
import CryptoKit
import DRCCore

public struct DRCArtifactSaveResult: Sendable, Hashable {
    public let reportURL: URL
    public let manifestURL: URL

    public init(reportURL: URL, manifestURL: URL) {
        self.reportURL = reportURL
        self.manifestURL = manifestURL
    }
}

public struct DRCArtifactStore: Sendable {
    public init() {}

    public func save(_ executionResult: DRCExecutionResult, to directory: URL) throws -> DRCArtifactSaveResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let reportURL = directory.appending(path: "drc-report-\(UUID().uuidString).json")
            let manifestURL = directory.appending(path: "drc-artifact-manifest-\(UUID().uuidString).json")
            let storedResult = DRCExecutionResult(
                request: executionResult.request,
                result: executionResult.result,
                waiverReport: executionResult.waiverReport,
                repairHintGeometry: executionResult.repairHintGeometry,
                reportURL: reportURL,
                artifactManifestURL: manifestURL
            )
            let data = try encoder.encode(storedResult)
            try data.write(to: reportURL, options: [.atomic])

            let manifest = try makeManifest(
                for: storedResult,
                reportURL: reportURL,
                manifestURL: manifestURL,
                baseDirectory: directory
            )
            let manifestData = try encoder.encode(manifest)
            try manifestData.write(to: manifestURL, options: [.atomic])
            return DRCArtifactSaveResult(reportURL: reportURL, manifestURL: manifestURL)
        } catch {
            throw DRCError.artifactWriteFailed(error.localizedDescription)
        }
    }

    private func makeManifest(
        for executionResult: DRCExecutionResult,
        reportURL: URL,
        manifestURL: URL,
        baseDirectory: URL
    ) throws -> DRCArtifactManifest {
        var inputs = [
            try record(
                id: "input-layout",
                kind: .layout,
                url: executionResult.request.layoutURL,
                baseDirectory: baseDirectory
            ),
        ]
        if let technologyURL = executionResult.request.technologyURL {
            inputs.append(try record(
                id: "input-technology",
                kind: .technology,
                url: technologyURL,
                baseDirectory: baseDirectory
            ))
        }
        if let waiverURL = executionResult.request.waiverURL {
            inputs.append(try record(
                id: "input-waivers",
                kind: .waiver,
                url: waiverURL,
                baseDirectory: baseDirectory
            ))
        }

        var outputs = [
            try record(
                id: "report",
                kind: .report,
                url: reportURL,
                baseDirectory: baseDirectory
            ),
        ]
        let logURL = URL(filePath: executionResult.result.logPath)
        if !executionResult.result.logPath.isEmpty,
           FileManager.default.fileExists(atPath: logURL.path(percentEncoded: false)) {
            outputs.append(try record(id: "log", kind: .log, url: logURL, baseDirectory: baseDirectory))
        }
        outputs.append(DRCArtifactRecord(
            id: "manifest",
            kind: .manifest,
            path: relativePath(for: manifestURL, baseDirectory: baseDirectory),
            byteCount: nil,
            sha256: nil
        ))

        return DRCArtifactManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            backendID: executionResult.result.backendID,
            toolName: executionResult.result.toolName,
            passed: executionResult.result.passed,
            completed: executionResult.result.completed,
            inputs: inputs,
            outputs: outputs,
            diagnosticSummary: diagnosticSummary(executionResult.result.diagnostics),
            waiverReport: executionResult.waiverReport
        )
    }

    private func diagnosticSummary(_ diagnostics: [DRCDiagnostic]) -> DRCDiagnosticSummary {
        diagnostics.reduce(into: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)) { summary, diagnostic in
            switch diagnostic.severity {
            case .info:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount + 1,
                    warningCount: summary.warningCount,
                    errorCount: summary.errorCount,
                    waivedErrorCount: summary.waivedErrorCount
                )
            case .warning:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount,
                    warningCount: summary.warningCount + 1,
                    errorCount: summary.errorCount,
                    waivedErrorCount: summary.waivedErrorCount
                )
            case .error:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount,
                    warningCount: summary.warningCount,
                    errorCount: summary.errorCount + (diagnostic.isWaived ? 0 : 1),
                    waivedErrorCount: summary.waivedErrorCount + (diagnostic.isWaived ? 1 : 0)
                )
            }
        }
    }

    private func record(
        id: String,
        kind: DRCArtifactRecord.Kind,
        url: URL,
        baseDirectory: URL
    ) throws -> DRCArtifactRecord {
        let data = try Data(contentsOf: url)
        return DRCArtifactRecord(
            id: id,
            kind: kind,
            path: relativePath(for: url, baseDirectory: baseDirectory),
            byteCount: data.count,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        )
    }

    private func relativePath(for url: URL, baseDirectory: URL) -> String {
        let basePath = baseDirectory.standardizedFileURL.path(percentEncoded: false)
        let artifactPath = url.standardizedFileURL.path(percentEncoded: false)
        guard artifactPath.hasPrefix(basePath + "/") else {
            return artifactPath
        }
        return String(artifactPath.dropFirst(basePath.count + 1))
    }
}
