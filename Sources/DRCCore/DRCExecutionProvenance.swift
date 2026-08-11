import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation

public enum DRCExecutionProvenance {
    public static let nativeImplementationVersion = "1.0.0"
    private static let processExecutableDigest: String? = {
        let executableURL = Bundle.main.executableURL
            ?? URL(filePath: CommandLine.arguments[0])
        do {
            return try SHA256ContentDigester().digest(
                fileAt: executableURL,
                using: .sha256
            ).hexadecimalValue
        } catch {
            return nil
        }
    }()

    public static func make(
        request: DRCRequest,
        result: DRCResult,
        implementationID: String? = nil,
        implementationVersion: String? = nil,
        implementationBuild: String? = nil,
        captureInputFiles: Bool = true,
        inputArtifacts: [ArtifactReference]? = nil,
        invocation: ExecutionInvocation,
        startedAt: Date,
        completedAt: Date
    ) throws -> ExecutionProvenance {
        let build: String
        if let implementationBuild {
            build = implementationBuild
        } else {
            build = try currentExecutableDigest()
        }
        let producer = try ProducerIdentity(
            kind: .engine,
            identifier: implementationID ?? self.implementationID(for: result.backendID),
            version: implementationVersion ?? self.implementationVersion(for: result.backendID),
            build: build
        )
        let inputs: [ArtifactReference]
        if let inputArtifacts {
            inputs = inputArtifacts
        } else if captureInputFiles {
            inputs = try captureInputArtifacts(for: request)
        } else {
            inputs = request.executionInputArtifacts
        }
        if captureInputFiles,
           request.executionInputArtifacts.isEmpty,
           !verifyCapturedInputs(inputs, for: request) {
            throw DRCError.backendFailed(
                "A DRC input artifact changed during execution."
            )
        }
        return try ExecutionProvenance(
            producer: producer,
            inputs: inputs,
            invocation: invocation,
            environment: try environmentFingerprint(
                request: request,
                toolchain: "\(producer.identifier)-\(producer.version)"
            ),
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    public static func implementationID(for backendID: String) -> String {
        implementationID(for: DRCBackendIdentity(backendID: backendID))
    }

    public static func implementationID(for identity: DRCBackendIdentity) -> String {
        switch identity.implementationFamily {
        case .layoutVerify:
            "layout-verify"
        case .magic:
            "magic"
        case .klayout:
            "klayout"
        case .unknown:
            identity.backendID
        }
    }

    public static func implementationVersion(for backendID: String) -> String {
        nativeImplementationVersion
    }

    public static func currentExecutableDigest() throws -> String {
        guard let processExecutableDigest else {
            throw DRCError.backendUnavailable(
                "The executable carrying the native DRC implementation could not be attested."
            )
        }
        return processExecutableDigest
    }

    public static func captureInputArtifacts(for request: DRCRequest) throws -> [ArtifactReference] {
        guard request.executionInputArtifacts.isEmpty else {
            return request.executionInputArtifacts
        }
        return try inputLocators(for: request).map {
            try LocalArtifactReferencer().reference($0, relativeTo: nil)
        }
    }

    private static func inputLocators(for request: DRCRequest) throws -> [ArtifactLocator] {
        var locators = [try locator(
            url: request.layoutURL,
            kind: .layout,
            format: try layoutFormat(request.layoutFormat)
        )]
        if let technologyURL = request.technologyURL {
            locators.append(try locator(
                url: technologyURL,
                kind: .technology,
                format: .json
            ))
        }
        if let waiverURL = request.waiverURL {
            locators.append(try locator(
                url: waiverURL,
                kind: .constraint,
                format: .json
            ))
        }
        return locators
    }

    private static func locator(
        url: URL,
        kind: ArtifactKind,
        format: ArtifactFormat
    ) throws -> ArtifactLocator {
        let resolvedURL = url.resolvingSymlinksInPath()
        return ArtifactLocator(
            location: try ArtifactLocation(fileURL: resolvedURL),
            role: .input,
            kind: kind,
            format: format
        )
    }

    private static func verifyCapturedInputs(
        _ references: [ArtifactReference],
        for request: DRCRequest
    ) -> Bool {
        let locators: [ArtifactLocator]
        do {
            locators = try inputLocators(for: request)
        } catch {
            return false
        }
        guard references.count == locators.count else { return false }
        let verifier = LocalArtifactVerifier()
        var remaining = references
        for locator in locators {
            guard let index = remaining.firstIndex(where: { $0.descriptor == locator.descriptor }) else {
                return false
            }
            let reference = remaining.remove(at: index)
            guard verifier.verify(reference, at: locator, relativeTo: nil).isVerified else {
                return false
            }
        }
        return remaining.isEmpty
    }

    private static func layoutFormat(_ format: DRCLayoutFormat?) throws -> ArtifactFormat {
        switch format {
        case .gds: .gdsii
        case .oasis: .oasis
        case .nativeJSON: .json
        case .cif: try ArtifactFormat(rawValue: "cif")
        case .dxf: try ArtifactFormat(rawValue: "dxf")
        case .magicLayout: try ArtifactFormat(rawValue: "magic-layout")
        case .auto, nil: .unknown
        }
    }

    private static func environmentFingerprint(
        request: DRCRequest,
        toolchain: String
    ) throws -> ExecutionEnvironmentFingerprint {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let environmentDigest = try SHA256ContentDigester().digest(
            data: encoder.encode(request.options.additionalEnvironment),
            using: .sha256
        )
        return try ExecutionEnvironmentFingerprint(
            platform: platform,
            architecture: architecture,
            toolchain: toolchain,
            environmentDigest: environmentDigest
        )
    }

    private static var platform: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        #if os(macOS)
        let name = "macOS"
        #elseif os(Linux)
        let name = "Linux"
        #elseif os(Windows)
        let name = "Windows"
        #else
        let name = "unknown-platform"
        #endif
        return "\(name)-\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #elseif arch(arm)
        "arm"
        #elseif arch(i386)
        "i386"
        #else
        "unknown-architecture"
        #endif
    }
}
