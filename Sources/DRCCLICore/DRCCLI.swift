import Foundation
import CryptoKit
import Synchronization
import DRCEngine
import SignoffToolSupport

public enum DRCCLIError: Error, LocalizedError, Equatable {
    case missingValue(String)
    case missingRequired(String)
    case invalidValue(argument: String, value: String, expected: String)
    case unknownArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            return "Missing value after \(argument)"
        case .missingRequired(let argument):
            return "Missing required argument: \(argument)"
        case .invalidValue(let argument, let value, let expected):
            return "Invalid value for \(argument): \(value). Expected \(expected)"
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        }
    }
}

public struct DRCCLIInvocationResult: Sendable, Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

private final class DRCCLIOutputBuffer: Sendable {
    private struct State: Sendable {
        var standardOutput = Data()
        var standardError = Data()
    }

    private let state = Mutex(State())

    func appendStandardOutput(_ data: Data) {
        state.withLock { $0.standardOutput.append(data) }
    }

    func appendStandardError(_ data: Data) {
        state.withLock { $0.standardError.append(data) }
    }

    func result(exitCode: Int32) -> DRCCLIInvocationResult {
        state.withLock { state in
            DRCCLIInvocationResult(
                exitCode: exitCode,
                standardOutput: String(decoding: state.standardOutput, as: UTF8.self),
                standardError: String(decoding: state.standardError, as: UTF8.self)
            )
        }
    }
}

private enum DRCCLIOutputWriter: Sendable {
    case standard
    case buffer(DRCCLIOutputBuffer)

    func writeStandardOutput(_ data: Data) {
        switch self {
        case .standard:
            FileHandle.standardOutput.write(data)
        case .buffer(let buffer):
            buffer.appendStandardOutput(data)
        }
    }

    func writeStandardOutputLine(_ line: String) {
        writeStandardOutput(Data("\(line)\n".utf8))
    }

    func writeStandardErrorLine(_ line: String) {
        let data = Data("\(line)\n".utf8)
        switch self {
        case .standard:
            FileHandle.standardError.write(data)
        case .buffer(let buffer):
            buffer.appendStandardError(data)
        }
    }

    func result(exitCode: Int32) -> DRCCLIInvocationResult {
        switch self {
        case .standard:
            DRCCLIInvocationResult(exitCode: exitCode, standardOutput: "", standardError: "")
        case .buffer(let buffer):
            buffer.result(exitCode: exitCode)
        }
    }
}

public enum DRCCLI {
    public static let availableBackends = [
        "native",
        "native-gds",
        "magic",
    ]

    public static func run(arguments: [String]) async -> Int32 {
        await invoke(arguments: arguments, writer: .standard).exitCode
    }

    public static func invoke(arguments: [String]) async -> DRCCLIInvocationResult {
        let buffer = DRCCLIOutputBuffer()
        return await invoke(arguments: arguments, writer: .buffer(buffer))
    }

    private static func invoke(arguments: [String], writer: DRCCLIOutputWriter) async -> DRCCLIInvocationResult {
        do {
            return try await dispatch(arguments: arguments, writer: writer)
        } catch {
            writer.writeStandardErrorLine(error.localizedDescription)
            return writer.result(exitCode: 1)
        }
    }

    private static func dispatch(arguments: [String], writer: DRCCLIOutputWriter) async throws -> DRCCLIInvocationResult {
        if arguments == ["--list-backends"] {
            return runListBackends(writer: writer)
        }
        if arguments.contains("--inspect-magic-rule-import-catalog") {
            return try runMagicRuleImportCatalogInventory(arguments: arguments, writer: writer)
        }
        if arguments.contains("--import-magic-rules") {
            return try runMagicRuleImport(arguments: arguments, writer: writer)
        }
        if importsFoundryMagicRules(arguments) {
            return try runFoundryRuleImport(arguments: arguments, writer: writer)
        }
        if arguments.contains("--foundry-deck-semantics") {
            return try runFoundryDeckSemantics(arguments: arguments, writer: writer)
        }
        if arguments.contains("--capabilities") {
            return try runCapabilities(arguments: arguments, writer: writer)
        }
        if arguments.contains("--repair-hints-from-report") {
            return try runRepairHints(arguments: arguments, writer: writer)
        }
        if arguments.contains("--summarize-report") {
            return try runReportSummary(arguments: arguments, writer: writer)
        }
        if arguments.contains("--action-domain") {
            return try runActionDomain(arguments: arguments, writer: writer)
        }
        if arguments.contains("--audit-corpus-coverage") {
            return try runCorpusCoverageAudit(arguments: arguments, writer: writer)
        }
        if arguments.contains("--evidence-packet-from-corpus-report") {
            return try runEvidencePacket(arguments: arguments, writer: writer)
        }
        if arguments.contains("--evidence-from-corpus-report") {
            return try runCorpusEvidence(arguments: arguments, writer: writer)
        }
        if arguments.contains("--qualify-corpus-report") {
            return try runCorpusQualification(arguments: arguments, writer: writer)
        }
        if arguments.contains("--corpus") {
            return try await runCorpus(arguments: arguments, writer: writer)
        }
        return try await runDefaultDRC(arguments: arguments, writer: writer)
    }

    private static func runListBackends(writer: DRCCLIOutputWriter) -> DRCCLIInvocationResult {
        for backendID in availableBackends {
            writer.writeStandardOutputLine(backendID)
        }
        return writer.result(exitCode: 0)
    }

    private static func runMagicRuleImportCatalogInventory(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCMagicRuleImportCatalogInventoryCLIOptions(arguments: arguments)
        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: options.catalogURLs,
            pdkRootURLs: options.pdkRootURLs
        )
        if let outputURL = options.outputURL {
            try writeJSON(inventory, to: outputURL)
        }
        try emitMagicRuleImportCatalogInventoryOutput(inventory, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: options.requirePassed && inventory.status != .passed ? 2 : 0)
    }

    private static func runMagicRuleImport(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCMagicRuleImportCLIOptions(arguments: arguments)
        let profile = try MagicDRCLayoutTechImportProfile.load(from: options.profileURL)
        let importResult = try MagicDRCLayoutTechImporter.importTechnology(from: options.magicTechURL, profile: profile)
        try writeMagicRuleImportArtifacts(importResult, options: options)
        let output = magicRuleImportOutput(options: options, importResult: importResult)
        try emitMagicRuleImportOutput(output, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: magicRuleImportExitCode(importResult, allowPartial: options.allowPartial))
    }

    private static func importsFoundryMagicRules(_ arguments: [String]) -> Bool {
        arguments.contains(DRCFoundryRuleImportCLIOptions.importFlag)
    }

    private static func runFoundryRuleImport(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCFoundryRuleImportCLIOptions(arguments: arguments)
        let signoffProfile = try defaultSignoffPDKProfile()
        let semanticReport = foundrySemanticReport(options: options, profile: signoffProfile)
        guard semanticReport.status == .passed, let pdkRoot = semanticReport.pdkRoot else {
            let output = blockedFoundryRuleImportOutput(semanticReport: semanticReport)
            try emitFoundryRuleImportOutput(output, json: options.emitJSON, writer: writer)
            return writer.result(exitCode: 2)
        }
        let importResult = try importFoundryRuleTechnology(options: options, profile: signoffProfile, pdkRoot: pdkRoot, report: semanticReport)
        try writeFoundryRuleImportArtifacts(importResult, options: options)
        let output = foundryRuleImportOutput(options: options, semanticReport: semanticReport, importResult: importResult)
        try emitFoundryRuleImportOutput(output, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: magicRuleImportExitCode(importResult, allowPartial: options.allowPartial))
    }

    private static func runFoundryDeckSemantics(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCFoundryDeckSemanticCLIOptions(arguments: arguments)
        let signoffProfile = try defaultSignoffPDKProfile()
        let report = foundrySemanticReport(options: options, profile: signoffProfile)
        try emitFoundryDeckSemanticReport(report, options: options, writer: writer)
        return writer.result(exitCode: options.requirePassed && report.status != .passed ? 2 : 0)
    }

    private static func runCapabilities(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCCapabilityCLIOptions(arguments: arguments)
        let snapshot = DRCCapabilitySnapshotProvider().snapshot()
        try emitCapabilities(snapshot, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: 0)
    }

    private static func runRepairHints(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCRepairHintsCLIOptions(arguments: arguments)
        let report = try DRCRepairHintBuilder().build(reportURL: options.reportURL)
        try emitRepairHints(report, options: options, writer: writer)
        return writer.result(exitCode: 0)
    }

    private static func runReportSummary(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCReportSummaryCLIOptions(arguments: arguments)
        let report = try DRCRunSummaryBuilder().build(reportURL: options.reportURL)
        try emitReportSummary(report, options: options, writer: writer)
        return writer.result(exitCode: 0)
    }

    private static func runActionDomain(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCActionDomainCLIOptions(arguments: arguments)
        let snapshot = DRCActionDomainExporter().snapshot()
        try emitActionDomain(snapshot, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: 0)
    }

    private static func runCorpusCoverageAudit(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCCorpusCoverageAuditCLIOptions(arguments: arguments)
        let report = try combinedCorpusReport(options: options)
        let policy = try corpusCoverageAuditPolicy(options: options)
        let audit = corpusCoverageAudit(options: options, report: report, policy: policy)
        try validateCorpusCoverageAudit(audit)
        if let outputURL = options.outputURL {
            try writeJSON(audit, to: outputURL)
        }
        try emitCorpusCoverageAudit(audit, options: options, writer: writer)
        return writer.result(exitCode: audit.status == .satisfied ? 0 : 2)
    }

    private static func runEvidencePacket(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCEvidencePacketCLIOptions(arguments: arguments)
        let loadedReport = try loadCorpusReport(from: options.reportURL)
        let packet = DRCCorpusEvidencePacketBuilder().build(
            report: loadedReport.report,
            reportPath: options.reportURL.path(percentEncoded: false),
            reportSHA256: sha256(data: loadedReport.data),
            packetID: options.packetID,
            allowedArtifactRootPath: options.reportURL.deletingLastPathComponent().path(percentEncoded: false)
        )
        try validateEvidencePacket(packet)
        if let outputURL = options.outputURL {
            try writeJSON(packet, to: outputURL)
        }
        try emitEvidencePacket(packet, options: options, writer: writer)
        return writer.result(exitCode: 0)
    }

    private static func runCorpusEvidence(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCCorpusEvidenceCLIOptions(arguments: arguments)
        let loadedReport = try loadCorpusReport(from: options.reportURL)
        let output = DRCCorpusToolEvidenceExport(
            reportPath: options.reportURL.path(percentEncoded: false),
            reportSHA256: sha256(data: loadedReport.data),
            report: loadedReport.report,
            evidenceID: options.evidenceID,
            checkedAt: options.checkedAt
        )
        try emitCorpusEvidence(output, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: output.toolEvidence.qualification.qualified ? 0 : 2)
    }

    private static func runCorpusQualification(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) throws -> DRCCLIInvocationResult {
        let options = try DRCCorpusQualificationCLIOptions(arguments: arguments)
        let report = try loadCorpusReport(from: options.reportURL).report
        let qualification = try corpusQualification(report: report, options: options)
        try emitCorpusQualification(report: report, qualification: qualification, options: options, writer: writer)
        return writer.result(exitCode: qualification.qualified ? 0 : 2)
    }

    private static func runCorpus(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) async throws -> DRCCLIInvocationResult {
        let options = try DRCCorpusCLIOptions(arguments: arguments)
        let report = try await DRCCorpusRunner().run(
            specURL: options.specURL,
            outputDirectory: options.outputDirectory,
            options: options.runOptions
        )
        try emitCorpus(report, options: options, writer: writer)
        return writer.result(exitCode: report.qualification.qualified ? 0 : 2)
    }

    private static func runDefaultDRC(
        arguments: [String],
        writer: DRCCLIOutputWriter
    ) async throws -> DRCCLIInvocationResult {
        let options = try DRCCLIOptions(arguments: arguments)
        let result = try await DefaultDRCEngine().run(options.makeRequest())
        try emitDefaultDRC(result, json: options.emitJSON, writer: writer)
        return writer.result(exitCode: result.result.passed ? 0 : 2)
    }

    private struct LoadedCorpusReport {
        var data: Data
        var report: DRCCorpusReport
    }

    private static func writeMagicRuleImportArtifacts(
        _ importResult: MagicDRCLayoutTechImport,
        options: DRCMagicRuleImportCLIOptions
    ) throws {
        try writeJSON(importResult.technology, to: options.technologyOutputURL)
        if let reportOutputURL = options.reportOutputURL {
            try writeJSON(importResult.report, to: reportOutputURL)
        }
    }

    private static func magicRuleImportOutput(
        options: DRCMagicRuleImportCLIOptions,
        importResult: MagicDRCLayoutTechImport
    ) -> DRCMagicRuleImportCLIOutput {
        DRCMagicRuleImportCLIOutput(
            technologyPath: options.technologyOutputURL.path(percentEncoded: false),
            reportPath: options.reportOutputURL?.path(percentEncoded: false),
            sourcePath: options.magicTechURL.path(percentEncoded: false),
            profilePath: options.profileURL.path(percentEncoded: false),
            profileResourceName: options.profileResourceName,
            catalogPath: options.catalogURL?.path(percentEncoded: false),
            technologyCatalogID: options.technologyCatalogID,
            pdkID: options.pdkID,
            profileID: options.profileID,
            importReport: importResult.report
        )
    }

    private static func magicRuleImportExitCode(
        _ importResult: MagicDRCLayoutTechImport,
        allowPartial: Bool
    ) -> Int32 {
        if importResult.report.status == .blocked {
            return 2
        }
        if importResult.report.status == .complete {
            return 0
        }
        return allowPartial ? 0 : 2
    }

    private static func foundrySemanticReport(
        options: DRCFoundryRuleImportCLIOptions,
        profile: SignoffPDKProfile
    ) -> SignoffDeckSemanticReport {
        SignoffDeckSemanticInventory.inspect(
            profile: profile,
            requirements: drcMagicDeckRequirements(from: profile),
            environment: options.environment(overriding: ProcessInfo.processInfo.environment)
        )
    }

    private static func foundrySemanticReport(
        options: DRCFoundryDeckSemanticCLIOptions,
        profile: SignoffPDKProfile
    ) -> SignoffDeckSemanticReport {
        SignoffDeckSemanticInventory.inspect(
            profile: profile,
            requirements: drcMagicDeckRequirements(from: profile),
            environment: options.environment(overriding: ProcessInfo.processInfo.environment)
        )
    }

    private static func blockedFoundryRuleImportOutput(
        semanticReport: SignoffDeckSemanticReport
    ) -> DRCFoundryRuleImportCLIOutput {
        DRCFoundryRuleImportCLIOutput(
            technologyPath: nil,
            reportPath: nil,
            semanticReport: semanticReport,
            importReport: nil
        )
    }

    private static func importFoundryRuleTechnology(
        options: DRCFoundryRuleImportCLIOptions,
        profile: SignoffPDKProfile,
        pdkRoot: String,
        report: SignoffDeckSemanticReport
    ) throws -> MagicDRCLayoutTechImport {
        let importProfile = try foundryImportProfile(options: options)
        let magicTechURL = try SignoffPDKLocator.requiredFileURL(
            in: pdkRoot,
            profile: profile,
            requirementID: "magic-tech"
        )
        return try MagicDRCLayoutTechImporter.importTechnology(
            from: magicTechURL,
            profile: importProfile,
            generatedAt: report.generatedAt
        )
    }

    private static func foundryImportProfile(
        options: DRCFoundryRuleImportCLIOptions
    ) throws -> MagicDRCLayoutTechImportProfile {
        let bundledProfileResourceName = options.profileResourceName ?? "sky130-magic-layouttech-profile"
        if let profileURL = options.profileURL {
            return try MagicDRCLayoutTechImportProfile.load(from: profileURL)
        }
        return try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: bundledProfileResourceName
        )
    }

    private static func writeFoundryRuleImportArtifacts(
        _ importResult: MagicDRCLayoutTechImport,
        options: DRCFoundryRuleImportCLIOptions
    ) throws {
        try writeJSON(importResult.technology, to: options.technologyOutputURL)
        if let reportOutputURL = options.reportOutputURL {
            try writeJSON(importResult.report, to: reportOutputURL)
        }
    }

    private static func foundryRuleImportOutput(
        options: DRCFoundryRuleImportCLIOptions,
        semanticReport: SignoffDeckSemanticReport,
        importResult: MagicDRCLayoutTechImport
    ) -> DRCFoundryRuleImportCLIOutput {
        DRCFoundryRuleImportCLIOutput(
            technologyPath: options.technologyOutputURL.path(percentEncoded: false),
            reportPath: options.reportOutputURL?.path(percentEncoded: false),
            semanticReport: semanticReport,
            importReport: importResult.report
        )
    }

    private static func combinedCorpusReport(options: DRCCorpusCoverageAuditCLIOptions) throws -> DRCCorpusReport {
        let primaryReport = try loadCorpusReport(from: options.reportURL).report
        let includedReports = try options.includedReportURLs.map { try loadCorpusReport(from: $0).report }
        return DRCCorpusReportCombiner().combine(primaryReport: primaryReport, includedReports: includedReports)
    }

    private static func corpusCoverageAuditPolicy(
        options: DRCCorpusCoverageAuditCLIOptions
    ) throws -> DRCCorpusCoverageAuditPolicy {
        guard let policyURL = options.policyURL else {
            return .magicFoundryExpansion
        }
        let policyData = try Data(contentsOf: policyURL)
        return try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: policyData)
    }

    private static func corpusCoverageAudit(
        options: DRCCorpusCoverageAuditCLIOptions,
        report: DRCCorpusReport,
        policy: DRCCorpusCoverageAuditPolicy
    ) -> DRCCorpusCoverageAudit {
        DRCCorpusCoverageAuditor().audit(
            report: report,
            reportPath: options.reportURL.path(percentEncoded: false),
            policy: policy,
            auditID: options.auditID,
            checkedAt: options.checkedAt
        )
    }

    private static func loadCorpusReport(from reportURL: URL) throws -> LoadedCorpusReport {
        let reportData = try Data(contentsOf: reportURL)
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
        return LoadedCorpusReport(data: reportData, report: report)
    }

    private static func corpusQualification(
        report: DRCCorpusReport,
        options: DRCCorpusQualificationCLIOptions
    ) throws -> DRCCorpusQualificationResult {
        guard let qualificationPolicyURL = options.qualificationPolicyURL else {
            return report.qualification
        }
        let policyData = try Data(contentsOf: qualificationPolicyURL)
        let policy = try JSONDecoder().decode(DRCCorpusQualificationPolicy.self, from: policyData)
        return policy.evaluate(passed: report.passed, caseCount: report.caseCount, summary: report.summary)
    }

    private static func emitFoundryDeckSemanticReport(
        _ report: SignoffDeckSemanticReport,
        options: DRCFoundryDeckSemanticCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        if options.emitJSON {
            try emit(output: report, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(report.status.rawValue)")
        writer.writeStandardOutputLine("kind=\(report.kind)")
        if let pdkRoot = report.pdkRoot {
            writer.writeStandardOutputLine("pdk_root=\(pdkRoot)")
        }
        for result in report.coverageTagResults {
            writer.writeStandardOutputLine("\(result.tag)=\(result.status.rawValue) evidence=\(result.evidenceCount)")
        }
    }

    private static func emitCapabilities(
        _ snapshot: DRCCapabilitySnapshot,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: snapshot, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("engine=\(snapshot.engineID)")
        writer.writeStandardOutputLine("status=\(snapshot.status)")
        writer.writeStandardOutputLine("preferred_backend=\(snapshot.preferredBackendID)")
        writer.writeStandardOutputLine("backends=\(snapshot.backends.map(\.backendID).joined(separator: ","))")
        writer.writeStandardOutputLine("corpus=\(snapshot.corpus.committedSpecPath)")
    }

    private static func emitRepairHints(
        _ report: DRCRepairHintReport,
        options: DRCRepairHintsCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        if options.emitJSON {
            try emit(output: report, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(report.status)")
        writer.writeStandardOutputLine("report=\(options.reportURL.path(percentEncoded: false))")
        writer.writeStandardOutputLine("active_diagnostics=\(report.activeDiagnosticCount)")
        writer.writeStandardOutputLine("hints=\(report.hintCount)")
        if !report.unsupportedDiagnosticIndexes.isEmpty {
            writer.writeStandardOutputLine("unsupported_diagnostics=\(report.unsupportedDiagnosticIndexes.map(String.init).joined(separator: ","))")
        }
    }

    private static func emitReportSummary(
        _ report: DRCRunSummaryReport,
        options: DRCReportSummaryCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        if options.emitJSON {
            try emit(output: report, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(report.summary.status)")
        writer.writeStandardOutputLine("report=\(options.reportURL.path(percentEncoded: false))")
        writer.writeStandardOutputLine("active_violations=\(report.summary.activeViolationCount)")
        writer.writeStandardOutputLine("waived_violations=\(report.summary.waivedViolationCount)")
        writer.writeStandardOutputLine("buckets=\(report.summary.violationBuckets.count)")
    }

    private static func emitActionDomain(
        _ snapshot: DRCActionDomainSnapshot,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: snapshot, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("action_domain=\(snapshot.domainID)")
        writer.writeStandardOutputLine("operations=\(snapshot.operations.count)")
    }

    private static func emitCorpusCoverageAudit(
        _ audit: DRCCorpusCoverageAudit,
        options: DRCCorpusCoverageAuditCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        if options.emitJSON {
            try emit(output: audit, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(audit.status.rawValue)")
        writer.writeStandardOutputLine("policy=\(audit.policyID)")
        writer.writeStandardOutputLine("missing_requirements=\(audit.summary.missingRequirementCount)")
        if let outputURL = options.outputURL {
            writer.writeStandardOutputLine("audit=\(outputURL.path(percentEncoded: false))")
        }
    }

    private static func emitEvidencePacket(
        _ packet: DRCEvidencePacket,
        options: DRCEvidencePacketCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        try validateEvidencePacket(packet)
        if options.emitJSON {
            try emit(output: packet, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=packet-produced")
        writer.writeStandardOutputLine("packet_id=\(packet.packetID)")
        writer.writeStandardOutputLine("diagnostics=\(packet.diagnostics.count)")
        writer.writeStandardOutputLine("decision_hints=\(packet.decisionHints.count)")
        if let outputURL = options.outputURL {
            writer.writeStandardOutputLine("packet=\(outputURL.path(percentEncoded: false))")
        }
    }

    private static func validateEvidencePacket(_ packet: DRCEvidencePacket) throws {
        let integrityIssues = packet.validateIntegrity()
        if !integrityIssues.isEmpty {
            let issueCodes = integrityIssues.map(\.code).joined(separator: ",")
            throw DRCError.invalidInput("DRC evidence packet failed integrity validation: \(issueCodes)")
        }
    }

    private static func validateCorpusCoverageAudit(_ audit: DRCCorpusCoverageAudit) throws {
        let integrityIssues = audit.validateIntegrity()
        if !integrityIssues.isEmpty {
            let issueCodes = integrityIssues.map(\.code).joined(separator: ",")
            throw DRCError.invalidInput("DRC corpus coverage audit failed integrity validation: \(issueCodes)")
        }
    }

    private static func emitCorpusEvidence(
        _ output: DRCCorpusToolEvidenceExport,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: output, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(output.status)")
        writer.writeStandardOutputLine("evidence_id=\(output.toolEvidence.evidenceID)")
        writer.writeStandardOutputLine("report=\(output.reportPath)")
    }

    private static func emitCorpusQualification(
        report: DRCCorpusReport,
        qualification: DRCCorpusQualificationResult,
        options: DRCCorpusQualificationCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        if options.emitJSON {
            let output = DRCCorpusQualificationCLIOutput(
                reportPath: options.reportURL.path(percentEncoded: false),
                report: report,
                qualification: qualification
            )
            try emit(output: output, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(qualification.qualified ? "passed" : "failed")")
        writer.writeStandardOutputLine("report=\(options.reportURL.path(percentEncoded: false))")
        if !qualification.failures.isEmpty {
            writer.writeStandardOutputLine("failures=\(qualification.failures.map(\.code).joined(separator: ","))")
        }
    }

    private static func emitCorpus(
        _ report: DRCCorpusReport,
        options: DRCCorpusCLIOptions,
        writer: DRCCLIOutputWriter
    ) throws {
        let reportURL = options.outputDirectory.appending(path: "drc-corpus-report.json")
        if options.emitJSON {
            let output = DRCCorpusCLIOutput(reportPath: reportURL.path(percentEncoded: false), report: report)
            try emit(output: output, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(report.qualification.qualified ? "passed" : "failed")")
        writer.writeStandardOutputLine("report=\(reportURL.path(percentEncoded: false))")
    }

    private static func emitDefaultDRC(
        _ result: DRCExecutionResult,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: DRCCLIOutput(result: result), json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(result.result.passed ? "passed" : "failed")")
        if let reportURL = result.reportURL {
            writer.writeStandardOutputLine("report=\(reportURL.path(percentEncoded: false))")
        }
        if let manifestURL = result.artifactManifestURL {
            writer.writeStandardOutputLine("manifest=\(manifestURL.path(percentEncoded: false))")
        }
    }

    private static func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func defaultSignoffPDKProfile() throws -> SignoffPDKProfile {
        try SignoffPDKProfile.bundledDefaultProfile()
    }

    private static func drcMagicDeckRequirements(from profile: SignoffPDKProfile) -> [SignoffDeckRequirement] {
        profile.deckRequirements(domain: "drc", backendID: "magic")
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private static func emit<T: Encodable>(
        output: T,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)
            writer.writeStandardOutput(data)
            writer.writeStandardOutputLine("")
        }
    }

    private static func emitFoundryRuleImportOutput(
        _ output: DRCFoundryRuleImportCLIOutput,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: output, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(output.status)")
        if let technologyPath = output.technologyPath {
            writer.writeStandardOutputLine("technology=\(technologyPath)")
        }
        if let reportPath = output.reportPath {
            writer.writeStandardOutputLine("report=\(reportPath)")
        }
        if let importReport = output.importReport {
            writer.writeStandardOutputLine("imported_rules=\(importReport.importedRuleCount)")
            writer.writeStandardOutputLine("skipped_rules=\(importReport.skippedRuleCount)")
            writer.writeStandardOutputLine("layers=\(importReport.importedLayerNames.joined(separator: ","))")
        } else {
            writer.writeStandardOutputLine("semantic_status=\(output.semanticReport.status.rawValue)")
        }
    }

    private static func emitMagicRuleImportOutput(
        _ output: DRCMagicRuleImportCLIOutput,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: output, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(output.status)")
        writer.writeStandardOutputLine("technology=\(output.technologyPath)")
        if let reportPath = output.reportPath {
            writer.writeStandardOutputLine("report=\(reportPath)")
        }
        writer.writeStandardOutputLine("source=\(output.sourcePath)")
        writer.writeStandardOutputLine("profile=\(output.profilePath)")
        if let profileResourceName = output.profileResourceName {
            writer.writeStandardOutputLine("profile_resource=\(profileResourceName)")
        }
        if let catalogPath = output.catalogPath {
            writer.writeStandardOutputLine("catalog=\(catalogPath)")
        }
        if let technologyCatalogID = output.technologyCatalogID {
            writer.writeStandardOutputLine("catalog_id=\(technologyCatalogID)")
        }
        if let pdkID = output.pdkID {
            writer.writeStandardOutputLine("pdk_id=\(pdkID)")
        }
        if let profileID = output.profileID {
            writer.writeStandardOutputLine("profile_id=\(profileID)")
        }
        writer.writeStandardOutputLine("imported_rules=\(output.importReport.importedRuleCount)")
        writer.writeStandardOutputLine("skipped_rules=\(output.importReport.skippedRuleCount)")
        writer.writeStandardOutputLine("layers=\(output.importReport.importedLayerNames.joined(separator: ","))")
    }

    private static func emitMagicRuleImportCatalogInventoryOutput(
        _ inventory: DRCMagicRuleImportCatalogInventory,
        json: Bool,
        writer: DRCCLIOutputWriter
    ) throws {
        if json {
            try emit(output: inventory, json: true, writer: writer)
            return
        }
        writer.writeStandardOutputLine("status=\(inventory.status.rawValue)")
        writer.writeStandardOutputLine("catalogs=\(inventory.catalogCount)")
        for catalog in inventory.catalogs {
            writer.writeStandardOutputLine("catalog=\(catalog.catalogPath) status=\(catalog.status.rawValue) entries=\(catalog.entryCount)")
        }
        let issueCodes = inventory.issues.map(\.code)
            + inventory.pdkRoots.flatMap { $0.issues.map(\.code) }
            + inventory.catalogs.flatMap { $0.issues.map(\.code) }
            + inventory.catalogs.flatMap { $0.entries.flatMap { $0.issues.map(\.code) } }
        if !issueCodes.isEmpty {
            writer.writeStandardOutputLine("issues=\(issueCodes.joined(separator: ","))")
        }
    }
}
