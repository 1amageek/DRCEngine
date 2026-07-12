import Foundation
import CryptoKit

public enum DRCArtifactSignatureVerifier {
    public static func verify(
        _ signature: DRCArtifactSignature,
        data: Data,
        trustedPublicKey: String? = nil
    ) -> Bool {
        guard signature.algorithm == "ed25519",
              trustedPublicKey == nil || trustedPublicKey == signature.publicKey,
              let publicKeyData = Data(base64Encoded: signature.publicKey),
              let signatureData = Data(base64Encoded: signature.signature) else {
            return false
        }
        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            return publicKey.isValidSignature(signatureData, for: data)
        } catch {
            return false
        }
    }
}
