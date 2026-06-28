import Foundation
import DRCEngine
import SignoffToolSupport

public struct DRCCLIOptions: Sendable, Hashable {
    public let layoutURL: URL
    public let topCell: String
    public let layoutFormat: DRCLayoutFormat?
    public let technologyURL: URL?
    public let waiverURL: URL?
    public let backendID: String?
    public let outputDirectory: URL
    public let timeoutSeconds: Double
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var layoutURL: URL?
        var topCell: String?
        var layoutFormat: DRCLayoutFormat?
        var technologyURL: URL?
        var waiverURL: URL?
        var backendID: String?
        var outputDirectory: URL?
        var timeoutSeconds = 300.0
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--layout":
                layoutURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--top-cell":
                topCell = try Self.value(after: argument, in: arguments, index: &index)
            case "--format":
                let value = try Self.value(after: argument, in: arguments, index: &index)
                guard let format = DRCLayoutFormat(rawValue: value) else {
                    throw DRCCLIError.invalidValue(
                        argument: argument,
                        value: value,
                        expected: "auto, gds, oasis, cif, dxf, native-json, or magic-layout"
                    )
                }
                layoutFormat = format
            case "--out":
                outputDirectory = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--tech":
                technologyURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--waivers":
                waiverURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--backend":
                backendID = try Self.value(after: argument, in: arguments, index: &index)
            case "--timeout":
                timeoutSeconds = try Self.positiveFiniteDouble(after: argument, in: arguments, index: &index)
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }

        guard let layoutURL else { throw DRCCLIError.missingRequired("--layout") }
        guard let topCell else { throw DRCCLIError.missingRequired("--top-cell") }
        guard let outputDirectory else { throw DRCCLIError.missingRequired("--out") }
        self.layoutURL = layoutURL
        self.topCell = topCell
        self.layoutFormat = layoutFormat
        self.technologyURL = technologyURL
        self.waiverURL = waiverURL
        self.backendID = backendID
        self.outputDirectory = outputDirectory
        self.timeoutSeconds = timeoutSeconds
        self.emitJSON = emitJSON
    }

    public func makeRequest() -> DRCRequest {
        // A technology deck implies the standard-input Native
        // backend unless the caller chose one explicitly.
        let resolvedBackendID = backendID ?? (technologyURL != nil ? "native-gds" : "magic")
        return DRCRequest(
            layoutURL: layoutURL,
            topCell: topCell,
            layoutFormat: layoutFormat,
            technologyURL: technologyURL,
            waiverURL: waiverURL,
            workingDirectory: outputDirectory,
            backendSelection: DRCBackendSelection(backendID: resolvedBackendID),
            options: DRCOptions(timeoutSeconds: timeoutSeconds)
        )
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func positiveFiniteDouble(after argument: String, in arguments: [String], index: inout Int) throws -> Double {
        let rawValue = try value(after: argument, in: arguments, index: &index)
        guard let value = Double(rawValue), value.isFinite, value > 0 else {
            throw DRCCLIError.invalidValue(argument: argument, value: rawValue, expected: "positive finite seconds")
        }
        return value
    }
}

public struct DRCCorpusCLIOptions: Sendable, Hashable {
    public let specURL: URL
    public let outputDirectory: URL
    public let oracleBackendIDOverride: String?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var specURL: URL?
        var outputDirectory: URL?
        var oracleBackendIDOverride: String?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--corpus":
                specURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--out":
                outputDirectory = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--oracle-backend":
                oracleBackendIDOverride = try Self.nonEmptyValue(after: argument, in: arguments, index: &index)
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let specURL else { throw DRCCLIError.missingRequired("--corpus") }
        guard let outputDirectory else { throw DRCCLIError.missingRequired("--out") }
        self.specURL = specURL
        self.outputDirectory = outputDirectory
        self.oracleBackendIDOverride = oracleBackendIDOverride
        self.emitJSON = emitJSON
    }

    public var runOptions: DRCCorpusRunOptions {
        DRCCorpusRunOptions(oracleBackendIDOverride: oracleBackendIDOverride)
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty backend ID")
        }
        return value
    }
}

public struct DRCCorpusQualificationCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let qualificationPolicyURL: URL?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var qualificationPolicyURL: URL?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--qualify-corpus-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--qualification-policy":
                qualificationPolicyURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else { throw DRCCLIError.missingRequired("--qualify-corpus-report") }
        self.reportURL = reportURL
        self.qualificationPolicyURL = qualificationPolicyURL
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

public struct DRCCorpusCoverageAuditCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let includedReportURLs: [URL]
    public let policyURL: URL?
    public let outputURL: URL?
    public let auditID: String?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var includedReportURLs: [URL] = []
        var policyURL: URL?
        var outputURL: URL?
        var auditID: String?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--audit-corpus-coverage":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--include-corpus-report":
                includedReportURLs.append(URL(filePath: try Self.value(after: argument, in: arguments, index: &index)))
            case "--coverage-policy":
                policyURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--out":
                outputURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--audit-id":
                auditID = try Self.value(after: argument, in: arguments, index: &index)
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else {
            throw DRCCLIError.missingRequired("--audit-corpus-coverage")
        }
        self.reportURL = reportURL
        self.includedReportURLs = includedReportURLs
        self.policyURL = policyURL
        self.outputURL = outputURL
        self.auditID = auditID
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

public struct DRCCorpusEvidenceCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let evidenceID: String?
    public let checkedAt: Date
    public let emitJSON: Bool

    public init(arguments: [String], now: Date = Date()) throws {
        var reportURL: URL?
        var evidenceID: String?
        var checkedAt = now
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--evidence-from-corpus-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--evidence-id":
                evidenceID = try Self.value(after: argument, in: arguments, index: &index)
            case "--checked-at":
                let value = try Self.value(after: argument, in: arguments, index: &index)
                checkedAt = try Self.iso8601Date(argument: argument, value: value)
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else { throw DRCCLIError.missingRequired("--evidence-from-corpus-report") }
        self.reportURL = reportURL
        self.evidenceID = evidenceID
        self.checkedAt = checkedAt
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func iso8601Date(argument: String, value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        throw DRCCLIError.invalidValue(
            argument: argument,
            value: value,
            expected: "ISO 8601 timestamp"
        )
    }
}

public struct DRCEvidencePacketCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let outputURL: URL?
    public let packetID: String?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var outputURL: URL?
        var packetID: String?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--evidence-packet-from-corpus-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--out":
                outputURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--packet-id":
                packetID = try Self.value(after: argument, in: arguments, index: &index)
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else {
            throw DRCCLIError.missingRequired("--evidence-packet-from-corpus-report")
        }
        self.reportURL = reportURL
        self.outputURL = outputURL
        self.packetID = packetID
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

public struct DRCActionDomainCLIOptions: Sendable, Hashable {
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawActionDomain = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--action-domain":
                sawActionDomain = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawActionDomain else { throw DRCCLIError.missingRequired("--action-domain") }
        self.emitJSON = emitJSON
    }
}

public struct DRCFoundryDeckSemanticCLIOptions: Sendable, Hashable {
    public let pdkRoot: String?
    public let requirePassed: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawFoundryDeckSemantics = false
        var pdkRoot: String?
        var requirePassed = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--foundry-deck-semantics":
                sawFoundryDeckSemantics = true
            case "--pdk-root":
                pdkRoot = try Self.nonEmptyValue(after: argument, in: arguments, index: &index)
            case "--require-passed":
                requirePassed = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawFoundryDeckSemantics else { throw DRCCLIError.missingRequired("--foundry-deck-semantics") }
        self.pdkRoot = pdkRoot
        self.requirePassed = requirePassed
        self.emitJSON = emitJSON
    }

    public func environment(overriding base: [String: String]) -> [String: String] {
        var environment = base
        if let pdkRoot {
            environment["PDK_ROOT"] = pdkRoot
        }
        return environment
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty path")
        }
        return value
    }
}

public struct DRCFoundryRuleImportCLIOptions: Sendable, Hashable {
    public static let importFlag = "--import-foundry-magic-rules"
    public static let deprecatedCompatibilityImportFlag = "--import-sky130-magic-rules"

    public let pdkRoot: String?
    public let profileURL: URL?
    public let profileResourceName: String?
    public let technologyOutputURL: URL
    public let reportOutputURL: URL?
    public let requireComplete: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawImport = false
        var pdkRoot: String?
        var profileURL: URL?
        var profileResourceName: String?
        var technologyOutputURL: URL?
        var reportOutputURL: URL?
        var requireComplete = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case Self.importFlag, Self.deprecatedCompatibilityImportFlag:
                sawImport = true
            case "--pdk-root":
                pdkRoot = try Self.nonEmptyValue(after: argument, in: arguments, index: &index)
            case "--profile":
                profileURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--profile-resource":
                profileResourceName = try Self.nonEmptyResourceName(after: argument, in: arguments, index: &index)
            case "--tech-out":
                technologyOutputURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--report-out":
                reportOutputURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--require-complete":
                requireComplete = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawImport else { throw DRCCLIError.missingRequired(Self.importFlag) }
        if let profileURL, let profileResourceName {
            throw DRCCLIError.invalidValue(
                argument: "--profile-resource",
                value: profileResourceName,
                expected: "only one of --profile or --profile-resource; received \(profileURL.path(percentEncoded: false))"
            )
        }
        guard let technologyOutputURL else { throw DRCCLIError.missingRequired("--tech-out") }
        self.pdkRoot = pdkRoot
        self.profileURL = profileURL
        self.profileResourceName = profileResourceName
        self.technologyOutputURL = technologyOutputURL
        self.reportOutputURL = reportOutputURL
        self.requireComplete = requireComplete
        self.emitJSON = emitJSON
    }

    public func environment(overriding base: [String: String]) -> [String: String] {
        var environment = base
        if let pdkRoot {
            environment["PDK_ROOT"] = pdkRoot
        }
        return environment
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty path")
        }
        return value
    }

    private static func nonEmptyResourceName(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty profile resource name")
        }
        return value
    }
}

public struct DRCMagicRuleImportCLIOptions: Sendable, Hashable {
    public let magicTechURL: URL
    public let profileURL: URL
    public let profileResourceName: String?
    public let catalogURL: URL?
    public let technologyCatalogID: String?
    public let pdkID: String?
    public let profileID: String?
    public let technologyOutputURL: URL
    public let reportOutputURL: URL?
    public let requireComplete: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawImport = false
        var magicTechURL: URL?
        var profileURL: URL?
        var profileResourceName: String?
        var catalogURL: URL?
        var technologyCatalogID: String?
        var pdkID: String?
        var profileID: String?
        var pdkRootURL: URL?
        var technologyOutputURL: URL?
        var reportOutputURL: URL?
        var requireComplete = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--import-magic-rules":
                sawImport = true
            case "--magic-tech":
                magicTechURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--profile":
                profileURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--profile-resource":
                profileResourceName = try Self.nonEmptyResourceName(after: argument, in: arguments, index: &index)
            case "--catalog":
                catalogURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--catalog-id":
                technologyCatalogID = try Self.nonEmptyResourceName(after: argument, in: arguments, index: &index)
            case "--pdk-id":
                pdkID = try Self.nonEmptyResourceName(after: argument, in: arguments, index: &index)
            case "--profile-id":
                profileID = try Self.nonEmptyResourceName(after: argument, in: arguments, index: &index)
            case "--pdk-root":
                pdkRootURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--tech-out":
                technologyOutputURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--report-out":
                reportOutputURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--require-complete":
                requireComplete = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawImport else { throw DRCCLIError.missingRequired("--import-magic-rules") }
        if let profileURL, let profileResourceName {
            throw DRCCLIError.invalidValue(
                argument: "--profile-resource",
                value: profileResourceName,
                expected: "only one of --profile or --profile-resource; received \(profileURL.path(percentEncoded: false))"
            )
        }
        if let catalogURL {
            let resolvedImport = try DRCMagicRuleImportCatalogResolver(
                catalogURL: catalogURL,
                pdkRootURL: pdkRootURL
            ).resolve(selection: DRCMagicRuleImportCatalogResolver.Selection(
                technologyCatalogID: technologyCatalogID,
                pdkID: pdkID,
                profileID: profileID
            ), requireProfileReference: profileURL == nil && profileResourceName == nil)
            if magicTechURL == nil {
                magicTechURL = resolvedImport.magicTechURL
            }
            if profileURL == nil && profileResourceName == nil {
                profileURL = resolvedImport.profileURL
                profileResourceName = resolvedImport.profileResourceName
            }
            technologyCatalogID = technologyCatalogID ?? resolvedImport.technologyCatalogID
            pdkID = pdkID ?? resolvedImport.pdkID
            profileID = profileID ?? resolvedImport.profileID
        }
        guard let magicTechURL else { throw DRCCLIError.missingRequired("--magic-tech or --catalog") }
        let resolvedProfileURL: URL
        if let profileURL {
            resolvedProfileURL = profileURL
        } else if let profileResourceName {
            resolvedProfileURL = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfileURL(
                resourceName: profileResourceName
            )
        } else {
            throw DRCCLIError.missingRequired("--profile or --profile-resource")
        }
        guard let technologyOutputURL else { throw DRCCLIError.missingRequired("--tech-out") }
        self.magicTechURL = magicTechURL
        self.profileURL = resolvedProfileURL
        self.profileResourceName = profileResourceName
        self.catalogURL = catalogURL
        self.technologyCatalogID = technologyCatalogID
        self.pdkID = pdkID
        self.profileID = profileID
        self.technologyOutputURL = technologyOutputURL
        self.reportOutputURL = reportOutputURL
        self.requireComplete = requireComplete
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty path")
        }
        return value
    }

    private static func nonEmptyResourceName(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty profile resource name")
        }
        return value
    }
}

public struct DRCMagicRuleImportCatalogInventoryCLIOptions: Sendable, Hashable {
    public let catalogURLs: [URL]
    public let pdkRootURLs: [URL]
    public let outputURL: URL?
    public let requirePassed: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawInspect = false
        var catalogURLs: [URL] = []
        var pdkRootURLs: [URL] = []
        var outputURL: URL?
        var requirePassed = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--inspect-magic-rule-import-catalog":
                sawInspect = true
            case "--catalog":
                catalogURLs.append(URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index)))
            case "--pdk-root":
                pdkRootURLs.append(URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index)))
            case "--out":
                outputURL = URL(filePath: try Self.nonEmptyValue(after: argument, in: arguments, index: &index))
            case "--require-passed":
                requirePassed = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawInspect else { throw DRCCLIError.missingRequired("--inspect-magic-rule-import-catalog") }
        guard !catalogURLs.isEmpty || !pdkRootURLs.isEmpty else {
            throw DRCCLIError.missingRequired("--catalog or --pdk-root")
        }
        self.catalogURLs = catalogURLs
        self.pdkRootURLs = pdkRootURLs
        self.outputURL = outputURL
        self.requirePassed = requirePassed
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty path")
        }
        return value
    }
}

public struct DRCCapabilityCLIOptions: Sendable, Hashable {
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var sawCapabilities = false
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--capabilities":
                sawCapabilities = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard sawCapabilities else { throw DRCCLIError.missingRequired("--capabilities") }
        self.emitJSON = emitJSON
    }
}

public struct DRCRepairHintsCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--repair-hints-from-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else { throw DRCCLIError.missingRequired("--repair-hints-from-report") }
        self.reportURL = reportURL
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}
