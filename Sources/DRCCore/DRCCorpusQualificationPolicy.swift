public struct DRCCorpusQualificationPolicy: Sendable, Hashable, Codable {
    public static let strict = DRCCorpusQualificationPolicy()

    public let requireCorpusPassed: Bool
    public let minimumPassRate: Double
    public let minimumDurationBudgetPassRate: Double
    public let minimumOracleCaseCount: Int?
    public let minimumOracleAgreementRate: Double?
    public let requireIndependentOracle: Bool
    public let allowPrimaryExecutionFailures: Bool
    public let allowOracleExecutionFailures: Bool
    public let requiredCoverageTags: [String]

    private enum CodingKeys: String, CodingKey {
        case requireCorpusPassed
        case minimumPassRate
        case minimumDurationBudgetPassRate
        case minimumOracleCaseCount
        case minimumOracleAgreementRate
        case requireIndependentOracle
        case allowPrimaryExecutionFailures
        case allowOracleExecutionFailures
        case requiredCoverageTags
    }

    public init(
        requireCorpusPassed: Bool = true,
        minimumPassRate: Double = 1,
        minimumDurationBudgetPassRate: Double = 1,
        minimumOracleCaseCount: Int? = nil,
        minimumOracleAgreementRate: Double? = nil,
        requireIndependentOracle: Bool = false,
        allowPrimaryExecutionFailures: Bool = false,
        allowOracleExecutionFailures: Bool = false,
        requiredCoverageTags: [String] = []
    ) {
        self.requireCorpusPassed = requireCorpusPassed
        self.minimumPassRate = minimumPassRate
        self.minimumDurationBudgetPassRate = minimumDurationBudgetPassRate
        self.minimumOracleCaseCount = minimumOracleCaseCount
        self.minimumOracleAgreementRate = minimumOracleAgreementRate
        self.requireIndependentOracle = requireIndependentOracle
        self.allowPrimaryExecutionFailures = allowPrimaryExecutionFailures
        self.allowOracleExecutionFailures = allowOracleExecutionFailures
        self.requiredCoverageTags = Self.normalizedCoverageTags(requiredCoverageTags)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requireCorpusPassed = try container.decodeIfPresent(Bool.self, forKey: .requireCorpusPassed) ?? true
        minimumPassRate = try container.decodeIfPresent(Double.self, forKey: .minimumPassRate) ?? 1
        minimumDurationBudgetPassRate = try container.decodeIfPresent(
            Double.self,
            forKey: .minimumDurationBudgetPassRate
        ) ?? 1
        minimumOracleCaseCount = try container.decodeIfPresent(Int.self, forKey: .minimumOracleCaseCount)
        minimumOracleAgreementRate = try container.decodeIfPresent(Double.self, forKey: .minimumOracleAgreementRate)
        requireIndependentOracle = try container.decodeIfPresent(
            Bool.self,
            forKey: .requireIndependentOracle
        ) ?? false
        allowPrimaryExecutionFailures = try container.decodeIfPresent(
            Bool.self,
            forKey: .allowPrimaryExecutionFailures
        ) ?? false
        allowOracleExecutionFailures = try container.decodeIfPresent(
            Bool.self,
            forKey: .allowOracleExecutionFailures
        ) ?? false
        requiredCoverageTags = Self.normalizedCoverageTags(try container.decodeIfPresent(
            [String].self,
            forKey: .requiredCoverageTags
        ) ?? [])
    }

    public func evaluate(
        passed: Bool,
        caseCount: Int,
        summary: DRCCorpusSummary,
        completed: Bool = true
    ) -> DRCCorpusQualificationResult {
        var failures = validationFailures()
        if !completed {
            failures.append(DRCCorpusQualificationFailure(
                code: "corpus_incomplete",
                message: "The corpus run did not complete all scheduled cases."
            ))
        }
        if caseCount == 0 {
            failures.append(DRCCorpusQualificationFailure(
                code: "empty_corpus",
                message: "The corpus did not run any cases.",
                observedCount: 0,
                requiredCount: 1
            ))
        }
        if requireCorpusPassed && !passed {
            failures.append(DRCCorpusQualificationFailure(
                code: "corpus_not_passed",
                message: "The corpus did not pass every case, duration budget, and oracle agreement gate."
            ))
        }
        if summary.passRate < minimumPassRate {
            failures.append(DRCCorpusQualificationFailure(
                code: "pass_rate_below_minimum",
                message: "The corpus pass rate is below the required threshold.",
                observedDouble: summary.passRate,
                requiredDouble: minimumPassRate
            ))
        }
        let durationBudgetPassRate = caseCount == 0
            ? 0
            : Double(summary.durationBudgetPassedCaseCount) / Double(caseCount)
        if durationBudgetPassRate < minimumDurationBudgetPassRate {
            failures.append(DRCCorpusQualificationFailure(
                code: "duration_budget_pass_rate_below_minimum",
                message: "The corpus duration-budget pass rate is below the required threshold.",
                observedDouble: durationBudgetPassRate,
                requiredDouble: minimumDurationBudgetPassRate
            ))
        }
        if let minimumOracleCaseCount,
           summary.oracleCaseCount < minimumOracleCaseCount {
            failures.append(DRCCorpusQualificationFailure(
                code: "oracle_case_count_below_minimum",
                message: "The corpus did not run enough oracle comparison cases.",
                observedCount: summary.oracleCaseCount,
                requiredCount: minimumOracleCaseCount
            ))
        }
        if let minimumOracleAgreementRate {
            if let oracleAgreementRate = summary.oracleAgreementRate {
                if oracleAgreementRate < minimumOracleAgreementRate {
                    failures.append(DRCCorpusQualificationFailure(
                        code: "oracle_agreement_rate_below_minimum",
                        message: "The corpus oracle agreement rate is below the required threshold.",
                        observedDouble: oracleAgreementRate,
                        requiredDouble: minimumOracleAgreementRate
                    ))
                }
            } else {
                failures.append(DRCCorpusQualificationFailure(
                    code: "oracle_agreement_rate_missing",
                    message: "The corpus qualification policy requires oracle agreement, but no oracle cases ran.",
                    observedCount: summary.oracleCaseCount
                ))
            }
        }
        if requireIndependentOracle && summary.nonIndependentOracleCaseCount > 0 {
            failures.append(DRCCorpusQualificationFailure(
                code: "independent_oracle_failed",
                message: "One or more oracle comparisons did not use an independently identified implementation family.",
                observedCount: summary.nonIndependentOracleCaseCount,
                requiredCount: 0
            ))
        }
        if requireIndependentOracle && summary.oracleCaseCount < caseCount {
            failures.append(DRCCorpusQualificationFailure(
                code: "independent_oracle_missing",
                message: "Independent-oracle qualification requires an oracle comparison for every corpus case.",
                observedCount: summary.oracleCaseCount,
                requiredCount: caseCount
            ))
        }
        if !allowPrimaryExecutionFailures && summary.primaryExecutionFailedCaseCount > 0 {
            failures.append(DRCCorpusQualificationFailure(
                code: "primary_execution_failed",
                message: "One or more primary corpus cases failed to execute.",
                observedCount: summary.primaryExecutionFailedCaseCount,
                requiredCount: 0
            ))
        }
        if !allowOracleExecutionFailures && summary.oracleExecutionFailedCaseCount > 0 {
            failures.append(DRCCorpusQualificationFailure(
                code: "oracle_execution_failed",
                message: "One or more oracle corpus cases failed to execute.",
                observedCount: summary.oracleExecutionFailedCaseCount,
                requiredCount: 0
            ))
        }
        let missingCoverageTags = requiredCoverageTags.filter { summary.coverageTagCounts[$0] == nil }
        if !missingCoverageTags.isEmpty {
            failures.append(DRCCorpusQualificationFailure(
                code: "required_coverage_missing",
                message: "The corpus is missing one or more required coverage tags.",
                observedCount: requiredCoverageTags.count - missingCoverageTags.count,
                requiredCount: requiredCoverageTags.count,
                observedText: summary.coverageTagCounts.keys.sorted().joined(separator: ","),
                requiredText: missingCoverageTags.joined(separator: ",")
            ))
        }
        return DRCCorpusQualificationResult(policy: self, failures: failures)
    }

    public func with(requireIndependentOracle: Bool) -> DRCCorpusQualificationPolicy {
        DRCCorpusQualificationPolicy(
            requireCorpusPassed: requireCorpusPassed,
            minimumPassRate: minimumPassRate,
            minimumDurationBudgetPassRate: minimumDurationBudgetPassRate,
            minimumOracleCaseCount: minimumOracleCaseCount,
            minimumOracleAgreementRate: minimumOracleAgreementRate,
            requireIndependentOracle: requireIndependentOracle,
            allowPrimaryExecutionFailures: allowPrimaryExecutionFailures,
            allowOracleExecutionFailures: allowOracleExecutionFailures,
            requiredCoverageTags: requiredCoverageTags
        )
    }

    public func validate() throws {
        let failures = validationFailures()
        guard failures.isEmpty else {
            let message = failures
                .map { [$0.code, $0.message].joined(separator: ": ") }
                .joined(separator: "; ")
            throw DRCError.invalidInput("Invalid DRC corpus qualification policy: \(message)")
        }
    }

    private func validationFailures() -> [DRCCorpusQualificationFailure] {
        var failures: [DRCCorpusQualificationFailure] = []
        if minimumPassRate < 0 || minimumPassRate > 1 || !minimumPassRate.isFinite {
            failures.append(DRCCorpusQualificationFailure(
                code: "invalid_minimum_pass_rate",
                message: "minimumPassRate must be a finite value between 0 and 1.",
                observedDouble: minimumPassRate
            ))
        }
        if minimumDurationBudgetPassRate < 0
            || minimumDurationBudgetPassRate > 1
            || !minimumDurationBudgetPassRate.isFinite {
            failures.append(DRCCorpusQualificationFailure(
                code: "invalid_minimum_duration_budget_pass_rate",
                message: "minimumDurationBudgetPassRate must be a finite value between 0 and 1.",
                observedDouble: minimumDurationBudgetPassRate
            ))
        }
        if let minimumOracleAgreementRate,
           minimumOracleAgreementRate < 0
            || minimumOracleAgreementRate > 1
            || !minimumOracleAgreementRate.isFinite {
            failures.append(DRCCorpusQualificationFailure(
                code: "invalid_minimum_oracle_agreement_rate",
                message: "minimumOracleAgreementRate must be a finite value between 0 and 1.",
                observedDouble: minimumOracleAgreementRate
            ))
        }
        if let minimumOracleCaseCount,
           minimumOracleCaseCount < 0 {
            failures.append(DRCCorpusQualificationFailure(
                code: "invalid_minimum_oracle_case_count",
                message: "minimumOracleCaseCount must be zero or greater.",
                observedCount: minimumOracleCaseCount
            ))
        }
        return failures
    }

    private static func normalizedCoverageTags(_ tags: [String]) -> [String] {
        Array(Set(tags.filter { !$0.isEmpty })).sorted()
    }
}
