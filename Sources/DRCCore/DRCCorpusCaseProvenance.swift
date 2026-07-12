public struct DRCCorpusCaseProvenance: Sendable, Hashable, Codable {
    public let backendID: String
    public let backendIdentity: DRCBackendIdentity?
    public let inputArtifacts: [DRCArtifactRecord]
    public let outputArtifacts: [DRCArtifactRecord]
    public let reportPath: String?
    public let manifestPath: String?
    public let runID: String?
    public let requestSHA256: String?
    public let requestEnvironmentSHA256: String?
    public let artifactRootSHA256: String?

    public init(
        backendID: String,
        backendIdentity: DRCBackendIdentity? = nil,
        inputArtifacts: [DRCArtifactRecord] = [],
        outputArtifacts: [DRCArtifactRecord] = [],
        reportPath: String?,
        manifestPath: String?,
        runID: String? = nil,
        requestSHA256: String? = nil,
        requestEnvironmentSHA256: String? = nil,
        artifactRootSHA256: String? = nil
    ) {
        self.backendID = backendID
        self.backendIdentity = backendIdentity
        self.inputArtifacts = inputArtifacts
        self.outputArtifacts = outputArtifacts
        self.reportPath = reportPath
        self.manifestPath = manifestPath
        self.runID = runID
        self.requestSHA256 = requestSHA256
        self.requestEnvironmentSHA256 = requestEnvironmentSHA256
        self.artifactRootSHA256 = artifactRootSHA256
    }
}
