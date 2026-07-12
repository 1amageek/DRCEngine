import Foundation

public extension DRCResult {
    /// Distinguishes a design violation from a backend that could not prove a verdict.
    var verdict: DRCVerdict {
        if diagnostics.contains(where: Self.isUnsupportedDiagnostic) {
            return .unsupported
        }
        if !success {
            return .executionFailed
        }
        if !completed {
            return .incomplete
        }
        if diagnostics.contains(where: { $0.severity == .error && !$0.isWaived }) {
            return .failed
        }
        return .passed
    }

    private static func isUnsupportedDiagnostic(_ diagnostic: DRCDiagnostic) -> Bool {
        guard diagnostic.severity == .error else { return false }
        if diagnostic.ruleID?.hasPrefix("drc.unsupported") == true {
            return true
        }
        if diagnostic.kind == "unsupported-geometry" || diagnostic.kind == "unsupported-rule" {
            return true
        }
        return false
    }
}
