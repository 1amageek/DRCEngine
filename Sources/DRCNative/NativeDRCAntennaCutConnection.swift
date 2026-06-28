import Foundation

public struct NativeDRCAntennaCutConnection: Sendable, Hashable, Codable {
    public let layer: String
    public let lowerLayer: String
    public let upperLayer: String

    public init(
        layer: String,
        lowerLayer: String,
        upperLayer: String
    ) {
        self.layer = layer
        self.lowerLayer = lowerLayer
        self.upperLayer = upperLayer
    }
}
