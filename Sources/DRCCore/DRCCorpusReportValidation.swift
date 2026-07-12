import Foundation

public extension DRCCorpusReport {
    /// Validates persisted corpus-report invariants before the report is used as evidence.
    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DRCError.invalidInput(
                "Unsupported DRC corpus report schema version: \(schemaVersion)."
            )
        }
        guard caseCount >= 0,
              matchedCaseCount >= 0,
              budgetExceededCaseCount >= 0,
              matchedCaseCount <= caseCount,
              budgetExceededCaseCount <= caseCount else {
            throw DRCError.invalidInput("DRC corpus report contains negative or out-of-range case counts.")
        }
        guard caseCount == caseResults.count else {
            throw DRCError.invalidInput(
                "DRC corpus report caseCount does not match the number of case results."
            )
        }
        let matchedResultCount = caseResults.filter(\.matched).count
        guard matchedCaseCount == matchedResultCount else {
            throw DRCError.invalidInput(
                "DRC corpus report matchedCaseCount does not match case results."
            )
        }
        let budgetExceededResultCount = caseResults.filter { !$0.durationBudgetPassed }.count
        guard budgetExceededCaseCount == budgetExceededResultCount else {
            throw DRCError.invalidInput(
                "DRC corpus report budgetExceededCaseCount does not match case results."
            )
        }
        guard passed == caseResults.allSatisfy(\.matched) else {
            throw DRCError.invalidInput(
                "DRC corpus report passed flag does not match case results."
            )
        }
        guard totalDurationSeconds.isFinite, totalDurationSeconds >= 0 else {
            throw DRCError.invalidInput("DRC corpus report totalDurationSeconds must be finite and non-negative.")
        }

        var caseIDs: Set<String> = []
        for caseResult in caseResults {
            guard !caseResult.caseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DRCError.invalidInput("DRC corpus report contains a case with an empty caseID.")
            }
            guard caseIDs.insert(caseResult.caseID).inserted else {
                throw DRCError.invalidInput(
                    "DRC corpus report contains duplicate caseID: \(caseResult.caseID)."
                )
            }
            guard caseResult.durationSeconds.isFinite, caseResult.durationSeconds >= 0 else {
                throw DRCError.invalidInput(
                    "DRC corpus case \(caseResult.caseID) has an invalid durationSeconds value."
                )
            }
            if let maximum = caseResult.expectedMaxDurationSeconds {
                guard maximum.isFinite, maximum > 0 else {
                    throw DRCError.invalidInput(
                        "DRC corpus case \(caseResult.caseID) has an invalid duration budget."
                    )
                }
                guard caseResult.durationBudgetPassed == (caseResult.durationSeconds <= maximum) else {
                    throw DRCError.invalidInput(
                        "DRC corpus case \(caseResult.caseID) has an inconsistent duration budget verdict."
                    )
                }
            }
        }

        guard summary.passRate.isFinite, summary.passRate >= 0, summary.passRate <= 1 else {
            throw DRCError.invalidInput("DRC corpus report summary passRate must be finite and between 0 and 1.")
        }
        if let oracleAgreementRate = summary.oracleAgreementRate {
            guard oracleAgreementRate.isFinite,
                  oracleAgreementRate >= 0,
                  oracleAgreementRate <= 1 else {
                throw DRCError.invalidInput(
                    "DRC corpus report summary oracleAgreementRate must be finite and between 0 and 1."
                )
            }
        }
    }
}
