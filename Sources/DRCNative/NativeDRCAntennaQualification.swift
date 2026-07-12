import Foundation
import CryptoKit
import DRCFoundryImport

/// Qualification verdict for a lowered antenna rule deck.
///
/// A regression pass is not enough for signoff: the source declarations must
/// be materialized and an independently identified oracle must agree. This
/// value makes that distinction explicit for CLI, Agent, and CI consumers.
public struct NativeDRCAntennaQualification: Sendable, Hashable, Codable {
    public enum Status: String, Sendable, Hashable, Codable {
        case qualified
        case blocked
    }

    public let status: Status
    public let sourceImportStatus: MagicDRCLayoutTechImportStatus
    public let sourceDigest: String?
    public let profileDigest: String?
    public let nativeRuleDigest: String?
    public let sourceRuleCount: Int
    public let nativeRuleCount: Int
    public let oracleEvidence: NativeDRCAntennaOracleEvidence?
    public let independentOracleVerified: Bool
    public let failureCodes: [String]

    public var qualified: Bool {
        status == .qualified
    }

    public init(
        sourceReport: MagicDRCLayoutTechImportReport,
        nativeRules: [NativeDRCRule],
        oracleEvidence: NativeDRCAntennaOracleEvidence? = nil
    ) {
        self.init(
            sourceImportStatus: sourceReport.status,
            sourceDigest: sourceReport.sourceDigest,
            profileDigest: sourceReport.profileDigest,
            sourceAntennaRuleCount: sourceReport.sourceAntennaRules.count,
            sourceAntennaRuleIDs: sourceReport.sourceAntennaRules.map(\.id),
            sourceDiagnostics: sourceReport.diagnostics,
            nativeRules: nativeRules,
            oracleEvidence: oracleEvidence
        )
    }

    @available(*, deprecated, message: "Use oracleEvidence with reproducible provenance instead of a boolean.")
    public init(
        sourceReport: MagicDRCLayoutTechImportReport,
        nativeRules: [NativeDRCRule],
        independentOracleVerified: Bool
    ) {
        self.init(
            sourceReport: sourceReport,
            nativeRules: nativeRules,
            oracleEvidence: nil
        )
    }

    private init(
        sourceImportStatus: MagicDRCLayoutTechImportStatus,
        sourceDigest: String?,
        profileDigest: String?,
        sourceAntennaRuleCount: Int,
        sourceAntennaRuleIDs: [String],
        sourceDiagnostics: [MagicDRCImportDiagnostic],
        nativeRules: [NativeDRCRule],
        oracleEvidence: NativeDRCAntennaOracleEvidence?
    ) {
        self.sourceImportStatus = sourceImportStatus
        self.sourceDigest = sourceDigest
        self.profileDigest = profileDigest
        self.sourceRuleCount = sourceAntennaRuleCount
        self.nativeRuleCount = nativeRules.count
        self.oracleEvidence = oracleEvidence
        self.independentOracleVerified = oracleEvidence?.passed == true
        self.nativeRuleDigest = Self.nativeRuleDigest(nativeRules)

        var failures: [String] = []
        if sourceImportStatus == .blocked {
            failures.append("source_import_blocked")
        }
        if sourceDigest?.isEmpty != false {
            failures.append("source_digest_missing")
        }
        if profileDigest?.isEmpty != false {
            failures.append("profile_digest_missing")
        }
        if nativeRuleDigest?.isEmpty != false {
            failures.append("native_rule_digest_missing")
        }
        if sourceAntennaRuleCount == 0 {
            failures.append("source_antenna_rules_missing")
        }
        for diagnostic in sourceDiagnostics
            where diagnostic.code.hasPrefix("magic_drc_antenna_")
                && diagnostic.code != "magic_drc_antenna_rule_not_materialized" {
            failures.append("source_antenna_diagnostic:\(diagnostic.code)")
        }
        if nativeRules.isEmpty {
            failures.append("native_antenna_rules_missing")
        }

        for sourceRuleID in sourceAntennaRuleIDs
            where !nativeRules.contains(where: { $0.id.hasPrefix("antenna.\(sourceRuleID).") }) {
            failures.append("source_antenna_rule_unmaterialized:\(sourceRuleID)")
        }
        if let oracleEvidence {
            failures.append(contentsOf: oracleEvidence.failureCodes(
                expectedSourceDigest: sourceDigest,
                expectedProfileDigest: profileDigest,
                expectedNativeRuleDigest: nativeRuleDigest
            ))
            if !oracleEvidence.passed {
                failures.append("independent_oracle_unverified")
            }
        } else {
            failures.append("oracle_evidence_missing")
            failures.append("independent_oracle_unverified")
        }
        self.failureCodes = failures
        self.status = failures.isEmpty ? .qualified : .blocked
    }

    /// Rebinds the qualification to an independently produced oracle artifact.
    /// Existing source/lowering failures are preserved; only the oracle portion
    /// of the verdict is replaced.
    public func applying(
        oracleEvidence: NativeDRCAntennaOracleEvidence
    ) -> NativeDRCAntennaQualification {
        let preservedFailures = failureCodes.filter { code in
            !code.hasPrefix("oracle_") && code != "independent_oracle_unverified"
        }
        let oracleFailures = oracleEvidence.failureCodes(
            expectedSourceDigest: sourceDigest,
            expectedProfileDigest: profileDigest,
            expectedNativeRuleDigest: nativeRuleDigest
        ) + (oracleEvidence.passed ? [] : ["independent_oracle_unverified"])
        return NativeDRCAntennaQualification(
            sourceImportStatus: sourceImportStatus,
            sourceDigest: sourceDigest,
            profileDigest: profileDigest,
            sourceAntennaRuleCount: sourceRuleCount,
            nativeRuleCount: nativeRuleCount,
            nativeRuleDigest: nativeRuleDigest,
            oracleEvidence: oracleEvidence,
            failureCodes: preservedFailures + oracleFailures
        )
    }

    private init(
        sourceImportStatus: MagicDRCLayoutTechImportStatus,
        sourceDigest: String?,
        profileDigest: String?,
        sourceAntennaRuleCount: Int,
        sourceAntennaRuleIDs: [String],
        sourceDiagnostics: [MagicDRCImportDiagnostic],
        nativeRules: [NativeDRCRule],
        oracleEvidence: NativeDRCAntennaOracleEvidence?,
        failureCodes: [String]
    ) {
        self.sourceImportStatus = sourceImportStatus
        self.sourceDigest = sourceDigest
        self.profileDigest = profileDigest
        self.sourceRuleCount = sourceAntennaRuleCount
        self.nativeRuleCount = nativeRules.count
        self.nativeRuleDigest = Self.nativeRuleDigest(nativeRules)
        self.oracleEvidence = oracleEvidence
        self.independentOracleVerified = oracleEvidence?.passed == true
        self.failureCodes = failureCodes
        self.status = failureCodes.isEmpty ? .qualified : .blocked
    }

    private init(
        sourceImportStatus: MagicDRCLayoutTechImportStatus,
        sourceDigest: String?,
        profileDigest: String?,
        sourceAntennaRuleCount: Int,
        nativeRuleCount: Int,
        nativeRuleDigest: String?,
        oracleEvidence: NativeDRCAntennaOracleEvidence?,
        failureCodes: [String]
    ) {
        self.sourceImportStatus = sourceImportStatus
        self.sourceDigest = sourceDigest
        self.profileDigest = profileDigest
        self.sourceRuleCount = sourceAntennaRuleCount
        self.nativeRuleCount = nativeRuleCount
        self.nativeRuleDigest = nativeRuleDigest
        self.oracleEvidence = oracleEvidence
        self.independentOracleVerified = oracleEvidence?.passed == true
        self.failureCodes = failureCodes
        self.status = failureCodes.isEmpty ? .qualified : .blocked
    }

    public static func nativeRuleDigest(_ rules: [NativeDRCRule]) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(rules)
            return SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
        } catch {
            return nil
        }
    }
}
