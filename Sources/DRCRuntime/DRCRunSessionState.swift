public enum DRCRunSessionState: String, Sendable, Codable {
    case idle
    case running
    case succeeded
    case failed
    case cancelled
}
