import Foundation

public struct NativeDRCLayout: Sendable, Hashable, Codable {
    public let technologyID: String
    public let topCell: String
    public let unit: String
    public let rectangles: [NativeDRCRectangle]
    public let rules: [NativeDRCRule]
    public let antennaMetadata: NativeDRCAntennaMetadata?

    public init(
        technologyID: String,
        topCell: String,
        unit: String = "micrometer",
        rectangles: [NativeDRCRectangle],
        rules: [NativeDRCRule],
        antennaMetadata: NativeDRCAntennaMetadata? = nil
    ) {
        self.technologyID = technologyID
        self.topCell = topCell
        self.unit = unit
        self.rectangles = rectangles
        self.rules = rules
        self.antennaMetadata = antennaMetadata
    }
}
