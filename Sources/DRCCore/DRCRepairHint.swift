public struct DRCRepairHint: Codable, Sendable, Hashable {
    public let hintID: String
    public let sourceDiagnosticIndex: Int
    public let operationID: String
    public let confidence: String
    public let ruleID: String?
    public let kind: String?
    public let layer: String?
    public let targetShapeIDs: [String]
    public let relatedViaIDs: [String]
    public let relatedNetIDs: [String]
    public let region: DRCRegion?
    public let measured: Double?
    public let required: Double?
    public let numericParameters: [String: Double]
    public let stringParameters: [String: String]
    public let verificationGates: [String]
    public let rationale: String

    public init(
        hintID: String,
        sourceDiagnosticIndex: Int,
        operationID: String,
        confidence: String,
        ruleID: String?,
        kind: String?,
        layer: String?,
        targetShapeIDs: [String],
        relatedViaIDs: [String] = [],
        relatedNetIDs: [String],
        region: DRCRegion?,
        measured: Double?,
        required: Double?,
        numericParameters: [String: Double],
        stringParameters: [String: String],
        verificationGates: [String],
        rationale: String
    ) {
        self.hintID = hintID
        self.sourceDiagnosticIndex = sourceDiagnosticIndex
        self.operationID = operationID
        self.confidence = confidence
        self.ruleID = ruleID
        self.kind = kind
        self.layer = layer
        self.targetShapeIDs = targetShapeIDs
        self.relatedViaIDs = relatedViaIDs
        self.relatedNetIDs = relatedNetIDs
        self.region = region
        self.measured = measured
        self.required = required
        self.numericParameters = numericParameters
        self.stringParameters = stringParameters
        self.verificationGates = verificationGates
        self.rationale = rationale
    }

    private enum CodingKeys: String, CodingKey {
        case hintID
        case sourceDiagnosticIndex
        case operationID
        case confidence
        case ruleID
        case kind
        case layer
        case targetShapeIDs
        case relatedViaIDs
        case relatedNetIDs
        case region
        case measured
        case required
        case numericParameters
        case stringParameters
        case verificationGates
        case rationale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hintID = try container.decode(String.self, forKey: .hintID)
        self.sourceDiagnosticIndex = try container.decode(Int.self, forKey: .sourceDiagnosticIndex)
        self.operationID = try container.decode(String.self, forKey: .operationID)
        self.confidence = try container.decode(String.self, forKey: .confidence)
        self.ruleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.layer = try container.decodeIfPresent(String.self, forKey: .layer)
        self.targetShapeIDs = try container.decode([String].self, forKey: .targetShapeIDs)
        self.relatedViaIDs = try container.decodeIfPresent([String].self, forKey: .relatedViaIDs) ?? []
        self.relatedNetIDs = try container.decode([String].self, forKey: .relatedNetIDs)
        self.region = try container.decodeIfPresent(DRCRegion.self, forKey: .region)
        self.measured = try container.decodeIfPresent(Double.self, forKey: .measured)
        self.required = try container.decodeIfPresent(Double.self, forKey: .required)
        self.numericParameters = try container.decode([String: Double].self, forKey: .numericParameters)
        self.stringParameters = try container.decode([String: String].self, forKey: .stringParameters)
        self.verificationGates = try container.decode([String].self, forKey: .verificationGates)
        self.rationale = try container.decode(String.self, forKey: .rationale)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hintID, forKey: .hintID)
        try container.encode(sourceDiagnosticIndex, forKey: .sourceDiagnosticIndex)
        try container.encode(operationID, forKey: .operationID)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(ruleID, forKey: .ruleID)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(layer, forKey: .layer)
        try container.encode(targetShapeIDs, forKey: .targetShapeIDs)
        try container.encode(relatedViaIDs, forKey: .relatedViaIDs)
        try container.encode(relatedNetIDs, forKey: .relatedNetIDs)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encodeIfPresent(measured, forKey: .measured)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encode(numericParameters, forKey: .numericParameters)
        try container.encode(stringParameters, forKey: .stringParameters)
        try container.encode(verificationGates, forKey: .verificationGates)
        try container.encode(rationale, forKey: .rationale)
    }
}
