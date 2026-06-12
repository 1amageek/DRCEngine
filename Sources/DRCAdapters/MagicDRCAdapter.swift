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

public struct MagicDRCAdapter: DRCBackend {
    public let toolchain: MagicDRCToolchain
    private let parser: MagicDRCReportParser

    public let backendID = "magic"
    private static let reservedEnvironmentKeys: Set<String> = [
        "PDK_ROOT",
        "DRC_CELL",
        "DRC_GDS",
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
        guard let pdkRoot = Sky130PDKLocator.root(
            requirement: .magic,
            environment: environment,
            fileManager: fileManager
        ) else {
            return nil
        }
        let rcFile = Sky130PDKLocator.requiredFileURL(in: pdkRoot, requirement: .magic)
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
        try Self.validateAdditionalEnvironment(request.options.additionalEnvironment)
        let artifactDirectory = request.workingDirectory ?? FileManager.default.temporaryDirectory
        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        let logURL = artifactDirectory.appending(path: "drc-magic-\(UUID().uuidString).log")

        let process = Process()
        process.executableURL = toolchain.magicExecutableURL
        process.arguments = [
            "-dnull",
            "-noconsole",
            "-rcfile",
            toolchain.rcFileURL.path(percentEncoded: false),
            toolchain.driverScriptURL.path(percentEncoded: false),
        ]
        process.currentDirectoryURL = artifactDirectory
        let requestEnvironment = [
            "PDK_ROOT": toolchain.pdkRoot,
            "DRC_CELL": request.topCell,
            "DRC_GDS": request.layoutURL.path(percentEncoded: false),
            "MAGTYPE": "mag",
        ]
        process.environment = ProcessInfo.processInfo.environment
            .merging(request.options.additionalEnvironment) { _, new in new }
            .merging(requestEnvironment) { _, new in new }

        let processResult = try await TimedProcessRunner(timeoutSeconds: request.options.timeoutSeconds).run(process: process)
        let rawOutput = [processResult.standardOutput, processResult.standardError].joined(separator: "\n")
        let log = renderLog(request: request, exitCode: processResult.exitCode, rawOutput: rawOutput)
        do {
            try log.write(to: logURL, atomically: true, encoding: .utf8)
        } catch {
            throw DRCError.artifactWriteFailed(error.localizedDescription)
        }

        let parsed = parser.parse(
            logPath: logURL.path(percentEncoded: false),
            rawOutput: rawOutput,
            success: processResult.exitCode == 0,
            provenance: DRCToolProvenance(
                executablePath: toolchain.magicExecutableURL.path(percentEncoded: false),
                pdkRoot: toolchain.pdkRoot,
                rcFilePath: toolchain.rcFileURL.path(percentEncoded: false),
                driverScriptPath: toolchain.driverScriptURL.path(percentEncoded: false),
                timeoutSeconds: request.options.timeoutSeconds
            )
        )
        return DRCExecutionResult(request: request, result: parsed)
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
}
