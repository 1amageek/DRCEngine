import Foundation

public struct DRCCorpusRunOptions: Sendable, Hashable, Codable {
    public let oracleBackendIDOverride: String?
    public let runID: String?
    public let resumeReportURL: URL?
    public let requireSignedArtifacts: Bool
    public let trustedArtifactPublicKey: String?
    public let requireAntennaRules: Bool

    public init(
        oracleBackendIDOverride: String? = nil,
        runID: String? = nil,
        resumeReportURL: URL? = nil,
        requireSignedArtifacts: Bool = false,
        trustedArtifactPublicKey: String? = nil,
        requireAntennaRules: Bool = false
    ) {
        self.oracleBackendIDOverride = oracleBackendIDOverride
        self.runID = runID
        self.resumeReportURL = resumeReportURL
        self.requireSignedArtifacts = requireSignedArtifacts
        self.trustedArtifactPublicKey = trustedArtifactPublicKey
        self.requireAntennaRules = requireAntennaRules
    }

    private enum CodingKeys: String, CodingKey {
        case oracleBackendIDOverride
        case runID
        case resumeReportURL
        case requireSignedArtifacts
        case trustedArtifactPublicKey
        case requireAntennaRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        oracleBackendIDOverride = try container.decodeIfPresent(String.self, forKey: .oracleBackendIDOverride)
        runID = try container.decodeIfPresent(String.self, forKey: .runID)
        resumeReportURL = try container.decodeIfPresent(URL.self, forKey: .resumeReportURL)
        requireSignedArtifacts = try container.decodeIfPresent(Bool.self, forKey: .requireSignedArtifacts) ?? false
        trustedArtifactPublicKey = try container.decodeIfPresent(String.self, forKey: .trustedArtifactPublicKey)
        requireAntennaRules = try container.decodeIfPresent(Bool.self, forKey: .requireAntennaRules) ?? false
    }

    public func validate() throws {
        if requireSignedArtifacts && trustedArtifactPublicKey == nil {
            throw DRCError.invalidInput(
                "DRC corpus trustedArtifactPublicKey is required when signed artifacts are enabled."
            )
        }
        if let trustedArtifactPublicKey {
            guard let data = Data(base64Encoded: trustedArtifactPublicKey), data.count == 32 else {
                throw DRCError.invalidInput(
                    "DRC corpus trustedArtifactPublicKey must be a base64-encoded 32-byte Ed25519 public key."
                )
            }
        }
    }
}
