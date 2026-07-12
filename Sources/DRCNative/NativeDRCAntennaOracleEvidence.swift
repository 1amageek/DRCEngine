import Foundation

/// Reproducible evidence that an independently identified ARC oracle agreed
/// with a native antenna rule deck.
///
/// A boolean is not sufficient for signoff: the oracle executable, technology,
/// source/profile inputs, native rules, corpus, and comparison artifact must
/// all be bound to the verdict.
public struct NativeDRCAntennaOracleEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public enum ValidationError: Error, LocalizedError, Sendable, Hashable {
        case unsupportedSchemaVersion(Int)
        case emptyOracleID
        case nativeOracleNotIndependent
        case missingDigest(String)
        case invalidDigest(String)
        case invalidCaseCounts
        case nonPassingResult
        case missingGeneratedAt

        public var errorDescription: String? {
            switch self {
            case .unsupportedSchemaVersion(let version):
                return "Unsupported antenna oracle evidence schema version: \(version)."
            case .emptyOracleID:
                return "Antenna oracle evidence oracleID must not be empty."
            case .nativeOracleNotIndependent:
                return "NativeDRC cannot be used as the independent antenna oracle."
            case .missingDigest(let field):
                return "Antenna oracle evidence is missing digest: \(field)."
            case .invalidDigest(let field):
                return "Antenna oracle evidence has an invalid SHA-256 digest: \(field)."
            case .invalidCaseCounts:
                return "Antenna oracle evidence has invalid evaluated/agreed case counts."
            case .nonPassingResult:
                return "Antenna oracle evidence does not report complete agreement."
            case .missingGeneratedAt:
                return "Antenna oracle evidence generatedAt must not be empty."
            }
        }
    }

    public let schemaVersion: Int
    public let oracleID: String
    public let oracleVersion: String?
    public let executableDigest: String
    public let ruleDeckDigest: String
    public let technologyDigest: String
    public let sourceDigest: String
    public let profileDigest: String
    public let nativeRuleDigest: String
    public let layoutCorpusDigest: String
    public let comparisonArtifactDigest: String
    public let evaluatedCaseCount: Int
    public let agreedCaseCount: Int
    public let passed: Bool
    public let generatedAt: String

    public init(
        schemaVersion: Int = NativeDRCAntennaOracleEvidence.currentSchemaVersion,
        oracleID: String,
        oracleVersion: String? = nil,
        executableDigest: String,
        ruleDeckDigest: String,
        technologyDigest: String,
        sourceDigest: String,
        profileDigest: String,
        nativeRuleDigest: String,
        layoutCorpusDigest: String,
        comparisonArtifactDigest: String,
        evaluatedCaseCount: Int,
        agreedCaseCount: Int,
        passed: Bool,
        generatedAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.oracleID = oracleID
        self.oracleVersion = oracleVersion
        self.executableDigest = executableDigest
        self.ruleDeckDigest = ruleDeckDigest
        self.technologyDigest = technologyDigest
        self.sourceDigest = sourceDigest
        self.profileDigest = profileDigest
        self.nativeRuleDigest = nativeRuleDigest
        self.layoutCorpusDigest = layoutCorpusDigest
        self.comparisonArtifactDigest = comparisonArtifactDigest
        self.evaluatedCaseCount = evaluatedCaseCount
        self.agreedCaseCount = agreedCaseCount
        self.passed = passed
        self.generatedAt = generatedAt
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !oracleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyOracleID
        }
        let normalizedOracleID = oracleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedOracleID != "native",
              normalizedOracleID != "nativedrc",
              normalizedOracleID != "native-gds",
              normalizedOracleID != "layoutverify",
              normalizedOracleID != "layout-verify" else {
            throw ValidationError.nativeOracleNotIndependent
        }
        let digests: [(String, String)] = [
            ("executableDigest", executableDigest),
            ("ruleDeckDigest", ruleDeckDigest),
            ("technologyDigest", technologyDigest),
            ("sourceDigest", sourceDigest),
            ("profileDigest", profileDigest),
            ("nativeRuleDigest", nativeRuleDigest),
            ("layoutCorpusDigest", layoutCorpusDigest),
            ("comparisonArtifactDigest", comparisonArtifactDigest),
        ]
        guard !digests.contains(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            let field = digests.first(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.0 ?? "unknown"
            throw ValidationError.missingDigest(field)
        }
        let hexadecimal = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        for (field, digest) in digests {
            guard digest.count == 64,
                  digest.unicodeScalars.allSatisfy({ hexadecimal.contains($0) }) else {
                throw ValidationError.invalidDigest(field)
            }
        }
        guard evaluatedCaseCount > 0,
              agreedCaseCount >= 0,
              agreedCaseCount <= evaluatedCaseCount else {
            throw ValidationError.invalidCaseCounts
        }
        guard passed,
              agreedCaseCount == evaluatedCaseCount else {
            throw ValidationError.nonPassingResult
        }
        guard !generatedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingGeneratedAt
        }
    }

    /// Returns qualification failure codes without throwing, so a blocked
    /// artifact can explain precisely which evidence field is incomplete.
    public func failureCodes(
        expectedSourceDigest: String?,
        expectedProfileDigest: String?,
        expectedNativeRuleDigest: String?
    ) -> [String] {
        var failures: [String] = []
        do {
            try validate()
        } catch let error as ValidationError {
            failures.append(Self.failureCode(for: error))
        } catch {
            failures.append("oracle_evidence_invalid")
        }
        if sourceDigest != expectedSourceDigest {
            failures.append("oracle_source_digest_mismatch")
        }
        if profileDigest != expectedProfileDigest {
            failures.append("oracle_profile_digest_mismatch")
        }
        if nativeRuleDigest != expectedNativeRuleDigest {
            failures.append("oracle_native_rule_digest_mismatch")
        }
        return failures
    }

    private static func failureCode(for error: ValidationError) -> String {
        switch error {
        case .unsupportedSchemaVersion:
            return "oracle_evidence_schema_unsupported"
        case .emptyOracleID:
            return "oracle_id_missing"
        case .nativeOracleNotIndependent:
            return "oracle_not_independent"
        case .missingDigest(let field):
            return "oracle_digest_missing:\(field)"
        case .invalidDigest(let field):
            return "oracle_digest_invalid:\(field)"
        case .invalidCaseCounts:
            return "oracle_case_counts_invalid"
        case .nonPassingResult:
            return "oracle_result_not_passing"
        case .missingGeneratedAt:
            return "oracle_generated_at_missing"
        }
    }
}
