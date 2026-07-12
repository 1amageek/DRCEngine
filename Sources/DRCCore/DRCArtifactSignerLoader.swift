import Foundation

public enum DRCArtifactSignerLoader {
    public static func loadEd25519(from url: URL) throws -> DRCEd25519ArtifactSigner {
        let keyData: Data
        do {
            keyData = try Data(contentsOf: url)
        } catch {
            throw DRCError.invalidInput(
                "Could not read artifact signing private key '\(url.path(percentEncoded: false))': \(error.localizedDescription)"
            )
        }
        let rawRepresentation: Data
        if keyData.count == 32 {
            rawRepresentation = keyData
        } else if let encoded = String(data: keyData, encoding: .utf8),
                  let decoded = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
                  decoded.count == 32 {
            rawRepresentation = decoded
        } else {
            throw DRCError.invalidInput(
                "Artifact signing private key must be a raw 32-byte Ed25519 key or base64-encoded 32-byte key."
            )
        }
        do {
            return try DRCEd25519ArtifactSigner(rawRepresentation: rawRepresentation)
        } catch {
            throw DRCError.invalidInput("Artifact signing private key is invalid: \(error.localizedDescription)")
        }
    }
}
