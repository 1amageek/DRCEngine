import Foundation

public extension DRCRequest {
    /// Validates the request contract before a backend is selected or launched.
    func validate() throws {
        guard !topCell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCError.invalidInput("DRC top cell must not be empty.")
        }
        guard !topCell.contains("\0"), !topCell.contains("\n"), !topCell.contains("\r") else {
            throw DRCError.invalidInput("DRC top cell contains a control character.")
        }
        guard !backendSelection.backendID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCError.invalidInput("DRC backend ID must not be empty.")
        }
        guard !backendSelection.backendID.contains("\0"),
              !backendSelection.backendID.contains("\n"),
              !backendSelection.backendID.contains("\r") else {
            throw DRCError.invalidInput("DRC backend ID contains a control character.")
        }
        guard options.timeoutSeconds.isFinite, options.timeoutSeconds > 0 else {
            throw DRCError.invalidInput("DRC timeoutSeconds must be finite and greater than zero.")
        }
        if let designRevision {
            guard !designRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !designRevision.contains("\0"),
                  !designRevision.contains("\n"),
                  !designRevision.contains("\r") else {
                throw DRCError.invalidInput("DRC designRevision must be a non-empty value without control characters.")
            }
        }
        if let canonicalStateDigest {
            guard Self.isSHA256(canonicalStateDigest) else {
                throw DRCError.invalidInput("DRC canonicalStateDigest must be a lowercase 64-character SHA-256 digest.")
            }
        }
        if let trustedArtifactPublicKey = options.trustedArtifactPublicKey {
            guard !trustedArtifactPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("DRC trustedArtifactPublicKey must not be empty when present.")
            }
            guard let publicKeyData = Data(base64Encoded: trustedArtifactPublicKey), publicKeyData.count == 32 else {
                throw DRCError.invalidInput(
                    "DRC trustedArtifactPublicKey must be a base64-encoded 32-byte Ed25519 public key."
                )
            }
        }
        if options.requireSignedArtifacts && options.trustedArtifactPublicKey == nil {
            throw DRCError.invalidInput(
                "DRC trustedArtifactPublicKey is required when requireSignedArtifacts is enabled."
            )
        }
        try Self.validateAdditionalEnvironment(options.additionalEnvironment)
    }

    static func validateAdditionalEnvironment(_ environment: [String: String]) throws {
        for (key, value) in environment {
            guard isValidEnvironmentKey(key) else {
                throw DRCError.invalidInput("DRC environment key '\(key)' is invalid.")
            }
            guard !value.contains("\0"), !value.contains("\n"), !value.contains("\r") else {
                throw DRCError.invalidInput("DRC environment value for '\(key)' contains a control character.")
            }
        }
    }

    private static func isValidEnvironmentKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let scalars = Array(key.unicodeScalars)
        guard let first = scalars.first,
              first == "_" || Self.isASCIILetter(first) else {
            return false
        }
        return scalars.dropFirst().allSatisfy { scalar in
            scalar == "_" || Self.isASCIILetter(scalar) || Self.isASCIIDigit(scalar)
        }
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 65 && scalar.value <= 90
            || scalar.value >= 97 && scalar.value <= 122
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64
            && value.unicodeScalars.allSatisfy { scalar in
                (scalar.value >= 48 && scalar.value <= 57)
                    || (scalar.value >= 97 && scalar.value <= 102)
            }
    }
}
