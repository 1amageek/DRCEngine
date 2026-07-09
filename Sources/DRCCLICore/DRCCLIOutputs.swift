import Foundation
import DRCEngine
import SignoffToolSupport

public struct DRCMagicRuleImportCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let technologyPath: String
    public let reportPath: String?
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
    public let semanticReport: SignoffDeckSemanticReport
    public let importReport: MagicDRCLayoutTechImportReport?

    public init(
        technologyPath: String?,
        reportPath: String?,
        semanticReport: SignoffDeckSemanticReport,
        importReport: MagicDRCLayoutTechImportReport?
    ) {
        self.status = importReport?.status.rawValue ?? "blocked"
        self.technologyPath = technologyPath
        self.reportPath = reportPath
        self.semanticReport = semanticReport
        self.importReport = importReport
    }
}

public struct DRCCorpusQualificationCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let reportPath: String
    public let summary: DRCCorpusSummary
    public let qualification: DRCCorpusQualificationResult

    public init(
        reportPath: String,
        report: DRCCorpusReport,
        qualification: DRCCorpusQualificationResult
    ) {
        self.status = qualification.qualified ? "passed" : "failed"
        self.reportPath = reportPath
        self.summary = report.summary
        self.qualification = qualification
    }
}

public struct DRCCorpusCLIOutput: Sendable, Hashable, Codable {
    public let status: String
    public let reportPath: String
    public let report: DRCCorpusReport

    public init(reportPath: String, report: DRCCorpusReport) {
        self.status = report.qualification.qualified ? "passed" : "failed"
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
        self.diagnostics = result.result.diagnostics
        self.waiverReport = result.waiverReport
        self.runSummary = summary
        self.diagnosticSummary = summary.diagnosticSummary
    }
}
