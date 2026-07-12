import Foundation
import DRCEngine

public extension DRCMagicRuleImportCatalog {
    func validationIssues() -> [DRCMagicRuleImportCatalogValidationIssue] {
        var issues: [DRCMagicRuleImportCatalogValidationIssue] = []
        if schemaVersion != 1 {
            issues.append(DRCMagicRuleImportCatalogValidationIssue(
                code: "unsupported-schema-version",
                message: "Magic rule import catalog schemaVersion must be 1.",
                field: "schemaVersion"
            ))
        }
        if entries.isEmpty {
            issues.append(DRCMagicRuleImportCatalogValidationIssue(
                code: "empty-catalog",
                message: "Magic rule import catalog must contain at least one entry.",
                field: "entries"
            ))
        }

        var entryKeys: Set<String> = []
        for (index, entry) in entries.enumerated() {
            let entryPath = "entries[\(index)]"
            if let issue = nonEmptyIdentifierIssue(
                entry.technologyCatalogID,
                code: "invalid-technology-catalog-id",
                field: "\(entryPath).technologyCatalogID"
            ) {
                issues.append(issue)
            }
            if let issue = nonEmptyIdentifierIssue(
                entry.pdkID,
                code: "invalid-pdk-id",
                field: "\(entryPath).pdkID"
            ) {
                issues.append(issue)
            }
            let entryKey = "\(entry.technologyCatalogID)\u{1F}\(entry.pdkID)"
            if !entry.technologyCatalogID.isEmpty,
               !entry.pdkID.isEmpty,
               !entryKeys.insert(entryKey).inserted {
                issues.append(DRCMagicRuleImportCatalogValidationIssue(
                    code: "duplicate-entry",
                    message: "Catalog entries must have unique technologyCatalogID and pdkID pairs.",
                    field: entryPath
                ))
            }

            let profileIDs = entry.profileIDs ?? []
            var profileIDSet: Set<String> = []
            for (profileIndex, profileID) in profileIDs.enumerated() {
                let field = "\(entryPath).profileIDs[\(profileIndex)]"
                if let issue = nonEmptyIdentifierIssue(
                    profileID,
                    code: "invalid-profile-id",
                    field: field
                ) {
                    issues.append(issue)
                }
                if !profileID.isEmpty, !profileIDSet.insert(profileID).inserted {
                    issues.append(DRCMagicRuleImportCatalogValidationIssue(
                        code: "duplicate-profile-id",
                        message: "Catalog profile IDs must be unique within an entry.",
                        field: field
                    ))
                }
            }

            var purposeSet: Set<String> = []
            for (fileIndex, requiredFile) in (entry.requiredFiles ?? []).enumerated() {
                let filePath = "\(entryPath).requiredFiles[\(fileIndex)]"
                if let issue = nonEmptyIdentifierIssue(
                    requiredFile.purpose,
                    code: "invalid-required-file-purpose",
                    field: "\(filePath).purpose"
                ) {
                    issues.append(issue)
                }
                if let issue = nonEmptyPathIssue(
                    requiredFile.path,
                    field: "\(filePath).path"
                ) {
                    issues.append(issue)
                }
                if !requiredFile.purpose.isEmpty,
                   !purposeSet.insert(requiredFile.purpose).inserted {
                    issues.append(DRCMagicRuleImportCatalogValidationIssue(
                        code: "duplicate-required-file-purpose",
                        message: "Catalog required-file purposes must be unique within an entry.",
                        field: "\(filePath).purpose"
                    ))
                }
            }

            for key in (entry.metadata ?? [:]).keys {
                if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || containsControlCharacter(key) {
                    issues.append(DRCMagicRuleImportCatalogValidationIssue(
                        code: "invalid-metadata-key",
                        message: "Catalog metadata keys must be non-empty and contain no control characters.",
                        field: "\(entryPath).metadata"
                    ))
                }
            }
            for (key, value) in entry.metadata ?? [:] where containsControlCharacter(value) {
                issues.append(DRCMagicRuleImportCatalogValidationIssue(
                    code: "invalid-metadata-value",
                    message: "Catalog metadata values must contain no control characters.",
                    field: "\(entryPath).metadata.\(key)"
                ))
            }
        }
        return issues
    }

    func validate() throws {
        let issues = validationIssues()
        guard issues.isEmpty else {
            let description = issues.map { issue in
                if let field = issue.field {
                    return "\(issue.code) (\(field))"
                }
                return issue.code
            }.joined(separator: ", ")
            throw DRCError.invalidInput("Invalid Magic rule import catalog: \(description)")
        }
    }

    private func nonEmptyIdentifierIssue(
        _ value: String,
        code: String,
        field: String
    ) -> DRCMagicRuleImportCatalogValidationIssue? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !containsControlCharacter(value) else {
            return DRCMagicRuleImportCatalogValidationIssue(
                code: code,
                message: "Catalog identifiers must be non-empty and contain no control characters.",
                field: field
            )
        }
        return nil
    }

    private func nonEmptyPathIssue(
        _ value: String,
        field: String
    ) -> DRCMagicRuleImportCatalogValidationIssue? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !containsControlCharacter(value) else {
            return DRCMagicRuleImportCatalogValidationIssue(
                code: "invalid-required-file-path",
                message: "Catalog required-file paths must be non-empty and contain no control characters.",
                field: field
            )
        }
        return nil
    }

    private func containsControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar.properties.generalCategory == .control
                || scalar.properties.generalCategory == .lineSeparator
                || scalar.properties.generalCategory == .paragraphSeparator
        }
    }
}
