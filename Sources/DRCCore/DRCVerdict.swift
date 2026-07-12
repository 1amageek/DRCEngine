public enum DRCVerdict: String, Sendable, Hashable, Codable {
    case passed
    case failed
    case unsupported
    case incomplete
    case executionFailed = "execution-failed"
}
