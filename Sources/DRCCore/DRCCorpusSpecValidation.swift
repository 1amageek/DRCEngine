import Foundation

public extension DRCCorpusSpec {
    static let currentSchemaVersion = 1

    /// Validates the complete corpus contract before any case is prepared or run.
    func validate() throws {
        try validateDuration(defaultMaxDurationSeconds, field: "defaultMaxDurationSeconds")
        try acceptanceCriteria.validate()

        var caseIDs: Set<String> = []
        var namespaceIDs: [String: String] = [:]
        for corpusCase in cases {
            let casePrefix = "case '\(corpusCase.caseID)'"
            let normalizedCaseID = corpusCase.caseID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedCaseID.isEmpty else {
                throw DRCError.invalidInput("DRC corpus caseID must not be empty.")
            }
            guard caseIDs.insert(normalizedCaseID).inserted else {
                throw DRCError.invalidInput("Duplicate DRC corpus caseID: \(normalizedCaseID).")
            }
            let namespaceID = DRCCorpusNamespace.safePathComponent(normalizedCaseID)
            if let existingCaseID = namespaceIDs[namespaceID], existingCaseID != normalizedCaseID {
                throw DRCError.invalidInput(
                    "DRC corpus caseID '\(normalizedCaseID)' collides with '\(existingCaseID)' in the artifact namespace."
                )
            }
            namespaceIDs[namespaceID] = normalizedCaseID
            guard !corpusCase.layoutPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("\(casePrefix) layoutPath must not be empty.")
            }
            guard !corpusCase.topCell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("\(casePrefix) topCell must not be empty.")
            }
            try validateDuration(corpusCase.maxDurationSeconds, field: "\(casePrefix).maxDurationSeconds")
            try DRCRequest.validateAdditionalEnvironment(corpusCase.additionalEnvironment)
            try validateOptionalIdentifier(corpusCase.backendID, field: "\(casePrefix).backendID")
            try validateOptionalIdentifier(corpusCase.oracleBackendID, field: "\(casePrefix).oracleBackendID")
            try validateOptionalIdentifier(corpusCase.designRevision, field: "\(casePrefix).designRevision")
            if let canonicalStateDigest = corpusCase.canonicalStateDigest,
               !isSHA256(canonicalStateDigest) {
                throw DRCError.invalidInput(
                    "\(casePrefix).canonicalStateDigest must be a lowercase 64-character SHA-256 digest."
                )
            }
            guard corpusCase.expectedActiveErrorRuleIDs.allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else {
                throw DRCError.invalidInput(
                    "\(casePrefix) expectedActiveErrorRuleIDs must not contain empty values."
                )
            }
            if let expectedOracleActiveErrorRuleIDs = corpusCase.expectedOracleActiveErrorRuleIDs {
                guard corpusCase.oracleBackendID != nil else {
                    throw DRCError.invalidInput(
                        "\(casePrefix) expectedOracleActiveErrorRuleIDs requires oracleBackendID."
                    )
                }
                guard expectedOracleActiveErrorRuleIDs.allSatisfy({
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }) else {
                    throw DRCError.invalidInput(
                        "\(casePrefix) expectedOracleActiveErrorRuleIDs must not contain empty values."
                    )
                }
            }
        }
    }

    private func validateDuration(_ value: Double?, field: String) throws {
        guard let value else { return }
        guard value.isFinite, value > 0 else {
            throw DRCError.invalidInput("\(field) must be positive finite seconds.")
        }
    }

    private func validateOptionalIdentifier(_ value: String?, field: String) throws {
        guard let value else { return }
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.contains("\0"),
              !value.contains("\n"),
              !value.contains("\r") else {
            throw DRCError.invalidInput("\(field) must not be empty when present.")
        }
    }

    private func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57)
                || (scalar.value >= 97 && scalar.value <= 102)
        }
    }
}
