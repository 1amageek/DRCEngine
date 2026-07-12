import Foundation

/// Completeness attestation for optional antenna annotations on a canonical
/// NativeDRC layout.
///
/// The evaluator treats absent annotations as zero/empty data for compatibility
/// with exploratory runs. A release run must carry this contract so missing
/// gate, diffusion, process, or cut metadata cannot be mistaken for a clean
/// antenna result.
public struct NativeDRCAntennaMetadata: Sendable, Hashable, Codable {
    public let gateAreasComplete: Bool
    public let diffusionAreasComplete: Bool
    public let processStepsComplete: Bool
    public let cutConnectivityComplete: Bool
    public let source: String?

    public init(
        gateAreasComplete: Bool,
        diffusionAreasComplete: Bool,
        processStepsComplete: Bool,
        cutConnectivityComplete: Bool,
        source: String? = nil
    ) {
        self.gateAreasComplete = gateAreasComplete
        self.diffusionAreasComplete = diffusionAreasComplete
        self.processStepsComplete = processStepsComplete
        self.cutConnectivityComplete = cutConnectivityComplete
        self.source = source
    }
}
