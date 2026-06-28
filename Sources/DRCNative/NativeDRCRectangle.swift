import Foundation
import DRCCore

public struct NativeDRCRectangle: Sendable, Hashable, Codable {
    public let id: String
    public let layer: String
    public let xMin: Double
    public let yMin: Double
    public let xMax: Double
    public let yMax: Double
    public let netID: String?
    public let antennaGateArea: Double?
    public let antennaProcessStep: String?

    public init(
        id: String,
        layer: String,
        xMin: Double,
        yMin: Double,
        xMax: Double,
        yMax: Double,
        netID: String? = nil,
        antennaGateArea: Double? = nil,
        antennaProcessStep: String? = nil
    ) {
        self.id = id
        self.layer = layer
        self.xMin = xMin
        self.yMin = yMin
        self.xMax = xMax
        self.yMax = yMax
        self.netID = netID
        self.antennaGateArea = antennaGateArea
        self.antennaProcessStep = antennaProcessStep
    }

    public var width: Double {
        xMax - xMin
    }

    public var height: Double {
        yMax - yMin
    }

    public var area: Double {
        width * height
    }

    public func overlaps(_ other: NativeDRCRectangle) -> Bool {
        xMin < other.xMax && xMax > other.xMin && yMin < other.yMax && yMax > other.yMin
    }

    public func touches(_ other: NativeDRCRectangle) -> Bool {
        xMin <= other.xMax && xMax >= other.xMin && yMin <= other.yMax && yMax >= other.yMin
    }

    func covers(_ rectangle: DensityRectangle) -> Bool {
        xMin <= rectangle.xMin
            && xMax >= rectangle.xMax
            && yMin <= rectangle.yMin
            && yMax >= rectangle.yMax
    }

    func touches(_ region: DRCRegion) -> Bool {
        xMin <= region.x + region.width
            && xMax >= region.x
            && yMin <= region.y + region.height
            && yMax >= region.y
    }

    public func spacing(to other: NativeDRCRectangle) -> Double {
        let xGap = max(0, max(other.xMin - xMax, xMin - other.xMax))
        let yGap = max(0, max(other.yMin - yMax, yMin - other.yMax))
        if xGap == 0 {
            return yGap
        }
        if yGap == 0 {
            return xGap
        }
        return (xGap * xGap + yGap * yGap).squareRoot()
    }

    public func enclosureMargin(around other: NativeDRCRectangle) -> Double {
        min(
            other.xMin - xMin,
            other.yMin - yMin,
            xMax - other.xMax,
            yMax - other.yMax
        )
    }

    public func intersectionArea(with region: DRCRegion) -> Double {
        guard let clipped = clippedDensityRectangle(to: region) else {
            return 0
        }
        return clipped.area
    }

    public func intersectionRegion(with other: NativeDRCRectangle) -> DRCRegion? {
        let intersectionXMin = max(self.xMin, other.xMin)
        let intersectionYMin = max(self.yMin, other.yMin)
        let intersectionXMax = min(self.xMax, other.xMax)
        let intersectionYMax = min(self.yMax, other.yMax)
        guard intersectionXMax > intersectionXMin, intersectionYMax > intersectionYMin else {
            return nil
        }
        return DRCRegion(
            x: intersectionXMin,
            y: intersectionYMin,
            width: intersectionXMax - intersectionXMin,
            height: intersectionYMax - intersectionYMin
        )
    }

    func clippedDensityRectangle(to region: DRCRegion) -> DensityRectangle? {
        let clippedXMin = max(xMin, region.x)
        let clippedYMin = max(yMin, region.y)
        let clippedXMax = min(xMax, region.x + region.width)
        let clippedYMax = min(yMax, region.y + region.height)
        guard clippedXMax > clippedXMin, clippedYMax > clippedYMin else {
            return nil
        }
        return DensityRectangle(
            xMin: clippedXMin,
            yMin: clippedYMin,
            xMax: clippedXMax,
            yMax: clippedYMax
        )
    }

    var region: DRCRegion {
        DRCRegion(x: xMin, y: yMin, width: width, height: height)
    }

    var densityRectangle: DensityRectangle {
        DensityRectangle(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax)
    }
}
