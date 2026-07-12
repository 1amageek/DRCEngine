import Foundation

public struct DRCBackendSelection: Sendable, Hashable, Codable {
    public let backendID: String

    public init(backendID: String) {
        self.backendID = backendID
    }
}

public struct DRCOptions: Sendable, Hashable, Codable {
    public let timeoutSeconds: Double
    public let additionalEnvironment: [String: String]
    public let requireApprovedWaivers: Bool
    public let requireSignedArtifacts: Bool
    public let trustedArtifactPublicKey: String?
    /// Require a technology deck to contain explicit antenna rules before a
    /// standard-layout backend may report a clean run.
    public let requireAntennaRules: Bool

    public init(
        timeoutSeconds: Double = 300,
        additionalEnvironment: [String: String] = [:],
        requireApprovedWaivers: Bool = false,
        requireSignedArtifacts: Bool = false,
        trustedArtifactPublicKey: String? = nil,
        requireAntennaRules: Bool = false
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.additionalEnvironment = additionalEnvironment
        self.requireApprovedWaivers = requireApprovedWaivers
        self.requireSignedArtifacts = requireSignedArtifacts
        self.trustedArtifactPublicKey = trustedArtifactPublicKey
        self.requireAntennaRules = requireAntennaRules
    }

    private enum CodingKeys: String, CodingKey {
        case timeoutSeconds
        case additionalEnvironment
        case requireApprovedWaivers
        case requireSignedArtifacts
        case trustedArtifactPublicKey
        case requireAntennaRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 300
        self.additionalEnvironment = try container.decodeIfPresent([String: String].self, forKey: .additionalEnvironment) ?? [:]
        self.requireApprovedWaivers = try container.decodeIfPresent(Bool.self, forKey: .requireApprovedWaivers) ?? false
        self.requireSignedArtifacts = try container.decodeIfPresent(Bool.self, forKey: .requireSignedArtifacts) ?? false
        self.trustedArtifactPublicKey = try container.decodeIfPresent(String.self, forKey: .trustedArtifactPublicKey)
        self.requireAntennaRules = try container.decodeIfPresent(Bool.self, forKey: .requireAntennaRules) ?? false
    }
}

public enum DRCLayoutFormat: String, Sendable, Hashable, Codable {
    case auto
    case gds
    case oasis
    case cif
    case dxf
    case nativeJSON = "native-json"
    case magicLayout = "magic-layout"
}

public struct DRCRequest: Sendable, Hashable, Codable {
    public let layoutURL: URL
    public let topCell: String
    public let layoutFormat: DRCLayoutFormat?
    /// Technology rule deck (`LayoutTechDatabase` JSON) for backends
    /// that check standard layout formats; backends embedding rules in
    /// the layout input (custom JSON, Magic PDK) leave it nil.
    public let technologyURL: URL?
    public let waiverURL: URL?
    public let workingDirectory: URL?
    public let backendSelection: DRCBackendSelection
    public let options: DRCOptions
    public let designRevision: String?
    public let canonicalStateDigest: String?

    public init(
        layoutURL: URL,
        topCell: String,
        layoutFormat: DRCLayoutFormat? = nil,
        technologyURL: URL? = nil,
        waiverURL: URL? = nil,
        workingDirectory: URL? = nil,
        backendSelection: DRCBackendSelection = DRCBackendSelection(backendID: "magic"),
        options: DRCOptions = DRCOptions(),
        designRevision: String? = nil,
        canonicalStateDigest: String? = nil
    ) {
        self.layoutURL = layoutURL
        self.topCell = topCell
        self.layoutFormat = layoutFormat
        self.technologyURL = technologyURL
        self.waiverURL = waiverURL
        self.workingDirectory = workingDirectory
        self.backendSelection = backendSelection
        self.options = options
        self.designRevision = designRevision
        self.canonicalStateDigest = canonicalStateDigest
    }
}

public struct DRCResult: Sendable, Hashable, Codable {
    public let backendID: String
    public let backendIdentity: DRCBackendIdentity?
    public let toolName: String
    public let success: Bool
    public let completed: Bool
    public let logPath: String
    public let diagnostics: [DRCDiagnostic]
    public let provenance: DRCToolProvenance?

    public init(
        backendID: String,
        backendIdentity: DRCBackendIdentity? = nil,
        toolName: String,
        success: Bool,
        completed: Bool,
        logPath: String,
        diagnostics: [DRCDiagnostic] = [],
        provenance: DRCToolProvenance? = nil
    ) {
        self.backendID = backendID
        self.backendIdentity = backendIdentity
        self.toolName = toolName
        self.success = success
        self.completed = completed
        self.logPath = logPath
        self.diagnostics = diagnostics
        self.provenance = provenance
    }

    public var passed: Bool {
        success && completed && !diagnostics.contains { $0.severity == .error && !$0.isWaived }
    }
}

public struct DRCToolProvenance: Sendable, Hashable, Codable {
    public let executablePath: String
    public let pdkRoot: String
    public let rcFilePath: String
    public let driverScriptPath: String
    public let timeoutSeconds: Double
    public let executableDigest: String?
    public let ruleProgramDigest: String?
    public let technologyDigest: String?

    public init(
        executablePath: String,
        pdkRoot: String,
        rcFilePath: String,
        driverScriptPath: String,
        timeoutSeconds: Double,
        executableDigest: String? = nil,
        ruleProgramDigest: String? = nil,
        technologyDigest: String? = nil
    ) {
        self.executablePath = executablePath
        self.pdkRoot = pdkRoot
        self.rcFilePath = rcFilePath
        self.driverScriptPath = driverScriptPath
        self.timeoutSeconds = timeoutSeconds
        self.executableDigest = executableDigest
        self.ruleProgramDigest = ruleProgramDigest
        self.technologyDigest = technologyDigest
    }
}

public struct DRCDiagnostic: Sendable, Hashable, Codable {
    public enum Severity: String, Sendable, Hashable, Codable {
        case info
        case warning
        case error
    }

    public let severity: Severity
    public let message: String
    public let ruleID: String?
    public let count: Int?
    public let kind: String?
    public let layer: String?
    public let measured: Double?
    public let required: Double?
    public let unit: String?
    public let region: DRCRegion?
    public let relatedShapeIDs: [String]
    public let relatedViaIDs: [String]
    public let relatedPinIDs: [String]
    public let relatedNetIDs: [String]
    public let suggestedFix: String?
    public let waiverID: String?
    public let waiverReason: String?
    public let rawLine: String

    public init(
        severity: Severity,
        message: String,
        ruleID: String? = nil,
        count: Int? = nil,
        kind: String? = nil,
        layer: String? = nil,
        measured: Double? = nil,
        required: Double? = nil,
        unit: String? = nil,
        region: DRCRegion? = nil,
        relatedShapeIDs: [String] = [],
        relatedViaIDs: [String] = [],
        relatedPinIDs: [String] = [],
        relatedNetIDs: [String] = [],
        suggestedFix: String? = nil,
        waiverID: String? = nil,
        waiverReason: String? = nil,
        rawLine: String
    ) {
        self.severity = severity
        self.message = message
        self.ruleID = ruleID
        self.count = count
        self.kind = kind
        self.layer = layer
        self.measured = measured
        self.required = required
        self.unit = unit
        self.region = region
        self.relatedShapeIDs = relatedShapeIDs
        self.relatedViaIDs = relatedViaIDs
        self.relatedPinIDs = relatedPinIDs
        self.relatedNetIDs = relatedNetIDs
        self.suggestedFix = suggestedFix
        self.waiverID = waiverID
        self.waiverReason = waiverReason
        self.rawLine = rawLine
    }

    public var isWaived: Bool {
        waiverID != nil
    }

    public func applyingWaiver(_ waiver: DRCWaiver) -> DRCDiagnostic {
        DRCDiagnostic(
            severity: severity,
            message: message,
            ruleID: ruleID,
            count: count,
            kind: kind,
            layer: layer,
            measured: measured,
            required: required,
            unit: unit,
            region: region,
            relatedShapeIDs: relatedShapeIDs,
            relatedViaIDs: relatedViaIDs,
            relatedPinIDs: relatedPinIDs,
            relatedNetIDs: relatedNetIDs,
            suggestedFix: suggestedFix,
            waiverID: waiver.id,
            waiverReason: waiver.reason,
            rawLine: rawLine
        )
    }
}

public struct DRCRegion: Sendable, Hashable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DRCExecutionResult: Sendable, Hashable, Codable {
    public let request: DRCRequest
    public let result: DRCResult
    public let waiverReport: DRCWaiverApplicationReport?
    public let repairHintGeometry: DRCRepairHintGeometryContext?
    public let reportURL: URL?
    public let artifactManifestURL: URL?
    public let artifactRunID: String?

    public init(
        request: DRCRequest,
        result: DRCResult,
        waiverReport: DRCWaiverApplicationReport? = nil,
        repairHintGeometry: DRCRepairHintGeometryContext? = nil,
        reportURL: URL? = nil,
        artifactManifestURL: URL? = nil,
        artifactRunID: String? = nil
    ) {
        self.request = request
        self.result = result
        self.waiverReport = waiverReport
        self.repairHintGeometry = repairHintGeometry
        self.reportURL = reportURL
        self.artifactManifestURL = artifactManifestURL
        self.artifactRunID = artifactRunID
    }
}

public struct DRCRepairHintGeometryContext: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let source: String
    public let topCell: String
    public let unit: String?
    public let rectangles: [DRCRepairHintGeometryRectangle]

    public init(
        schemaVersion: Int = 1,
        source: String,
        topCell: String,
        unit: String? = nil,
        rectangles: [DRCRepairHintGeometryRectangle]
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.topCell = topCell
        self.unit = unit
        self.rectangles = rectangles
    }
}

public struct DRCRepairHintGeometryRectangle: Sendable, Hashable, Codable {
    public let id: String
    public let layer: String?
    public let netID: String?
    public let xMin: Double
    public let yMin: Double
    public let xMax: Double
    public let yMax: Double

    public init(
        id: String,
        layer: String? = nil,
        netID: String? = nil,
        xMin: Double,
        yMin: Double,
        xMax: Double,
        yMax: Double
    ) {
        self.id = id
        self.layer = layer
        self.netID = netID
        self.xMin = xMin
        self.yMin = yMin
        self.xMax = xMax
        self.yMax = yMax
    }
}

public struct DRCArtifactManifest: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let backendID: String
    public let backendIdentity: DRCBackendIdentity?
    public let toolName: String
    public let passed: Bool
    public let completed: Bool
    public let verdict: DRCVerdict?
    public let inputs: [DRCArtifactRecord]
    public let outputs: [DRCArtifactRecord]
    public let diagnosticSummary: DRCDiagnosticSummary
    public let waiverReport: DRCWaiverApplicationReport?
    public let runID: String?
    public let requestSHA256: String?
    public let requestEnvironmentSHA256: String?
    public let artifactRootSHA256: String?
    public let signature: DRCArtifactSignature?

    public init(
        schemaVersion: Int = 1,
        generatedAt: String,
        backendID: String,
        backendIdentity: DRCBackendIdentity? = nil,
        toolName: String,
        passed: Bool,
        completed: Bool,
        verdict: DRCVerdict? = nil,
        inputs: [DRCArtifactRecord],
        outputs: [DRCArtifactRecord],
        diagnosticSummary: DRCDiagnosticSummary,
        waiverReport: DRCWaiverApplicationReport? = nil,
        runID: String? = nil,
        requestSHA256: String? = nil,
        requestEnvironmentSHA256: String? = nil,
        artifactRootSHA256: String? = nil,
        signature: DRCArtifactSignature? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.backendID = backendID
        self.backendIdentity = backendIdentity
        self.toolName = toolName
        self.passed = passed
        self.completed = completed
        self.verdict = verdict
        self.inputs = inputs
        self.outputs = outputs
        self.diagnosticSummary = diagnosticSummary
        self.waiverReport = waiverReport
        self.runID = runID
        self.requestSHA256 = requestSHA256
        self.requestEnvironmentSHA256 = requestEnvironmentSHA256
        self.artifactRootSHA256 = artifactRootSHA256
        self.signature = signature
    }

    public func withSignature(_ signature: DRCArtifactSignature?) -> DRCArtifactManifest {
        DRCArtifactManifest(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            backendID: backendID,
            backendIdentity: backendIdentity,
            toolName: toolName,
            passed: passed,
            completed: completed,
            verdict: verdict,
            inputs: inputs,
            outputs: outputs,
            diagnosticSummary: diagnosticSummary,
            waiverReport: waiverReport,
            runID: runID,
            requestSHA256: requestSHA256,
            requestEnvironmentSHA256: requestEnvironmentSHA256,
            artifactRootSHA256: artifactRootSHA256,
            signature: signature
        )
    }
}

public struct DRCArtifactRecord: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case layout
        case technology
        case waiver
        case report
        case log
        case manifest
    }

    public let id: String
    public let kind: Kind
    public let path: String
    public let byteCount: Int?
    public let sha256: String?

    public init(
        id: String,
        kind: Kind,
        path: String,
        byteCount: Int?,
        sha256: String?
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct DRCDiagnosticSummary: Sendable, Hashable, Codable {
    public let infoCount: Int
    public let warningCount: Int
    public let errorCount: Int
    public let waivedErrorCount: Int

    public init(
        infoCount: Int,
        warningCount: Int,
        errorCount: Int,
        waivedErrorCount: Int = 0
    ) {
        self.infoCount = infoCount
        self.warningCount = warningCount
        self.errorCount = errorCount
        self.waivedErrorCount = waivedErrorCount
    }
}

public struct DRCWaiverFile: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let waivers: [DRCWaiver]

    public init(schemaVersion: Int = 1, waivers: [DRCWaiver]) {
        self.schemaVersion = schemaVersion
        self.waivers = waivers
    }
}

public struct DRCWaiver: Sendable, Hashable, Codable {
    public let id: String
    public let reason: String
    public let ruleID: String?
    public let kind: String?
    public let layer: String?
    public let relatedShapeIDs: [String]
    public let messageContains: String?
    public let approval: DRCWaiverApproval?

    public init(
        id: String,
        reason: String,
        ruleID: String? = nil,
        kind: String? = nil,
        layer: String? = nil,
        relatedShapeIDs: [String] = [],
        messageContains: String? = nil,
        approval: DRCWaiverApproval? = nil
    ) {
        self.id = id
        self.reason = reason
        self.ruleID = ruleID
        self.kind = kind
        self.layer = layer
        self.relatedShapeIDs = relatedShapeIDs
        self.messageContains = messageContains
        self.approval = approval
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reason
        case ruleID
        case kind
        case layer
        case relatedShapeIDs
        case messageContains
        case approval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        reason = try container.decode(String.self, forKey: .reason)
        ruleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        layer = try container.decodeIfPresent(String.self, forKey: .layer)
        relatedShapeIDs = try container.decodeIfPresent([String].self, forKey: .relatedShapeIDs) ?? []
        messageContains = try container.decodeIfPresent(String.self, forKey: .messageContains)
        approval = try container.decodeIfPresent(DRCWaiverApproval.self, forKey: .approval)
    }
}

public struct DRCWaiverApplicationReport: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let waivedDiagnosticCount: Int
    public let appliedWaivers: [DRCAppliedWaiver]
    public let unusedWaiverIDs: [String]

    public init(
        schemaVersion: Int = 1,
        waivedDiagnosticCount: Int,
        appliedWaivers: [DRCAppliedWaiver],
        unusedWaiverIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.waivedDiagnosticCount = waivedDiagnosticCount
        self.appliedWaivers = appliedWaivers
        self.unusedWaiverIDs = unusedWaiverIDs
    }
}

public struct DRCAppliedWaiver: Sendable, Hashable, Codable {
    public let waiverID: String
    public let ruleID: String?
    public let diagnosticMessage: String

    public init(waiverID: String, ruleID: String?, diagnosticMessage: String) {
        self.waiverID = waiverID
        self.ruleID = ruleID
        self.diagnosticMessage = diagnosticMessage
    }
}

public protocol DRCBackend: Sendable {
    var backendID: String { get }
    var identity: DRCBackendIdentity { get }

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult
}

public extension DRCBackend {
    var identity: DRCBackendIdentity {
        DRCBackendIdentity(backendID: backendID)
    }
}

public typealias DRCExecutionCancellationCheck = @Sendable () async throws -> Bool

public protocol DRCCancellableBackend: DRCBackend {
    func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult
}

public enum DRCError: Error, LocalizedError, Equatable {
    case invalidInput(String)
    case backendUnavailable(String)
    case backendFailed(String)
    case timedOut(String)
    case artifactWriteFailed(String)
    case waiverApplicationFailed(String)
    case cancelled(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid DRC input: \(message)"
        case .backendUnavailable(let message):
            return "DRC backend unavailable: \(message)"
        case .backendFailed(let message):
            return "DRC backend failed: \(message)"
        case .timedOut(let message):
            return "DRC timed out: \(message)"
        case .artifactWriteFailed(let message):
            return "DRC artifact write failed: \(message)"
        case .waiverApplicationFailed(let message):
            return "DRC waiver application failed: \(message)"
        case .cancelled(let message):
            return "DRC cancelled: \(message)"
        }
    }
}
