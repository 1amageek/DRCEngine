import Foundation

/// One process-layer contribution to a native antenna calculation.
public struct NativeDRCAntennaLayer: Sendable, Hashable, Codable {
    public enum Measurement: String, Sendable, Hashable, Codable {
        case surface
        case sidewall
    }

    public enum DiffusionCorrection: String, Sendable, Hashable, Codable {
        case none
        case finite
    }

    public let layer: String
    public let measurement: Measurement
    public let diffusionCorrection: DiffusionCorrection
    public let ratioGate: Double
    public let thickness: Double?
    public let diffusionRatioConstant: Double?
    public let diffusionRatioPerArea: Double?

    public init(
        layer: String,
        measurement: Measurement,
        ratioGate: Double,
        thickness: Double? = nil,
        diffusionCorrection: DiffusionCorrection = .finite,
        diffusionRatioConstant: Double? = nil,
        diffusionRatioPerArea: Double? = nil
    ) {
        self.layer = layer
        self.measurement = measurement
        self.diffusionCorrection = diffusionCorrection
        self.ratioGate = ratioGate
        self.thickness = thickness
        self.diffusionRatioConstant = diffusionRatioConstant
        self.diffusionRatioPerArea = diffusionRatioPerArea
    }

    private enum CodingKeys: String, CodingKey {
        case layer
        case measurement
        case diffusionCorrection
        case ratioGate
        case thickness
        case diffusionRatioConstant
        case diffusionRatioPerArea
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.layer = try container.decode(String.self, forKey: .layer)
        self.measurement = try container.decode(Measurement.self, forKey: .measurement)
        self.diffusionCorrection = try container.decodeIfPresent(
            DiffusionCorrection.self,
            forKey: .diffusionCorrection
        ) ?? .finite
        self.ratioGate = try container.decode(Double.self, forKey: .ratioGate)
        self.thickness = try container.decodeIfPresent(Double.self, forKey: .thickness)
        self.diffusionRatioConstant = try container.decodeIfPresent(Double.self, forKey: .diffusionRatioConstant)
        self.diffusionRatioPerArea = try container.decodeIfPresent(Double.self, forKey: .diffusionRatioPerArea)
    }
}
