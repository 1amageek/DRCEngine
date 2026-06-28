public struct DRCCorpusQualificationResult: Sendable, Hashable, Codable {
    public let qualified: Bool
    public let policy: DRCCorpusQualificationPolicy
    public let failures: [DRCCorpusQualificationFailure]

    public init(
        policy: DRCCorpusQualificationPolicy,
        failures: [DRCCorpusQualificationFailure]
    ) {
        self.policy = policy
        self.failures = failures
        self.qualified = failures.isEmpty
    }
}
