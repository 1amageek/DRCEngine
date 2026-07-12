import Foundation

public struct DRCBackendIdentity: Sendable, Hashable, Codable {
    public enum ImplementationFamily: String, Sendable, Hashable, Codable {
        case layoutVerify = "layout-verify"
        case magic
        case klayout
        case unknown
    }

    public let backendID: String
    public let implementationFamily: ImplementationFamily
    public let executableDigest: String?
    public let ruleProgramDigest: String?
    public let technologyDigest: String?

    public init(backendID: String) {
        self.init(
            backendID: backendID,
            implementationFamily: Self.inferredFamily(for: backendID)
        )
    }

    public init(
        backendID: String,
        implementationFamily: ImplementationFamily,
        executableDigest: String? = nil,
        ruleProgramDigest: String? = nil,
        technologyDigest: String? = nil
    ) {
        self.backendID = backendID
        self.implementationFamily = implementationFamily
        self.executableDigest = executableDigest
        self.ruleProgramDigest = ruleProgramDigest
        self.technologyDigest = technologyDigest
    }

    private static func inferredFamily(for backendID: String) -> ImplementationFamily {
        let normalizedID = backendID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedID {
        case "native", "native-gds", "layout-verify", "layoutverify":
            return .layoutVerify
        case "magic", "external.magic":
            return .magic
        case "klayout", "external.klayout":
            return .klayout
        default:
            return .unknown
        }
    }

    public func independenceFailureCode(comparedTo other: DRCBackendIdentity) -> String? {
        if normalizedBackendID == other.normalizedBackendID {
            return "same_backend_reference"
        }
        if implementationFamily == .unknown || other.implementationFamily == .unknown {
            return "reference_independence_unproven"
        }
        if implementationFamily == other.implementationFamily {
            return "same_implementation_family_reference"
        }
        if !isAttested || !other.isAttested {
            return "reference_attestation_unproven"
        }
        return nil
    }

    public func isIndependent(from other: DRCBackendIdentity) -> Bool {
        independenceFailureCode(comparedTo: other) == nil
    }

    public var isAttested: Bool {
        switch implementationFamily {
        case .layoutVerify:
            return true
        case .magic, .klayout:
            return executableDigest != nil
                && ruleProgramDigest != nil
                && technologyDigest != nil
        case .unknown:
            return false
        }
    }

    private var normalizedBackendID: String {
        backendID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
