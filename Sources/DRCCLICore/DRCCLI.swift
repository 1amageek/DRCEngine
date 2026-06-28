import Foundation
import CryptoKit
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

public enum DRCCLI {
    public static let availableBackends = [
        "native",
        "native-gds",
        "magic",
    ]

    public static func run(arguments: [String]) async -> Int32 {
        do {
            if arguments == ["--list-backends"] {
                for backendID in availableBackends {
                    print(backendID)
                }
                return 0
            }
            if arguments.contains("--inspect-magic-rule-import-catalog") {
                let options = try DRCMagicRuleImportCatalogInventoryCLIOptions(arguments: arguments)
                let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
                    catalogURLs: options.catalogURLs,
                    pdkRootURLs: options.pdkRootURLs
                )
                if let outputURL = options.outputURL {
                    try writeJSON(inventory, to: outputURL)
                }
                try emitMagicRuleImportCatalogInventoryOutput(inventory, json: options.emitJSON)
                return options.requirePassed && inventory.status != .passed ? 2 : 0
            }
            if arguments.contains("--import-magic-rules") {
                let options = try DRCMagicRuleImportCLIOptions(arguments: arguments)
                let profile = try MagicDRCLayoutTechImportProfile.load(from: options.profileURL)
                let importResult = try MagicDRCLayoutTechImporter.importTechnology(
                    from: options.magicTechURL,
                    profile: profile
                )
                try writeJSON(importResult.technology, to: options.technologyOutputURL)
                if let reportOutputURL = options.reportOutputURL {
                    try writeJSON(importResult.report, to: reportOutputURL)
                }
                let output = DRCMagicRuleImportCLIOutput(
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
                try emitMagicRuleImportOutput(output, json: options.emitJSON)
                if importResult.report.status == .blocked {
                    return 2
                }
                return options.requireComplete && importResult.report.status != .complete ? 2 : 0
            }
            let importsFoundryMagicRules = arguments.contains(DRCFoundryRuleImportCLIOptions.importFlag)
                || arguments.contains(DRCFoundryRuleImportCLIOptions.deprecatedCompatibilityImportFlag)
            if importsFoundryMagicRules {
                let options = try DRCFoundryRuleImportCLIOptions(arguments: arguments)
                let environment = options.environment(overriding: ProcessInfo.processInfo.environment)
                let signoffProfile = try defaultSignoffPDKProfile()
                let semanticReport = SignoffDeckSemanticInventory.inspect(
                    profile: signoffProfile,
                    requirements: drcMagicDeckRequirements(from: signoffProfile),
                    environment: environment
                )
                guard semanticReport.status == .passed, let pdkRoot = semanticReport.pdkRoot else {
                    let output = DRCFoundryRuleImportCLIOutput(
                        technologyPath: nil,
                        reportPath: nil,
                        semanticReport: semanticReport,
                        importReport: nil
                    )
                    try emitFoundryRuleImportOutput(output, json: options.emitJSON)
                    return 2
                }

                let bundledProfileResourceName = options.profileResourceName ?? "sky130-magic-layouttech-profile"
                let profile = try options.profileURL.map(MagicDRCLayoutTechImportProfile.load)
                    ?? MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
                        resourceName: bundledProfileResourceName
                    )
                let importResult = try MagicDRCLayoutTechImporter.importTechnology(
                    from: SignoffPDKLocator.requiredFileURL(
                        in: pdkRoot,
                        profile: signoffProfile,
                        requirementID: "magic-tech"
                    ),
                    profile: profile,
                    generatedAt: semanticReport.generatedAt
                )
                try writeJSON(importResult.technology, to: options.technologyOutputURL)
                if let reportOutputURL = options.reportOutputURL {
                    try writeJSON(importResult.report, to: reportOutputURL)
                }
                let output = DRCFoundryRuleImportCLIOutput(
                    technologyPath: options.technologyOutputURL.path(percentEncoded: false),
                    reportPath: options.reportOutputURL?.path(percentEncoded: false),
                    semanticReport: semanticReport,
                    importReport: importResult.report
                )
                try emitFoundryRuleImportOutput(output, json: options.emitJSON)
                if importResult.report.status == .blocked {
                    return 2
                }
                return options.requireComplete && importResult.report.status != .complete ? 2 : 0
            }
            if arguments.contains("--foundry-deck-semantics") {
                let options = try DRCFoundryDeckSemanticCLIOptions(arguments: arguments)
                let signoffProfile = try defaultSignoffPDKProfile()
                let report = SignoffDeckSemanticInventory.inspect(
                    profile: signoffProfile,
                    requirements: drcMagicDeckRequirements(from: signoffProfile),
                    environment: options.environment(overriding: ProcessInfo.processInfo.environment)
                )
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(report)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(report.status.rawValue)")
                    print("kind=\(report.kind)")
                    if let pdkRoot = report.pdkRoot {
                        print("pdk_root=\(pdkRoot)")
                    }
                    for result in report.coverageTagResults {
                        print("\(result.tag)=\(result.status.rawValue) evidence=\(result.evidenceCount)")
                    }
                }
                return options.requirePassed && report.status != .passed ? 2 : 0
            }
            if arguments.contains("--capabilities") {
                let options = try DRCCapabilityCLIOptions(arguments: arguments)
                let snapshot = DRCCapabilitySnapshotProvider().snapshot()
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(snapshot)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("engine=\(snapshot.engineID)")
                    print("status=\(snapshot.status)")
                    print("preferred_backend=\(snapshot.preferredBackendID)")
                    print("backends=\(snapshot.backends.map(\.backendID).joined(separator: ","))")
                    print("corpus=\(snapshot.corpus.committedSpecPath)")
                }
                return 0
            }
            if arguments.contains("--repair-hints-from-report") {
                let options = try DRCRepairHintsCLIOptions(arguments: arguments)
                let report = try DRCRepairHintBuilder().build(reportURL: options.reportURL)
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(report)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(report.status)")
                    print("report=\(options.reportURL.path(percentEncoded: false))")
                    print("active_diagnostics=\(report.activeDiagnosticCount)")
                    print("hints=\(report.hintCount)")
                    if !report.unsupportedDiagnosticIndexes.isEmpty {
                        print("unsupported_diagnostics=\(report.unsupportedDiagnosticIndexes.map(String.init).joined(separator: ","))")
                    }
                }
                return 0
            }
            if arguments.contains("--action-domain") {
                let options = try DRCActionDomainCLIOptions(arguments: arguments)
                let snapshot = DRCActionDomainExporter().snapshot()
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(snapshot)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("action_domain=\(snapshot.domainID)")
                    print("operations=\(snapshot.operations.count)")
                }
                return 0
            }
            if arguments.contains("--audit-corpus-coverage") {
                let options = try DRCCorpusCoverageAuditCLIOptions(arguments: arguments)
                let reportData = try Data(contentsOf: options.reportURL)
                let primaryReport = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
                let includedReports = try options.includedReportURLs.map { reportURL in
                    let data = try Data(contentsOf: reportURL)
                    return try JSONDecoder().decode(DRCCorpusReport.self, from: data)
                }
                let report = DRCCorpusReportCombiner().combine(
                    primaryReport: primaryReport,
                    includedReports: includedReports
                )
                let policy: DRCCorpusCoverageAuditPolicy
                if let policyURL = options.policyURL {
                    let policyData = try Data(contentsOf: policyURL)
                    policy = try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: policyData)
                } else {
                    policy = .magicFoundryExpansion
                }
                let audit = DRCCorpusCoverageAuditor().audit(
                    report: report,
                    reportPath: options.reportURL.path(percentEncoded: false),
                    policy: policy,
                    auditID: options.auditID
                )
                if let outputURL = options.outputURL {
                    try writeJSON(audit, to: outputURL)
                }
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(audit)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(audit.status.rawValue)")
                    print("policy=\(audit.policyID)")
                    print("missing_requirements=\(audit.summary.missingRequirementCount)")
                    if let outputURL = options.outputURL {
                        print("audit=\(outputURL.path(percentEncoded: false))")
                    }
                }
                return audit.status == .satisfied ? 0 : 2
            }
            if arguments.contains("--evidence-packet-from-corpus-report") {
                let options = try DRCEvidencePacketCLIOptions(arguments: arguments)
                let reportData = try Data(contentsOf: options.reportURL)
                let report = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
                let packet = DRCCorpusEvidencePacketBuilder().build(
                    report: report,
                    reportPath: options.reportURL.path(percentEncoded: false),
                    reportSHA256: sha256(data: reportData),
                    packetID: options.packetID
                )
                if let outputURL = options.outputURL {
                    try FileManager.default.createDirectory(
                        at: outputURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(packet)
                    try data.write(to: outputURL)
                }
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(packet)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=packet-produced")
                    print("packet_id=\(packet.packetID)")
                    print("diagnostics=\(packet.diagnostics.count)")
                    print("decision_hints=\(packet.decisionHints.count)")
                    if let outputURL = options.outputURL {
                        print("packet=\(outputURL.path(percentEncoded: false))")
                    }
                }
                return 0
            }
            if arguments.contains("--evidence-from-corpus-report") {
                let options = try DRCCorpusEvidenceCLIOptions(arguments: arguments)
                let reportData = try Data(contentsOf: options.reportURL)
                let report = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
                let output = DRCCorpusToolEvidenceExport(
                    reportPath: options.reportURL.path(percentEncoded: false),
                    reportSHA256: sha256(data: reportData),
                    report: report,
                    evidenceID: options.evidenceID,
                    checkedAt: options.checkedAt
                )
                if options.emitJSON {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(output)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(output.status)")
                    print("evidence_id=\(output.toolEvidence.evidenceID)")
                    print("report=\(output.reportPath)")
                }
                return output.toolEvidence.qualification.qualified ? 0 : 2
            }
            if arguments.contains("--qualify-corpus-report") {
                let options = try DRCCorpusQualificationCLIOptions(arguments: arguments)
                let reportData = try Data(contentsOf: options.reportURL)
                let report = try JSONDecoder().decode(DRCCorpusReport.self, from: reportData)
                let qualification: DRCCorpusQualificationResult
                if let qualificationPolicyURL = options.qualificationPolicyURL {
                    let policyData = try Data(contentsOf: qualificationPolicyURL)
                    let policy = try JSONDecoder().decode(DRCCorpusQualificationPolicy.self, from: policyData)
                    qualification = policy.evaluate(
                        passed: report.passed,
                        caseCount: report.caseCount,
                        summary: report.summary
                    )
                } else {
                    qualification = report.qualification
                }
                if options.emitJSON {
                    let output = DRCCorpusQualificationCLIOutput(
                        reportPath: options.reportURL.path(percentEncoded: false),
                        report: report,
                        qualification: qualification
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(output)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(qualification.qualified ? "passed" : "failed")")
                    print("report=\(options.reportURL.path(percentEncoded: false))")
                    if !qualification.failures.isEmpty {
                        print("failures=\(qualification.failures.map(\.code).joined(separator: ","))")
                    }
                }
                return qualification.qualified ? 0 : 2
            }
            if arguments.contains("--corpus") {
                let options = try DRCCorpusCLIOptions(arguments: arguments)
                let report = try await DRCCorpusRunner().run(
                    specURL: options.specURL,
                    outputDirectory: options.outputDirectory,
                    options: options.runOptions
                )
                let reportURL = options.outputDirectory.appending(path: "drc-corpus-report.json")
                if options.emitJSON {
                    let output = DRCCorpusCLIOutput(
                        reportPath: reportURL.path(percentEncoded: false),
                        report: report
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(output)
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                } else {
                    print("status=\(report.qualification.qualified ? "passed" : "failed")")
                    print("report=\(reportURL.path(percentEncoded: false))")
                }
                return report.qualification.qualified ? 0 : 2
            }
            let options = try DRCCLIOptions(arguments: arguments)
            let result = try await DefaultDRCEngine().run(options.makeRequest())
            if options.emitJSON {
                let output = DRCCLIOutput(result: result)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(output)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } else {
                print("status=\(result.result.passed ? "passed" : "failed")")
                if let reportURL = result.reportURL {
                    print("report=\(reportURL.path(percentEncoded: false))")
                }
                if let manifestURL = result.artifactManifestURL {
                    print("manifest=\(manifestURL.path(percentEncoded: false))")
                }
            }
            return result.result.passed ? 0 : 2
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            return 1
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

    private static func emit<T: Encodable>(output: T, json: Bool) throws {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private static func emitFoundryRuleImportOutput(
        _ output: DRCFoundryRuleImportCLIOutput,
        json: Bool
    ) throws {
        if json {
            try emit(output: output, json: true)
            return
        }
        print("status=\(output.status)")
        if let technologyPath = output.technologyPath {
            print("technology=\(technologyPath)")
        }
        if let reportPath = output.reportPath {
            print("report=\(reportPath)")
        }
        if let importReport = output.importReport {
            print("imported_rules=\(importReport.importedRuleCount)")
            print("skipped_rules=\(importReport.skippedRuleCount)")
            print("layers=\(importReport.importedLayerNames.joined(separator: ","))")
        } else {
            print("semantic_status=\(output.semanticReport.status.rawValue)")
        }
    }

    private static func emitMagicRuleImportOutput(
        _ output: DRCMagicRuleImportCLIOutput,
        json: Bool
    ) throws {
        if json {
            try emit(output: output, json: true)
            return
        }
        print("status=\(output.status)")
        print("technology=\(output.technologyPath)")
        if let reportPath = output.reportPath {
            print("report=\(reportPath)")
        }
        print("source=\(output.sourcePath)")
        print("profile=\(output.profilePath)")
        if let profileResourceName = output.profileResourceName {
            print("profile_resource=\(profileResourceName)")
        }
        if let catalogPath = output.catalogPath {
            print("catalog=\(catalogPath)")
        }
        if let technologyCatalogID = output.technologyCatalogID {
            print("catalog_id=\(technologyCatalogID)")
        }
        if let pdkID = output.pdkID {
            print("pdk_id=\(pdkID)")
        }
        if let profileID = output.profileID {
            print("profile_id=\(profileID)")
        }
        print("imported_rules=\(output.importReport.importedRuleCount)")
        print("skipped_rules=\(output.importReport.skippedRuleCount)")
        print("layers=\(output.importReport.importedLayerNames.joined(separator: ","))")
    }

    private static func emitMagicRuleImportCatalogInventoryOutput(
        _ inventory: DRCMagicRuleImportCatalogInventory,
        json: Bool
    ) throws {
        if json {
            try emit(output: inventory, json: true)
            return
        }
        print("status=\(inventory.status.rawValue)")
        print("catalogs=\(inventory.catalogCount)")
        for catalog in inventory.catalogs {
            print("catalog=\(catalog.catalogPath) status=\(catalog.status.rawValue) entries=\(catalog.entryCount)")
        }
        let issueCodes = inventory.issues.map(\.code)
            + inventory.pdkRoots.flatMap { $0.issues.map(\.code) }
            + inventory.catalogs.flatMap { $0.issues.map(\.code) }
            + inventory.catalogs.flatMap { $0.entries.flatMap { $0.issues.map(\.code) } }
        if !issueCodes.isEmpty {
            print("issues=\(issueCodes.joined(separator: ","))")
        }
    }
}
