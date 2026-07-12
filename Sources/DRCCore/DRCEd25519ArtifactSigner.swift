import Foundation
import CryptoKit

public struct DRCEd25519ArtifactSigner: DRCArtifactSigner, Sendable {
    private let privateKey: Curve25519.Signing.PrivateKey

    public let algorithm = "ed25519"

    public var publicKey: String {
        privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    public init(privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()) {
        self.privateKey = privateKey
    }

    public init(rawRepresentation: Data) throws {
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    public func sign(_ data: Data) throws -> DRCArtifactSignature {
        let signature = try privateKey.signature(for: data)
        return DRCArtifactSignature(
            algorithm: algorithm,
            publicKey: publicKey,
            signature: signature.base64EncodedString()
        )
    }
}
