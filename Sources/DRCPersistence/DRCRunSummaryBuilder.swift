import Foundation
import DRCCore

public struct DRCRunSummaryBuilder: Sendable {
    public init() {}

    public func build(reportURL: URL) throws -> DRCRunSummaryReport {
        do {
            let data = try Data(contentsOf: reportURL)
            let result = try JSONDecoder().decode(DRCExecutionResult.self, from: data)
            return build(result: result, reportURL: reportURL)
        } catch {
            throw DRCError.invalidInput("Unable to load DRC report summary input: \(error.localizedDescription)")
        }
    }

    public func build(
        result: DRCExecutionResult,
        reportURL: URL? = nil
    ) -> DRCRunSummaryReport {
        DRCRunSummaryReport(
            reportURL: reportURL ?? result.reportURL,
            manifestURL: result.artifactManifestURL,
            summary: DRCRunSummary(
                status: result.result.passed ? "passed" : "failed",
                backendID: result.result.backendID,
                toolName: result.result.toolName,
                topCell: result.request.topCell,
                layoutFormat: result.request.layoutFormat?.rawValue,
                passed: result.result.passed,
                completed: result.result.completed,
                diagnosticSummary: diagnosticSummary(result.result.diagnostics),
                activeViolationCount: result.result.diagnostics.filter { $0.severity == .error && !$0.isWaived }.count,
                waivedViolationCount: result.result.diagnostics.filter { $0.severity == .error && $0.isWaived }.count,
                violationBuckets: violationBuckets(result.result.diagnostics),
                unusedWaiverIDs: result.waiverReport?.unusedWaiverIDs.sorted() ?? []
            )
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

    private func violationBuckets(_ diagnostics: [DRCDiagnostic]) -> [DRCViolationBucketSummary] {
        let errors = diagnostics.filter { $0.severity == .error }
        var buckets: [DRCViolationBucketKey: DRCViolationBucketAccumulator] = [:]
        for diagnostic in errors {
            let key = DRCViolationBucketKey(
                ruleID: diagnostic.ruleID,
                kind: diagnostic.kind,
                layer: diagnostic.layer
            )
            buckets[key, default: DRCViolationBucketAccumulator(key: key)].add(diagnostic)
        }
        return buckets.values
            .map { $0.summary }
            .sorted { lhs, rhs in
                if lhs.activeCount != rhs.activeCount {
                    return lhs.activeCount > rhs.activeCount
                }
                if lhs.waivedCount != rhs.waivedCount {
                    return lhs.waivedCount > rhs.waivedCount
                }
                return lhs.sortKey < rhs.sortKey
            }
    }
}

public struct DRCRunSummaryReport: Sendable, Codable, Hashable {
    public let schemaVersion: Int
    public let reportURL: URL?
    public let manifestURL: URL?
    public let summary: DRCRunSummary

    public init(
        schemaVersion: Int = 1,
        reportURL: URL?,
        manifestURL: URL?,
        summary: DRCRunSummary
    ) {
        self.schemaVersion = schemaVersion
        self.reportURL = reportURL
        self.manifestURL = manifestURL
        self.summary = summary
    }
}

public struct DRCRunSummary: Sendable, Codable, Hashable {
    public let status: String
    public let backendID: String
    public let toolName: String
    public let topCell: String
    public let layoutFormat: String?
    public let passed: Bool
    public let completed: Bool
    public let diagnosticSummary: DRCDiagnosticSummary
    public let activeViolationCount: Int
    public let waivedViolationCount: Int
    public let violationBuckets: [DRCViolationBucketSummary]
    public let unusedWaiverIDs: [String]

    public init(
        status: String,
        backendID: String,
        toolName: String,
        topCell: String,
        layoutFormat: String?,
        passed: Bool,
        completed: Bool,
        diagnosticSummary: DRCDiagnosticSummary,
        activeViolationCount: Int,
        waivedViolationCount: Int,
        violationBuckets: [DRCViolationBucketSummary],
        unusedWaiverIDs: [String]
    ) {
        self.status = status
        self.backendID = backendID
        self.toolName = toolName
        self.topCell = topCell
        self.layoutFormat = layoutFormat
        self.passed = passed
        self.completed = completed
        self.diagnosticSummary = diagnosticSummary
        self.activeViolationCount = activeViolationCount
        self.waivedViolationCount = waivedViolationCount
        self.violationBuckets = violationBuckets
        self.unusedWaiverIDs = unusedWaiverIDs
    }
}

public struct DRCViolationBucketSummary: Sendable, Codable, Hashable {
    public let ruleID: String?
    public let kind: String?
    public let layer: String?
    public let activeCount: Int
    public let waivedCount: Int
    public let maxMeasured: Double?
    public let required: Double?
    public let representativeRegion: DRCRegion?
    public let relatedShapeIDs: [String]
    public let relatedNetIDs: [String]
    public let suggestedFixes: [String]

    public init(
        ruleID: String?,
        kind: String?,
        layer: String?,
        activeCount: Int,
        waivedCount: Int,
        maxMeasured: Double?,
        required: Double?,
        representativeRegion: DRCRegion? = nil,
        relatedShapeIDs: [String],
        relatedNetIDs: [String],
        suggestedFixes: [String]
    ) {
        self.ruleID = ruleID
        self.kind = kind
        self.layer = layer
        self.activeCount = activeCount
        self.waivedCount = waivedCount
        self.maxMeasured = maxMeasured
        self.required = required
        self.representativeRegion = representativeRegion
        self.relatedShapeIDs = relatedShapeIDs
        self.relatedNetIDs = relatedNetIDs
        self.suggestedFixes = suggestedFixes
    }

    fileprivate var sortKey: String {
        [ruleID, kind, layer].map { $0 ?? "" }.joined(separator: "|")
    }
}

private struct DRCViolationBucketKey: Hashable {
    let ruleID: String?
    let kind: String?
    let layer: String?
}

private struct DRCViolationBucketAccumulator {
    let key: DRCViolationBucketKey
    var activeCount = 0
    var waivedCount = 0
    var maxMeasured: Double?
    var required: Double?
    var representativeRegion: DRCRegion?
    var relatedShapeIDs: Set<String> = []
    var relatedNetIDs: Set<String> = []
    var suggestedFixes: Set<String> = []

    mutating func add(_ diagnostic: DRCDiagnostic) {
        if diagnostic.isWaived {
            waivedCount += 1
        } else {
            activeCount += 1
        }
        if let measured = diagnostic.measured {
            maxMeasured = max(maxMeasured ?? measured, measured)
        }
        if required == nil {
            required = diagnostic.required
        }
        if representativeRegion == nil, let region = diagnostic.region {
            representativeRegion = region
        }
        relatedShapeIDs.formUnion(diagnostic.relatedShapeIDs)
        relatedNetIDs.formUnion(diagnostic.relatedNetIDs)
        if let suggestedFix = diagnostic.suggestedFix {
            suggestedFixes.insert(suggestedFix)
        }
    }

    var summary: DRCViolationBucketSummary {
        DRCViolationBucketSummary(
            ruleID: key.ruleID,
            kind: key.kind,
            layer: key.layer,
            activeCount: activeCount,
            waivedCount: waivedCount,
            maxMeasured: maxMeasured,
            required: required,
            representativeRegion: representativeRegion,
            relatedShapeIDs: relatedShapeIDs.sorted(),
            relatedNetIDs: relatedNetIDs.sorted(),
            suggestedFixes: suggestedFixes.sorted()
        )
    }
}
