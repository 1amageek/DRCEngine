import Foundation

public extension DRCCorpusReport {
    /// Validates a persisted report as evidence, including all derived fields.
    ///
    /// `validate()` intentionally keeps the structural contract used by
    /// coverage-audit tooling. This stricter entry point is used before a
    /// persisted report can drive a corpus assessment or evidence decision.
    func validateEvidence() throws {
        try validate()

        let derivedSummary = DRCCorpusSummary(caseResults: caseResults)
        guard summary == derivedSummary else {
            throw DRCError.invalidInput(
                "DRC corpus report summary does not match its case results."
            )
        }

        let derivedAssessment = assessment.criteria.evaluate(
            passed: passed,
            caseCount: caseCount,
            summary: derivedSummary,
            completed: completed
        )
        guard assessment.criteria == derivedAssessment.criteria,
              derivedAssessment.findings.allSatisfy(assessment.findings.contains) else {
            throw DRCError.invalidInput(
                "DRC corpus report assessment omits findings derived from its case results and criteria."
            )
        }
    }
}
