import Foundation
import DRCCore
import DRCParsers
import SignoffToolSupport

public struct MagicDRCToolchain: Sendable, Hashable {
    public let magicExecutableURL: URL
    public let rcFileURL: URL
    public let pdkRoot: String
    public let driverScriptURL: URL

    public init(
        magicExecutableURL: URL,
        rcFileURL: URL,
        pdkRoot: String,
        driverScriptURL: URL
    ) {
        self.magicExecutableURL = magicExecutableURL
        self.rcFileURL = rcFileURL
        self.pdkRoot = pdkRoot
        self.driverScriptURL = driverScriptURL
    }
}

public struct MagicDRCAdapter: DRCCancellableBackend {
    public let toolchain: MagicDRCToolchain
    private let parser: MagicDRCReportParser

    public let backendID = "magic"
    private static let reservedEnvironmentKeys: Set<String> = [
        "PDK_ROOT",
        "DRC_CELL",
        "DRC_GDS",
        "DRC_MAG",
        "MAGTYPE",
    ]

    public init(
        toolchain: MagicDRCToolchain,
        parser: MagicDRCReportParser = MagicDRCReportParser()
    ) {
        self.toolchain = toolchain
        self.parser = parser
    }

    public static var bundledDriverScriptURL: URL? {
        Bundle.module.url(forResource: "drc", withExtension: "tcl")
    }

    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> MagicDRCAdapter? {
        guard let driver = bundledDriverScriptURL else { return nil }
        let magicPath = environment["MAGIC_BIN"]
            ?? NSString(string: "~/.local/magic/bin/magic").expandingTildeInPath
        guard fileManager.isExecutableFile(atPath: magicPath) else { return nil }
        let profile: SignoffPDKProfile
        do {
            profile = try SignoffPDKProfile.bundledDefaultProfile()
        } catch {
            return nil
        }
        guard let pdkRoot = SignoffPDKLocator.root(
            requirementID: "magic",
            profile: profile,
            environment: environment,
            fileManager: fileManager
        ) else {
            return nil
        }
        let rcFile: URL
        do {
            rcFile = try SignoffPDKLocator.requiredFileURL(
                in: pdkRoot,
                profile: profile,
                requirementID: "magic"
            )
        } catch {
            return nil
        }
        guard fileManager.fileExists(atPath: rcFile.path(percentEncoded: false)) else {
            return nil
        }
        return MagicDRCAdapter(toolchain: MagicDRCToolchain(
            magicExecutableURL: URL(filePath: magicPath),
            rcFileURL: rcFile,
            pdkRoot: pdkRoot,
            driverScriptURL: driver
        ))
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request, cancellationCheck: nil)
    }

    public func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult {
        let context = try prepareExecutionContext(for: request)
        let process = makeProcess(context: context)
        let processResult = try await runProcess(
            process,
            request: request,
            cancellationCheck: cancellationCheck
        )
        let rawOutput = Self.combinedOutput(from: processResult)
        try writeLog(
            to: context.logURL,
            request: request,
            exitCode: processResult.exitCode,
            rawOutput: rawOutput
        )
        let parsed = parser.parse(
            logPath: context.logURL.path(percentEncoded: false),
            rawOutput: rawOutput,
            success: processResult.exitCode == 0,
            provenance: makeProvenance(request: request)
        )
        return DRCExecutionResult(request: request, result: parsed)
    }

    private enum MagicInputKind {
        case gds
        case magicLayout
    }

    private struct ExecutionContext {
        let artifactDirectory: URL
        let logURL: URL
        let environment: [String: String]
    }

    private func prepareExecutionContext(for request: DRCRequest) throws -> ExecutionContext {
        try Self.validateAdditionalEnvironment(request.options.additionalEnvironment)
        try Self.validateMagicDRCStyle(request.options.additionalEnvironment["MAGIC_DRC_STYLE"])
        try Self.validateTopCell(request.topCell)
        let inputKind = try Self.resolveInputKind(for: request)
        let artifactDirectory = request.workingDirectory ?? FileManager.default.temporaryDirectory
        do {
            try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        } catch {
            throw DRCError.artifactWriteFailed(
                "Could not create Magic DRC artifact directory '\(artifactDirectory.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        return ExecutionContext(
            artifactDirectory: artifactDirectory,
            logURL: artifactDirectory.appending(path: "drc-magic-\(UUID().uuidString).log"),
            environment: processEnvironment(for: request, inputKind: inputKind)
        )
    }

    private func makeProcess(context: ExecutionContext) -> Process {
        let process = Process()
        process.executableURL = toolchain.magicExecutableURL
        process.arguments = [
            "-dnull",
            "-noconsole",
            "-rcfile",
            toolchain.rcFileURL.path(percentEncoded: false),
            toolchain.driverScriptURL.path(percentEncoded: false),
        ]
        process.currentDirectoryURL = context.artifactDirectory
        process.environment = context.environment
        return process
    }

    private func runProcess(
        _ process: Process,
        request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> TimedProcessResult {
        do {
            return try await TimedProcessRunner(
                timeoutSeconds: request.options.timeoutSeconds,
                terminationGraceSeconds: 0.1,
                pipeDrainGraceSeconds: 0.05
            ).run(
                process: process,
                cancellationCheck: cancellationCheck
            )
        } catch let error as TimedProcessError {
            switch error {
            case .cancelled(_, let standardOutput, let standardError):
                let output = [standardOutput, standardError]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw DRCError.cancelled(output.isEmpty ? "Magic DRC process was cancelled." : output)
            case .cancellationCheckFailed(_, let message, let standardOutput, let standardError):
                let output = [standardOutput, standardError, message]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw DRCError.backendFailed(output)
            default:
                throw error
            }
        }
    }

    private func writeLog(
        to logURL: URL,
        request: DRCRequest,
        exitCode: Int32,
        rawOutput: String
    ) throws {
        let log = renderLog(request: request, exitCode: exitCode, rawOutput: rawOutput)
        do {
            try log.write(to: logURL, atomically: true, encoding: .utf8)
        } catch {
            throw DRCError.artifactWriteFailed(error.localizedDescription)
        }
    }

    private func makeProvenance(request: DRCRequest) -> DRCToolProvenance {
        DRCToolProvenance(
            executablePath: toolchain.magicExecutableURL.path(percentEncoded: false),
            pdkRoot: toolchain.pdkRoot,
            rcFilePath: toolchain.rcFileURL.path(percentEncoded: false),
            driverScriptPath: toolchain.driverScriptURL.path(percentEncoded: false),
            timeoutSeconds: request.options.timeoutSeconds
        )
    }

    private static func combinedOutput(from result: TimedProcessResult) -> String {
        [result.standardOutput, result.standardError].joined(separator: "\n")
    }

    private func renderLog(request: DRCRequest, exitCode: Int32, rawOutput: String) -> String {
        """
        tool=magic
        kind=drc
        layout=\(request.layoutURL.path(percentEncoded: false))
        top_cell=\(request.topCell)
        exit_code=\(exitCode)

        [output]
        \(rawOutput)
        """
    }

    private static func validateAdditionalEnvironment(_ environment: [String: String]) throws {
        let reservedKeys = environment.keys
            .filter { reservedEnvironmentKeys.contains($0) }
            .sorted()
        guard reservedKeys.isEmpty else {
            throw DRCError.invalidInput("additionalEnvironment contains reserved keys: \(reservedKeys.joined(separator: ", "))")
        }
    }

    private static func validateMagicDRCStyle(_ style: String?) throws {
        guard let style, !style.isEmpty else { return }
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.()-")
        guard style.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw DRCError.invalidInput("MAGIC_DRC_STYLE contains unsupported characters")
        }
    }

    private static func validateTopCell(_ topCell: String) throws {
        guard !topCell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCError.invalidInput("topCell must not be empty")
        }
    }

    private static func resolveInputKind(for request: DRCRequest) throws -> MagicInputKind {
        switch request.layoutFormat ?? .auto {
        case .gds:
            return .gds
        case .magicLayout:
            return .magicLayout
        case .auto:
            return try inferAutoInputKind(from: request.layoutURL)
        case .oasis, .cif, .dxf, .nativeJSON:
            throw DRCError.invalidInput(
                "Magic DRC backend supports only GDSII or Magic layout inputs, got \(request.layoutFormat?.rawValue ?? DRCLayoutFormat.auto.rawValue)"
            )
        }
    }

    private static func inferAutoInputKind(from layoutURL: URL) throws -> MagicInputKind {
        switch layoutURL.pathExtension.lowercased() {
        case "gds":
            return .gds
        case "mag":
            return .magicLayout
        default:
            throw DRCError.invalidInput(
                "Magic DRC auto layout format requires a .gds or .mag extension: \(layoutURL.lastPathComponent)"
            )
        }
    }

    private func processEnvironment(for request: DRCRequest, inputKind: MagicInputKind) -> [String: String] {
        let requestEnvironment = [
            "PDK_ROOT": toolchain.pdkRoot,
            "DRC_CELL": request.topCell,
            "MAGTYPE": "mag",
        ].merging(Self.layoutEnvironment(for: request, inputKind: inputKind)) { _, new in new }
        return ProcessInfo.processInfo.environment
            .merging(request.options.additionalEnvironment) { _, new in new }
            .merging(requestEnvironment) { _, new in new }
    }

    private static func layoutEnvironment(for request: DRCRequest, inputKind: MagicInputKind) -> [String: String] {
        let layoutPath = request.layoutURL.path(percentEncoded: false)
        switch inputKind {
        case .magicLayout:
            return ["DRC_MAG": layoutPath]
        case .gds:
            return ["DRC_GDS": layoutPath]
        }
    }
}
