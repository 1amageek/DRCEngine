import Foundation

public protocol DRCArtifactSigner: Sendable {
    var algorithm: String { get }
    var publicKey: String { get }
    func sign(_ data: Data) throws -> DRCArtifactSignature
}
