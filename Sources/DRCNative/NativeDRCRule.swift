import Foundation

public struct NativeDRCRule: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case manufacturingGrid
        case minimumWidth
        case minimumSpacing
        case forbiddenOverlap
        case exactOverlap
        case differentNetOverlap
        case minimumEndOfLineSpacing
        case minimumArea
        case maximumDensity
        case minimumDensity
        case minimumNotch
        case minimumEnclosedArea
        case minimumCut
        case maximumAntennaRatio
        case minimumEnclosure
        case minimumExtension
    }

    public enum SpacingNetScope: String, Sendable, Hashable, Codable {
        case all
        case sameNet
        case differentNet
    }

    public enum SpacingDirection: String, Sendable, Hashable, Codable {
        case either
        case horizontal
        case vertical
    }

    public enum ExtensionDirection: String, Sendable, Hashable, Codable {
        case horizontal
        case vertical
    }

    public let id: String
    public let kind: Kind
    public let layer: String
    public let value: Double
    public let enclosedLayer: String?
    public let windowWidth: Double?
    public let windowHeight: Double?
    public let stepX: Double?
    public let stepY: Double?
    public let windowOriginX: Double?
    public let windowOriginY: Double?
    public let gateLayer: String?
    public let conductorLayers: [String]?
    public let processStep: String?
    public let antennaCutConnections: [NativeDRCAntennaCutConnection]?
    public let spacingNetScope: SpacingNetScope?
    public let secondaryLayer: String?
    public let endOfLineWidth: Double?
    public let spacingDirection: SpacingDirection?
    public let minimumParallelRunLength: Double?
    public let wideWidthThreshold: Double?
    public let lowerLayer: String?
    public let upperLayer: String?
    public let extensionDirection: ExtensionDirection?

    public init(
        id: String,
        kind: Kind,
        layer: String,
        value: Double,
        enclosedLayer: String? = nil,
        windowWidth: Double? = nil,
        windowHeight: Double? = nil,
        stepX: Double? = nil,
        stepY: Double? = nil,
        windowOriginX: Double? = nil,
        windowOriginY: Double? = nil,
        gateLayer: String? = nil,
        conductorLayers: [String]? = nil,
        processStep: String? = nil,
        antennaCutConnections: [NativeDRCAntennaCutConnection]? = nil,
        spacingNetScope: SpacingNetScope? = nil,
        secondaryLayer: String? = nil,
        endOfLineWidth: Double? = nil,
        spacingDirection: SpacingDirection? = nil,
        minimumParallelRunLength: Double? = nil,
        wideWidthThreshold: Double? = nil,
        lowerLayer: String? = nil,
        upperLayer: String? = nil,
        extensionDirection: ExtensionDirection? = nil
    ) {
        self.id = id
        self.kind = kind
        self.layer = layer
        self.value = value
        self.enclosedLayer = enclosedLayer
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.stepX = stepX
        self.stepY = stepY
        self.windowOriginX = windowOriginX
        self.windowOriginY = windowOriginY
        self.gateLayer = gateLayer
        self.conductorLayers = conductorLayers
        self.processStep = processStep
        self.antennaCutConnections = antennaCutConnections
        self.spacingNetScope = spacingNetScope
        self.secondaryLayer = secondaryLayer
        self.endOfLineWidth = endOfLineWidth
        self.spacingDirection = spacingDirection
        self.minimumParallelRunLength = minimumParallelRunLength
        self.wideWidthThreshold = wideWidthThreshold
        self.lowerLayer = lowerLayer
        self.upperLayer = upperLayer
        self.extensionDirection = extensionDirection
    }
}
