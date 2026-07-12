import CryptoKit
import Foundation

/// Stable, message-independent marker identity used for cross-engine correlation.
public struct DRCCorpusMarkerFingerprint: Hashable, Sendable, Codable {
    public let digest: String

    public init(diagnostic: DRCDiagnostic) {
        let relatedShapeIDs = diagnostic.relatedShapeIDs.sorted().joined(separator: ",")
        let relatedViaIDs = diagnostic.relatedViaIDs.sorted().joined(separator: ",")
        let relatedPinIDs = diagnostic.relatedPinIDs.sorted().joined(separator: ",")
        let relatedNetIDs = diagnostic.relatedNetIDs.sorted().joined(separator: ",")
        let region = diagnostic.region.map { region in
            [region.x, region.y, region.width, region.height]
                .map(Self.format)
                .joined(separator: ",")
        } ?? ""
        let payload = [
            "drc-marker-v1",
            diagnostic.ruleID ?? "",
            diagnostic.kind ?? "",
            diagnostic.layer ?? "",
            region,
            relatedShapeIDs,
            relatedViaIDs,
            relatedPinIDs,
            relatedNetIDs
        ].joined(separator: "|")
        digest = SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public static func fingerprints(from diagnostics: [DRCDiagnostic]) -> [String] {
        diagnostics
            .map { Self(diagnostic: $0).digest }
            .sorted()
    }

    private static func format(_ value: Double) -> String {
        guard value.isFinite else { return "nonfinite" }
        let normalized = value == 0 ? 0 : value
        return String(
            format: "%.12f",
            locale: Locale(identifier: "en_US_POSIX"),
            normalized
        )
    }
}
