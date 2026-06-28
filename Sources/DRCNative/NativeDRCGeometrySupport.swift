import Foundation
import DRCCore

struct DensityRectangle: Sendable, Hashable {
    let xMin: Double
    let yMin: Double
    let xMax: Double
    let yMax: Double

    var area: Double {
        (xMax - xMin) * (yMax - yMin)
    }
}

struct NotchInterval: Sendable, Hashable {
    let lower: Double
    let upper: Double

    var length: Double {
        upper - lower
    }
}

struct NotchBridgeInterval: Sendable, Hashable {
    let interval: NotchInterval
    let shapeID: String
}

struct DRCGridCell: Sendable, Hashable {
    let x: Int
    let y: Int
}

enum EndOfLineDirection: Sendable, Hashable {
    case bottom
    case top
    case left
    case right
}

struct EndOfLineEdge: Sendable, Hashable {
    let rectangle: NativeDRCRectangle
    let name: String
    let direction: EndOfLineDirection
}

enum SpacingRelationDirection: Sendable, Hashable {
    case horizontal
    case vertical
}

struct SpacingRelation: Sendable, Hashable {
    let direction: SpacingRelationDirection
    let spacing: Double
    let parallelRunLength: Double
}

extension DRCRegion {
    func enclosing(_ other: DRCRegion) -> DRCRegion {
        let minX = min(x, other.x)
        let minY = min(y, other.y)
        let maxX = max(x + width, other.x + other.width)
        let maxY = max(y + height, other.y + other.height)
        return DRCRegion(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
