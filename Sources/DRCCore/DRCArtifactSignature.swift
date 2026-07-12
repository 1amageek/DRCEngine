import Foundation

public struct DRCArtifactSignature: Sendable, Hashable, Codable {
    public let algorithm: String
    public let publicKey: String
    public let signature: String

    public init(algorithm: String, publicKey: String, signature: String) {
        self.algorithm = algorithm
        self.publicKey = publicKey
        self.signature = signature
    }
}
