import Foundation

public struct NativeDRCLayout: Sendable, Hashable, Codable {
    public let technologyID: String
    public let topCell: String
    public let unit: String
    public let rectangles: [NativeDRCRectangle]
    public let rules: [NativeDRCRule]

    public init(
        technologyID: String,
        topCell: String,
        unit: String = "micrometer",
        rectangles: [NativeDRCRectangle],
        rules: [NativeDRCRule]
    ) {
        self.technologyID = technologyID
        self.topCell = topCell
        self.unit = unit
        self.rectangles = rectangles
        self.rules = rules
    }
}
