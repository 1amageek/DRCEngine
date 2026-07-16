import Foundation
import CircuiteFoundation

public struct DRCCorpusObservationExport: Sendable, Hashable, Codable {
    public struct ObservationSet: Sendable, Hashable, Codable {
        public let acceptanceCriteriaID: String?
        public let observedMetrics: [String: Double]
        public let observedCounts: [String: Int]
        public let findingCodes: [String]

        public init(
            acceptanceCriteriaID: String?,
            observedMetrics: [String: Double],
            observedCounts: [String: Int],
            findingCodes: [String]
        ) {
            self.acceptanceCriteriaID = acceptanceCriteriaID
            self.observedMetrics = observedMetrics
            self.observedCounts = observedCounts
            self.findingCodes = findingCodes
        }
    }

    public struct ObservationRecord: Sendable, Hashable, Codable {
        public let recordID: String
        public let artifact: ArtifactReference
        public let observations: ObservationSet
        public let observedAt: String

        public init(
            recordID: String,
            artifact: ArtifactReference,
            observations: ObservationSet,
            observedAt: String
        ) {
            self.recordID = recordID
            self.artifact = artifact
            self.observations = observations
            self.observedAt = observedAt
        }
    }

    public let schemaVersion: Int
    public let reportArtifact: ArtifactReference
    public let summary: DRCCorpusSummary
    public let observationRecord: ObservationRecord
    public let signature: DRCArtifactSignature?

    private init(
        schemaVersion: Int,
        reportArtifact: ArtifactReference,
        summary: DRCCorpusSummary,
        observationRecord: ObservationRecord,
        signature: DRCArtifactSignature?
    ) {
        self.schemaVersion = schemaVersion
        self.reportArtifact = reportArtifact
        self.summary = summary
        self.observationRecord = observationRecord
        self.signature = signature
    }

    public init(
        schemaVersion: Int = 1,
        reportPath: String,
        reportSHA256: String,
        reportByteCount: UInt64,
        report: DRCCorpusReport,
        recordID: String? = nil,
        observedAt: Date = Date(),
        signature: DRCArtifactSignature? = nil
    ) throws {
        self.schemaVersion = schemaVersion
        self.reportArtifact = ArtifactReference(
            id: try ArtifactID(rawValue: "drc-corpus-report"),
            locator: ArtifactLocator(
                location: try ArtifactLocation(workspaceRelativePath: reportPath),
                role: .input,
                kind: .report,
                format: .json
            ),
            digest: try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: reportSHA256
            ),
            byteCount: reportByteCount
        )
        self.summary = report.summary
        self.signature = signature
        self.observationRecord = ObservationRecord(
            recordID: recordID ?? Self.defaultRecordID(reportPath: reportPath),
            artifact: reportArtifact,
            observations: ObservationSet(
                acceptanceCriteriaID: report.assessment.criteria == .strict ? "strict" : "custom",
                observedMetrics: Self.observedMetrics(report),
                observedCounts: Self.observedCounts(report),
                findingCodes: report.assessment.findings.map(\.code)
            ),
            observedAt: Self.iso8601String(from: observedAt)
        )
    }

    public func withSignature(_ signature: DRCArtifactSignature?) -> DRCCorpusObservationExport {
        DRCCorpusObservationExport(
            schemaVersion: schemaVersion,
            reportArtifact: reportArtifact,
            summary: summary,
            observationRecord: observationRecord,
            signature: signature
        )
    }

    public var reportPath: String { reportArtifact.path }
    public var reportSHA256: String { reportArtifact.digest.hexadecimalValue }

    public func signed(using signer: any DRCArtifactSigner) throws -> DRCCorpusObservationExport {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(withSignature(nil))
        return withSignature(try signer.sign(payload))
    }

    private static func defaultRecordID(reportPath: String) -> String {
        let filename = URL(filePath: reportPath).deletingPathExtension().lastPathComponent
        return filename.isEmpty ? "drc-corpus" : "drc-corpus:\(filename)"
    }

    private static func observedMetrics(_ report: DRCCorpusReport) -> [String: Double] {
        var metrics = [
            "passRate": report.summary.passRate,
            "durationBudgetPassRate": report.caseCount == 0
                ? 0
                : Double(report.summary.durationBudgetPassedCaseCount) / Double(report.caseCount),
            "totalDurationSeconds": report.totalDurationSeconds,
        ]
        if let oracleAgreementRate = report.summary.oracleAgreementRate {
            metrics["oracleAgreementRate"] = oracleAgreementRate
        }
        return metrics
    }

    private static func observedCounts(_ report: DRCCorpusReport) -> [String: Int] {
        [
            "caseCount": report.caseCount,
            "matchedCaseCount": report.matchedCaseCount,
            "budgetExceededCaseCount": report.budgetExceededCaseCount,
            "durationBudgetPassedCaseCount": report.summary.durationBudgetPassedCaseCount,
            "oracleCaseCount": report.summary.oracleCaseCount,
            "oracleAgreementPassedCaseCount": report.summary.oracleAgreementPassedCaseCount,
            "primaryExecutionFailedCaseCount": report.summary.primaryExecutionFailedCaseCount,
            "oracleExecutionFailedCaseCount": report.summary.oracleExecutionFailedCaseCount,
            "oracleReadinessBlockedCaseCount": report.summary.oracleReadinessBlockedCaseCount,
            "coverageTagCount": report.summary.coverageTagCounts.count,
            "requiredCoverageTagCount": report.assessment.criteria.requiredCoverageTags.count,
            "coveredRequiredCoverageTagCount": coveredRequiredCoverageTagCount(report),
        ]
    }

    private static func coveredRequiredCoverageTagCount(_ report: DRCCorpusReport) -> Int {
        report.assessment.criteria.requiredCoverageTags.filter { report.summary.coverageTagCounts[$0] != nil }.count
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

}
