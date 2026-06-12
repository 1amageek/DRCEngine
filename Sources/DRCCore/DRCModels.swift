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

public struct DRCRequest: Sendable, Hashable, Codable {
    public let layoutURL: URL
    public let topCell: String
    public let workingDirectory: URL?
    public let backendSelection: DRCBackendSelection
    public let options: DRCOptions

    public init(
        layoutURL: URL,
        topCell: String,
        workingDirectory: URL? = nil,
        backendSelection: DRCBackendSelection = DRCBackendSelection(backendID: "magic"),
        options: DRCOptions = DRCOptions()
    ) {
        self.layoutURL = layoutURL
        self.topCell = topCell
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
        success && completed && !diagnostics.contains { $0.severity == .error }
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
    public let rawLine: String

    public init(
        severity: Severity,
        message: String,
        ruleID: String? = nil,
        count: Int? = nil,
        rawLine: String
    ) {
        self.severity = severity
        self.message = message
        self.ruleID = ruleID
        self.count = count
        self.rawLine = rawLine
    }
}

public struct DRCExecutionResult: Sendable, Hashable, Codable {
    public let request: DRCRequest
    public let result: DRCResult
    public let reportURL: URL?

    public init(request: DRCRequest, result: DRCResult, reportURL: URL? = nil) {
        self.request = request
        self.result = result
        self.reportURL = reportURL
    }
}

public protocol DRCBackend: Sendable {
    var backendID: String { get }

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult
}

public enum DRCError: Error, LocalizedError, Equatable {
    case invalidInput(String)
    case backendUnavailable(String)
    case backendFailed(String)
    case artifactWriteFailed(String)

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
        }
    }
}
