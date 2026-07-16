import Foundation
import DRCEngine
import SignoffToolSupport

public struct DRCNativeAntennaAssessmentCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let artifactPath: String
    public let outputPath: String
    public let assessment: NativeDRCAntennaAssessment

    public init(
        artifactPath: String,
        outputPath: String,
        assessment: NativeDRCAntennaAssessment
    ) {
        self.status = assessment.status.rawValue
        self.artifactPath = artifactPath
        self.outputPath = outputPath
        self.assessment = assessment
    }
}

public struct DRCMagicRuleImportCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let technologyPath: String
    public let reportPath: String?
    public let nativeAntennaPath: String?
    public let nativeAntennaAssessment: NativeDRCAntennaAssessment?
    public let sourcePath: String
    public let profilePath: String
    public let profileResourceName: String?
    public let catalogPath: String?
    public let technologyCatalogID: String?
    public let pdkID: String?
    public let profileID: String?
    public let importReport: MagicDRCLayoutTechImportReport

    public init(
        technologyPath: String,
        reportPath: String?,
        nativeAntennaPath: String? = nil,
        nativeAntennaAssessment: NativeDRCAntennaAssessment? = nil,
        sourcePath: String,
        profilePath: String,
        profileResourceName: String? = nil,
        catalogPath: String? = nil,
        technologyCatalogID: String? = nil,
        pdkID: String? = nil,
        profileID: String? = nil,
        importReport: MagicDRCLayoutTechImportReport
    ) {
        self.status = importReport.status.rawValue
        self.technologyPath = technologyPath
        self.reportPath = reportPath
        self.nativeAntennaPath = nativeAntennaPath
        self.nativeAntennaAssessment = nativeAntennaAssessment
        self.sourcePath = sourcePath
        self.profilePath = profilePath
        self.profileResourceName = profileResourceName
        self.catalogPath = catalogPath
        self.technologyCatalogID = technologyCatalogID
        self.pdkID = pdkID
        self.profileID = profileID
        self.importReport = importReport
    }
}

public struct DRCFoundryRuleImportCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let technologyPath: String?
    public let reportPath: String?
    public let nativeAntennaPath: String?
    public let nativeAntennaAssessment: NativeDRCAntennaAssessment?
    public let semanticReport: SignoffDeckSemanticReport
    public let importReport: MagicDRCLayoutTechImportReport?

    public init(
        technologyPath: String?,
        reportPath: String?,
        nativeAntennaPath: String? = nil,
        nativeAntennaAssessment: NativeDRCAntennaAssessment? = nil,
        semanticReport: SignoffDeckSemanticReport,
        importReport: MagicDRCLayoutTechImportReport?
    ) {
        self.status = importReport?.status.rawValue ?? "blocked"
        self.technologyPath = technologyPath
        self.reportPath = reportPath
        self.nativeAntennaPath = nativeAntennaPath
        self.nativeAntennaAssessment = nativeAntennaAssessment
        self.semanticReport = semanticReport
        self.importReport = importReport
    }
}

public struct DRCCorpusAssessmentCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let reportPath: String
    public let summary: DRCCorpusSummary
    public let assessment: DRCCorpusAssessment

    public init(
        reportPath: String,
        report: DRCCorpusReport,
        assessment: DRCCorpusAssessment
    ) {
        self.status = assessment.meetsCriteria ? "passed" : "failed"
        self.reportPath = reportPath
        self.summary = report.summary
        self.assessment = assessment
    }
}

public struct DRCCorpusCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let reportPath: String
    public let report: DRCCorpusReport

    public init(reportPath: String, report: DRCCorpusReport) {
        self.status = report.assessment.meetsCriteria ? "passed" : "failed"
        self.reportPath = reportPath
        self.report = report
    }
}

public struct DRCCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let backendID: String
    public let toolName: String
    public let reportPath: String?
    public let manifestPath: String?
    public let runID: String?
    public let diagnosticSummary: DRCDiagnosticSummary
    public let runSummary: DRCRunSummary
    public let diagnostics: [DRCDiagnostic]
    public let waiverReport: DRCWaiverApplicationReport?

    public init(result: DRCExecutionResult) {
        let summaryReport = DRCRunSummaryBuilder().build(result: result)
        let summary = summaryReport.summary
        self.status = summary.status
        self.backendID = summary.backendID
        self.toolName = summary.toolName
        self.reportPath = result.reportURL?.path(percentEncoded: false)
        self.manifestPath = result.artifactManifestURL?.path(percentEncoded: false)
        self.runID = result.artifactRunID
        self.diagnostics = result.result.diagnostics
        self.waiverReport = result.waiverReport
        self.runSummary = summary
        self.diagnosticSummary = summary.diagnosticSummary
    }
}
