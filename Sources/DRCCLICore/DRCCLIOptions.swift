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
    public let requireApprovedWaivers: Bool
    public let requireSignedArtifacts: Bool
    public let requireAntennaRules: Bool
    public let trustedArtifactPublicKey: String?
    public let artifactSigningPrivateKeyURL: URL?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        let parsed = try Self.parseArguments(arguments)
        self.layoutURL = try parsed.requireLayoutURL()
        self.topCell = try parsed.requireTopCell()
        self.layoutFormat = parsed.layoutFormat
        self.technologyURL = parsed.technologyURL
        self.waiverURL = parsed.waiverURL
        self.backendID = parsed.backendID
        self.outputDirectory = try parsed.requireOutputDirectory()
        self.timeoutSeconds = parsed.timeoutSeconds
        self.requireApprovedWaivers = parsed.requireApprovedWaivers
        self.requireSignedArtifacts = parsed.requireSignedArtifacts
        self.requireAntennaRules = parsed.requireAntennaRules
        self.trustedArtifactPublicKey = parsed.trustedArtifactPublicKey
        self.artifactSigningPrivateKeyURL = parsed.artifactSigningPrivateKeyURL
        if parsed.requireSignedArtifacts && parsed.artifactSigningPrivateKeyURL == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--artifact-signing-private-key must also be provided"
            )
        }
        if parsed.requireSignedArtifacts && parsed.trustedArtifactPublicKey == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--trusted-artifact-public-key must also be provided"
            )
        }
        self.emitJSON = parsed.emitJSON
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
            options: DRCOptions(
                timeoutSeconds: timeoutSeconds,
                requireApprovedWaivers: requireApprovedWaivers,
                requireSignedArtifacts: requireSignedArtifacts,
                trustedArtifactPublicKey: trustedArtifactPublicKey,
                requireAntennaRules: requireAntennaRules
            )
        )
    }

    public func makeArtifactStore() throws -> DRCArtifactStore {
        guard let artifactSigningPrivateKeyURL else {
            return DRCArtifactStore()
        }
        return DRCArtifactStore(
            signer: try DRCArtifactSignerLoader.loadEd25519(from: artifactSigningPrivateKeyURL)
        )
    }

    private struct ParsedArguments {
        var layoutURL: URL?
        var topCell: String?
        var layoutFormat: DRCLayoutFormat?
        var technologyURL: URL?
        var waiverURL: URL?
        var backendID: String?
        var outputDirectory: URL?
        var timeoutSeconds = 300.0
        var requireApprovedWaivers = false
        var requireSignedArtifacts = false
        var requireAntennaRules = false
        var trustedArtifactPublicKey: String?
        var artifactSigningPrivateKeyURL: URL?
        var emitJSON = false

        mutating func apply(_ argument: String, cursor: inout DRCCLIArgumentCursor) throws {
            switch argument {
            case "--layout":
                layoutURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--top-cell":
                topCell = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty top cell")
            case "--format":
                layoutFormat = try Self.parseFormat(try cursor.requireValue(for: argument), argument: argument)
            case "--out":
                outputDirectory = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--tech":
                technologyURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--waivers":
                waiverURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--backend":
                backendID = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty backend identifier")
            case "--timeout":
                timeoutSeconds = try Self.parseTimeout(try cursor.requireValue(for: argument), argument: argument)
            case "--require-approved-waivers":
                requireApprovedWaivers = true
            case "--require-signed-artifacts":
                requireSignedArtifacts = true
            case "--require-antenna-rules":
                requireAntennaRules = true
            case "--trusted-artifact-public-key":
                trustedArtifactPublicKey = try cursor.requireNonEmptyValue(
                    for: argument,
                    expected: "non-empty base64 public key"
                )
            case "--artifact-signing-private-key":
                artifactSigningPrivateKeyURL = URL(filePath: try cursor.requireNonEmptyValue(
                    for: argument,
                    expected: "non-empty path"
                ))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
        }

        func requireLayoutURL() throws -> URL {
            guard let layoutURL else { throw DRCCLIError.missingRequired("--layout") }
            return layoutURL
        }

        func requireTopCell() throws -> String {
            guard let topCell else { throw DRCCLIError.missingRequired("--top-cell") }
            return topCell
        }

        func requireOutputDirectory() throws -> URL {
            guard let outputDirectory else { throw DRCCLIError.missingRequired("--out") }
            return outputDirectory
        }

        private static func parseFormat(_ value: String, argument: String) throws -> DRCLayoutFormat {
            guard let format = DRCLayoutFormat(rawValue: value) else {
                throw DRCCLIError.invalidValue(
                    argument: argument,
                    value: value,
                    expected: "auto, gds, oasis, cif, dxf, native-json, or magic-layout"
                )
            }
            return format
        }

        private static func parseTimeout(_ rawValue: String, argument: String) throws -> Double {
            guard let value = Double(rawValue), value.isFinite, value > 0 else {
                throw DRCCLIError.invalidValue(argument: argument, value: rawValue, expected: "positive finite seconds")
            }
            return value
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
        var parsed = ParsedArguments()
        var cursor = DRCCLIArgumentCursor(arguments: arguments)
        while let argument = cursor.next() {
            try parsed.apply(argument, cursor: &cursor)
        }
        return parsed
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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
    public let runID: String?
    public let resumeReportURL: URL?
    public let requireSignedArtifacts: Bool
    public let trustedArtifactPublicKey: String?
    public let requireAntennaRules: Bool
    public let artifactSigningPrivateKeyURL: URL?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var specURL: URL?
        var outputDirectory: URL?
        var oracleBackendIDOverride: String?
        var runID: String?
        var resumeReportURL: URL?
        var requireSignedArtifacts = false
        var requireAntennaRules = false
        var trustedArtifactPublicKey: String?
        var artifactSigningPrivateKeyURL: URL?
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
            case "--run-id":
                runID = try Self.nonEmptyValue(after: argument, in: arguments, index: &index)
            case "--resume-report":
                resumeReportURL = URL(filePath: try Self.nonEmptyPath(after: argument, in: arguments, index: &index))
            case "--require-signed-artifacts":
                requireSignedArtifacts = true
            case "--require-antenna-rules":
                requireAntennaRules = true
            case "--trusted-artifact-public-key":
                trustedArtifactPublicKey = try Self.nonEmptyValue(after: argument, in: arguments, index: &index)
            case "--artifact-signing-private-key":
                artifactSigningPrivateKeyURL = URL(filePath: try Self.nonEmptyPath(after: argument, in: arguments, index: &index))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let specURL else { throw DRCCLIError.missingRequired("--corpus") }
        guard let outputDirectory else { throw DRCCLIError.missingRequired("--out") }
        if requireSignedArtifacts && artifactSigningPrivateKeyURL == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--artifact-signing-private-key must also be provided"
            )
        }
        if requireSignedArtifacts && trustedArtifactPublicKey == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--trusted-artifact-public-key must also be provided"
            )
        }
        self.specURL = specURL
        self.outputDirectory = outputDirectory
        self.oracleBackendIDOverride = oracleBackendIDOverride
        self.runID = runID
        self.resumeReportURL = resumeReportURL
        self.requireSignedArtifacts = requireSignedArtifacts
        self.trustedArtifactPublicKey = trustedArtifactPublicKey
        self.requireAntennaRules = requireAntennaRules
        self.artifactSigningPrivateKeyURL = artifactSigningPrivateKeyURL
        self.emitJSON = emitJSON
    }

    public var runOptions: DRCCorpusRunOptions {
        DRCCorpusRunOptions(
            oracleBackendIDOverride: oracleBackendIDOverride,
            runID: runID,
            resumeReportURL: resumeReportURL,
            requireSignedArtifacts: requireSignedArtifacts,
            trustedArtifactPublicKey: trustedArtifactPublicKey,
            requireAntennaRules: requireAntennaRules
        )
    }

    public func makeArtifactStore() throws -> DRCArtifactStore {
        guard let artifactSigningPrivateKeyURL else { return DRCArtifactStore() }
        return DRCArtifactStore(
            signer: try DRCArtifactSignerLoader.loadEd25519(from: artifactSigningPrivateKeyURL)
        )
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
    }

    private static func nonEmptyValue(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty backend ID")
        }
        return value
    }

    private static func nonEmptyPath(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: "non-empty path")
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
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
    }
}

public struct DRCReportSummaryCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--summarize-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else {
            throw DRCCLIError.missingRequired("--summarize-report")
        }
        self.reportURL = reportURL
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
    }
}

public struct DRCCorpusCoverageAuditCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let includedReportURLs: [URL]
    public let policyURL: URL?
    public let outputURL: URL?
    public let auditID: String?
    public let checkedAt: Date?
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var reportURL: URL?
        var includedReportURLs: [URL] = []
        var policyURL: URL?
        var outputURL: URL?
        var auditID: String?
        var checkedAt: Date?
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
        guard let reportURL else {
            throw DRCCLIError.missingRequired("--audit-corpus-coverage")
        }
        self.reportURL = reportURL
        self.includedReportURLs = includedReportURLs
        self.policyURL = policyURL
        self.outputURL = outputURL
        self.auditID = auditID
        self.checkedAt = checkedAt
        self.emitJSON = emitJSON
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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

public struct DRCCorpusEvidenceCLIOptions: Sendable, Hashable {
    public let reportURL: URL
    public let outputURL: URL?
    public let evidenceID: String?
    public let checkedAt: Date
    public let requireSignedArtifacts: Bool
    public let trustedArtifactPublicKey: String?
    public let artifactSigningPrivateKeyURL: URL?
    public let emitJSON: Bool

    public init(arguments: [String], now: Date = Date()) throws {
        var reportURL: URL?
        var outputURL: URL?
        var evidenceID: String?
        var checkedAt = now
        var requireSignedArtifacts = false
        var trustedArtifactPublicKey: String?
        var artifactSigningPrivateKeyURL: URL?
        var emitJSON = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--evidence-from-corpus-report":
                reportURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--out":
                outputURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--evidence-id":
                evidenceID = try Self.value(after: argument, in: arguments, index: &index)
            case "--checked-at":
                let value = try Self.value(after: argument, in: arguments, index: &index)
                checkedAt = try Self.iso8601Date(argument: argument, value: value)
            case "--require-signed-artifacts":
                requireSignedArtifacts = true
            case "--trusted-artifact-public-key":
                trustedArtifactPublicKey = try Self.value(after: argument, in: arguments, index: &index)
            case "--artifact-signing-private-key":
                artifactSigningPrivateKeyURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }
        guard let reportURL else { throw DRCCLIError.missingRequired("--evidence-from-corpus-report") }
        if requireSignedArtifacts && artifactSigningPrivateKeyURL == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--artifact-signing-private-key must also be provided"
            )
        }
        if requireSignedArtifacts && trustedArtifactPublicKey == nil {
            throw DRCCLIError.invalidValue(
                argument: "--require-signed-artifacts",
                value: "true",
                expected: "--trusted-artifact-public-key must also be provided"
            )
        }
        self.reportURL = reportURL
        self.outputURL = outputURL
        self.evidenceID = evidenceID
        self.checkedAt = checkedAt
        self.requireSignedArtifacts = requireSignedArtifacts
        self.trustedArtifactPublicKey = trustedArtifactPublicKey
        self.artifactSigningPrivateKeyURL = artifactSigningPrivateKeyURL
        self.emitJSON = emitJSON
    }

    public func makeSigner() throws -> (any DRCArtifactSigner)? {
        guard let artifactSigningPrivateKeyURL else { return nil }
        return try DRCArtifactSignerLoader.loadEd25519(from: artifactSigningPrivateKeyURL)
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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

    public let pdkRoot: String?
    public let profileURL: URL?
    public let profileResourceName: String?
    public let technologyOutputURL: URL
    public let reportOutputURL: URL?
    public let nativeAntennaOutputURL: URL?
    public let requireComplete: Bool
    public let allowPartial: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        let parsed = try Self.parseArguments(arguments)
        try parsed.validateImportFlag()
        try parsed.validateProfileSelection()
        self.pdkRoot = parsed.pdkRoot
        self.profileURL = parsed.profileURL
        self.profileResourceName = parsed.profileResourceName
        self.technologyOutputURL = try parsed.requireTechnologyOutputURL()
        self.reportOutputURL = parsed.reportOutputURL
        self.nativeAntennaOutputURL = parsed.nativeAntennaOutputURL
        self.requireComplete = parsed.requireComplete
        self.allowPartial = parsed.allowPartial
        self.emitJSON = parsed.emitJSON
    }

    public func environment(overriding base: [String: String]) -> [String: String] {
        var environment = base
        if let pdkRoot {
            environment["PDK_ROOT"] = pdkRoot
        }
        return environment
    }

    private struct ParsedArguments {
        var sawImport = false
        var pdkRoot: String?
        var profileURL: URL?
        var profileResourceName: String?
        var technologyOutputURL: URL?
        var reportOutputURL: URL?
        var nativeAntennaOutputURL: URL?
        var requireComplete = false
        var allowPartial = false
        var emitJSON = false

        mutating func apply(_ argument: String, cursor: inout DRCCLIArgumentCursor) throws {
            switch argument {
            case DRCFoundryRuleImportCLIOptions.importFlag:
                sawImport = true
            case "--pdk-root":
                pdkRoot = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path")
            case "--profile":
                profileURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--profile-resource":
                profileResourceName = try cursor.requireNonEmptyValue(
                    for: argument,
                    expected: "non-empty profile resource name"
                )
            case "--tech-out":
                technologyOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--report-out":
                reportOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--native-antenna-out":
                nativeAntennaOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--require-complete":
                requireComplete = true
            case "--allow-partial":
                allowPartial = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
        }

        func validateImportFlag() throws {
            guard sawImport else { throw DRCCLIError.missingRequired(DRCFoundryRuleImportCLIOptions.importFlag) }
        }

        func validateProfileSelection() throws {
            guard let profileURL, let profileResourceName else { return }
            throw DRCCLIError.invalidValue(
                argument: "--profile-resource",
                value: profileResourceName,
                expected: "only one of --profile or --profile-resource; received \(profileURL.path(percentEncoded: false))"
            )
        }

        func requireTechnologyOutputURL() throws -> URL {
            guard let technologyOutputURL else { throw DRCCLIError.missingRequired("--tech-out") }
            return technologyOutputURL
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
        var parsed = ParsedArguments()
        var cursor = DRCCLIArgumentCursor(arguments: arguments)
        while let argument = cursor.next() {
            try parsed.apply(argument, cursor: &cursor)
        }
        return parsed
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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

public struct DRCNativeAntennaQualificationCLIOptions: Sendable, Hashable {
    public static let qualificationFlag = "--qualify-native-antenna"

    public let artifactURL: URL
    public let oracleEvidenceURL: URL
    public let outputURL: URL
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        let parsed = try Self.parseArguments(arguments)
        guard parsed.sawQualification else {
            throw DRCCLIError.missingRequired(Self.qualificationFlag)
        }
        guard let artifactURL = parsed.artifactURL else {
            throw DRCCLIError.missingRequired("--native-antenna-artifact")
        }
        guard let oracleEvidenceURL = parsed.oracleEvidenceURL else {
            throw DRCCLIError.missingRequired("--oracle-evidence")
        }
        guard let outputURL = parsed.outputURL else {
            throw DRCCLIError.missingRequired("--out")
        }
        self.artifactURL = artifactURL
        self.oracleEvidenceURL = oracleEvidenceURL
        self.outputURL = outputURL
        self.emitJSON = parsed.emitJSON
    }

    private struct ParsedArguments {
        var sawQualification = false
        var artifactURL: URL?
        var oracleEvidenceURL: URL?
        var outputURL: URL?
        var emitJSON = false

        mutating func apply(_ argument: String, cursor: inout DRCCLIArgumentCursor) throws {
            switch argument {
            case DRCNativeAntennaQualificationCLIOptions.qualificationFlag:
                sawQualification = true
            case "--native-antenna-artifact":
                artifactURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--oracle-evidence":
                oracleEvidenceURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--out":
                outputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
        var parsed = ParsedArguments()
        var cursor = DRCCLIArgumentCursor(arguments: arguments)
        while let argument = cursor.next() {
            try parsed.apply(argument, cursor: &cursor)
        }
        return parsed
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
    public let nativeAntennaOutputURL: URL?
    public let requireComplete: Bool
    public let allowPartial: Bool
    public let emitJSON: Bool

    public init(arguments: [String]) throws {
        var parsed = try Self.parseArguments(arguments)
        try parsed.validateImportFlag()
        try parsed.validateProfileSelection()
        try parsed.resolveCatalogIfNeeded()
        self.magicTechURL = try parsed.requireMagicTechURL()
        self.profileURL = try parsed.resolvedProfileURL()
        self.profileResourceName = parsed.profileResourceName
        self.catalogURL = parsed.catalogURL
        self.technologyCatalogID = parsed.technologyCatalogID
        self.pdkID = parsed.pdkID
        self.profileID = parsed.profileID
        self.technologyOutputURL = try parsed.requireTechnologyOutputURL()
        self.reportOutputURL = parsed.reportOutputURL
        self.nativeAntennaOutputURL = parsed.nativeAntennaOutputURL
        self.requireComplete = parsed.requireComplete
        self.allowPartial = parsed.allowPartial
        self.emitJSON = parsed.emitJSON
    }

    private struct ParsedArguments {
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
        var nativeAntennaOutputURL: URL?
        var requireComplete = false
        var allowPartial = false
        var emitJSON = false

        mutating func apply(_ argument: String, cursor: inout DRCCLIArgumentCursor) throws {
            switch argument {
            case "--import-magic-rules":
                sawImport = true
            case "--magic-tech":
                magicTechURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--profile":
                profileURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--profile-resource":
                profileResourceName = try cursor.requireNonEmptyValue(
                    for: argument,
                    expected: "non-empty profile resource name"
                )
            case "--catalog":
                catalogURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--catalog-id":
                technologyCatalogID = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty catalog identifier")
            case "--pdk-id":
                pdkID = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty PDK identifier")
            case "--profile-id":
                profileID = try cursor.requireNonEmptyValue(for: argument, expected: "non-empty profile identifier")
            case "--pdk-root":
                pdkRootURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--tech-out":
                technologyOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--report-out":
                reportOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--native-antenna-out":
                nativeAntennaOutputURL = URL(filePath: try cursor.requireNonEmptyValue(for: argument, expected: "non-empty path"))
            case "--require-complete":
                requireComplete = true
            case "--allow-partial":
                allowPartial = true
            case "--json":
                emitJSON = true
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
        }

        func validateImportFlag() throws {
            guard sawImport else { throw DRCCLIError.missingRequired("--import-magic-rules") }
        }

        func validateProfileSelection() throws {
            guard let profileURL, let profileResourceName else { return }
            throw DRCCLIError.invalidValue(
                argument: "--profile-resource",
                value: profileResourceName,
                expected: "only one of --profile or --profile-resource; received \(profileURL.path(percentEncoded: false))"
            )
        }

        mutating func resolveCatalogIfNeeded() throws {
            guard let catalogURL else { return }
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

        func requireMagicTechURL() throws -> URL {
            guard let magicTechURL else { throw DRCCLIError.missingRequired("--magic-tech or --catalog") }
            return magicTechURL
        }

        func resolvedProfileURL() throws -> URL {
            if let profileURL {
                return profileURL
            }
            if let profileResourceName {
                return try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfileURL(
                    resourceName: profileResourceName
                )
            }
            throw DRCCLIError.missingRequired("--profile or --profile-resource")
        }

        func requireTechnologyOutputURL() throws -> URL {
            guard let technologyOutputURL else { throw DRCCLIError.missingRequired("--tech-out") }
            return technologyOutputURL
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
        var parsed = ParsedArguments()
        var cursor = DRCCLIArgumentCursor(arguments: arguments)
        while let argument = cursor.next() {
            try parsed.apply(argument, cursor: &cursor)
        }
        return parsed
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
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
        try DRCCLIArgumentCursor.value(after: argument, in: arguments, index: &index)
    }
}
