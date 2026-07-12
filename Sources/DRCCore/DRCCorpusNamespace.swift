import Foundation

public enum DRCCorpusNamespace {
    public static func safePathComponent(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let mapped = value.map { allowed.contains($0) ? $0 : "_" }
        let result = String(mapped)
        return result.isEmpty ? "case" : result
    }
}
