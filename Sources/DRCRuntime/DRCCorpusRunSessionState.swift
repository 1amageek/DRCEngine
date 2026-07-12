public enum DRCCorpusRunSessionState: String, Sendable, Hashable, Codable {
    case idle
    case running
    case succeeded
    case failed
    case cancelled
}
