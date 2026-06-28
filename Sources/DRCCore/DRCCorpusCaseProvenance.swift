public struct DRCCorpusCaseProvenance: Sendable, Hashable, Codable {
    public let backendID: String
    public let inputArtifacts: [DRCArtifactRecord]
    public let outputArtifacts: [DRCArtifactRecord]
    public let reportPath: String?
    public let manifestPath: String?

    public init(
        backendID: String,
        inputArtifacts: [DRCArtifactRecord] = [],
        outputArtifacts: [DRCArtifactRecord] = [],
        reportPath: String?,
        manifestPath: String?
    ) {
        self.backendID = backendID
        self.inputArtifacts = inputArtifacts
        self.outputArtifacts = outputArtifacts
        self.reportPath = reportPath
        self.manifestPath = manifestPath
    }
}
