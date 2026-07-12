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

    private enum CodingKeys: String, CodingKey {
        case qualified
        case policy
        case failures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        policy = try container.decode(DRCCorpusQualificationPolicy.self, forKey: .policy)
        failures = try container.decode([DRCCorpusQualificationFailure].self, forKey: .failures)
        // `qualified` is a derived value. Never trust a persisted copy of it.
        qualified = failures.isEmpty
    }
}
