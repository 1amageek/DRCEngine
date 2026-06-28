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

    public init(
        timeoutSeconds: Double = 300,
        additionalEnvironment: [String: String] = [:]
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.additionalEnvironment = additionalEnvironment
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

    public init(
        layoutURL: URL,
        topCell: String,
        layoutFormat: DRCLayoutFormat? = nil,
        technologyURL: URL? = nil,
        waiverURL: URL? = nil,
        workingDirectory: URL? = nil,
        backendSelection: DRCBackendSelection = DRCBackendSelection(backendID: "magic"),
        options: DRCOptions = DRCOptions()
    ) {
        self.layoutURL = layoutURL
        self.topCell = topCell
        self.layoutFormat = layoutFormat
        self.technologyURL = technologyURL
        self.waiverURL = waiverURL
        self.workingDirectory = workingDirectory
        self.backendSelection = backendSelection
        self.options = options
    }
}

public struct DRCResult: Sendable, Hashable, Codable {
    public let backendID: String
    public let toolName: String
    public let success: Bool
    public let completed: Bool
    public let logPath: String
    public let diagnostics: [DRCDiagnostic]
    public let provenance: DRCToolProvenance?

    public init(
        backendID: String,
        toolName: String,
        success: Bool,
        completed: Bool,
        logPath: String,
        diagnostics: [DRCDiagnostic] = [],
        provenance: DRCToolProvenance? = nil
    ) {
        self.backendID = backendID
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

    public init(
        executablePath: String,
        pdkRoot: String,
        rcFilePath: String,
        driverScriptPath: String,
        timeoutSeconds: Double
    ) {
        self.executablePath = executablePath
        self.pdkRoot = pdkRoot
        self.rcFilePath = rcFilePath
        self.driverScriptPath = driverScriptPath
        self.timeoutSeconds = timeoutSeconds
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

    public init(
        request: DRCRequest,
        result: DRCResult,
        waiverReport: DRCWaiverApplicationReport? = nil,
        repairHintGeometry: DRCRepairHintGeometryContext? = nil,
        reportURL: URL? = nil,
        artifactManifestURL: URL? = nil
    ) {
        self.request = request
        self.result = result
        self.waiverReport = waiverReport
        self.repairHintGeometry = repairHintGeometry
        self.reportURL = reportURL
        self.artifactManifestURL = artifactManifestURL
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
    public let toolName: String
    public let passed: Bool
    public let completed: Bool
    public let inputs: [DRCArtifactRecord]
    public let outputs: [DRCArtifactRecord]
    public let diagnosticSummary: DRCDiagnosticSummary
    public let waiverReport: DRCWaiverApplicationReport?

    public init(
        schemaVersion: Int = 1,
        generatedAt: String,
        backendID: String,
        toolName: String,
        passed: Bool,
        completed: Bool,
        inputs: [DRCArtifactRecord],
        outputs: [DRCArtifactRecord],
        diagnosticSummary: DRCDiagnosticSummary,
        waiverReport: DRCWaiverApplicationReport? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.backendID = backendID
        self.toolName = toolName
        self.passed = passed
        self.completed = completed
        self.inputs = inputs
        self.outputs = outputs
        self.diagnosticSummary = diagnosticSummary
        self.waiverReport = waiverReport
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

    public init(
        id: String,
        reason: String,
        ruleID: String? = nil,
        kind: String? = nil,
        layer: String? = nil,
        relatedShapeIDs: [String] = [],
        messageContains: String? = nil
    ) {
        self.id = id
        self.reason = reason
        self.ruleID = ruleID
        self.kind = kind
        self.layer = layer
        self.relatedShapeIDs = relatedShapeIDs
        self.messageContains = messageContains
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

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult
}

public typealias DRCExecutionCancellationCheck = @Sendable () async -> Bool

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
        case .artifactWriteFailed(let message):
            return "DRC artifact write failed: \(message)"
        case .waiverApplicationFailed(let message):
            return "DRC waiver application failed: \(message)"
        case .cancelled(let message):
            return "DRC cancelled: \(message)"
        }
    }
}
