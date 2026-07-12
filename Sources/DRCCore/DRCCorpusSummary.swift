public struct DRCCorpusSummary: Sendable, Hashable, Codable {
    public let expectationMatchedCaseCount: Int
    public let durationBudgetPassedCaseCount: Int
    public let primaryExecutionFailedCaseCount: Int
    public let oracleCaseCount: Int
    public let oracleAgreementPassedCaseCount: Int
    public let oracleExecutionFailedCaseCount: Int
    public let oracleReadinessBlockedCaseCount: Int
    public let nonIndependentOracleCaseCount: Int
    public let failureCategoryCounts: [String: Int]
    public let coverageTagCounts: [String: Int]
    public let passRate: Double
    public let oracleAgreementRate: Double?

    private enum CodingKeys: String, CodingKey {
        case expectationMatchedCaseCount
        case durationBudgetPassedCaseCount
        case primaryExecutionFailedCaseCount
        case oracleCaseCount
        case oracleAgreementPassedCaseCount
        case oracleExecutionFailedCaseCount
        case oracleReadinessBlockedCaseCount
        case nonIndependentOracleCaseCount
        case failureCategoryCounts
        case coverageTagCounts
        case passRate
        case oracleAgreementRate
    }

    public init(
        expectationMatchedCaseCount: Int,
        durationBudgetPassedCaseCount: Int,
        primaryExecutionFailedCaseCount: Int,
        oracleCaseCount: Int,
        oracleAgreementPassedCaseCount: Int,
        oracleExecutionFailedCaseCount: Int,
        oracleReadinessBlockedCaseCount: Int = 0,
        failureCategoryCounts: [String: Int],
        coverageTagCounts: [String: Int] = [:],
        passRate: Double,
        oracleAgreementRate: Double?,
        nonIndependentOracleCaseCount: Int = 0
    ) {
        self.expectationMatchedCaseCount = expectationMatchedCaseCount
        self.durationBudgetPassedCaseCount = durationBudgetPassedCaseCount
        self.primaryExecutionFailedCaseCount = primaryExecutionFailedCaseCount
        self.oracleCaseCount = oracleCaseCount
        self.oracleAgreementPassedCaseCount = oracleAgreementPassedCaseCount
        self.oracleExecutionFailedCaseCount = oracleExecutionFailedCaseCount
        self.oracleReadinessBlockedCaseCount = oracleReadinessBlockedCaseCount
        self.nonIndependentOracleCaseCount = nonIndependentOracleCaseCount
        self.failureCategoryCounts = failureCategoryCounts
        self.coverageTagCounts = coverageTagCounts
        self.passRate = passRate
        self.oracleAgreementRate = oracleAgreementRate
    }

    public init(caseResults: [DRCCorpusCaseResult]) {
        let caseCount = caseResults.count
        let oracleResults = caseResults.compactMap(\.oracleResult)
        self.init(
            expectationMatchedCaseCount: caseResults.filter(\.expectationMatched).count,
            durationBudgetPassedCaseCount: caseResults.filter(\.durationBudgetPassed).count,
            primaryExecutionFailedCaseCount: caseResults.filter { $0.executionError != nil }.count,
            oracleCaseCount: oracleResults.count,
            oracleAgreementPassedCaseCount: oracleResults.filter(\.agreementPassed).count,
            oracleExecutionFailedCaseCount: oracleResults.filter { $0.executionError != nil }.count,
            oracleReadinessBlockedCaseCount: oracleResults.filter { $0.readinessStatus == .blocked }.count,
            failureCategoryCounts: Self.failureCategoryCounts(in: caseResults),
            coverageTagCounts: Self.coverageTagCounts(in: caseResults),
            passRate: caseCount == 0 ? 0 : Double(caseResults.filter(\.matched).count) / Double(caseCount),
            oracleAgreementRate: oracleResults.isEmpty
                ? nil
                : Double(oracleResults.filter(\.agreementPassed).count) / Double(oracleResults.count),
            nonIndependentOracleCaseCount: caseResults.filter(Self.hasNonIndependentOracle).count
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        expectationMatchedCaseCount = try container.decode(Int.self, forKey: .expectationMatchedCaseCount)
        durationBudgetPassedCaseCount = try container.decode(Int.self, forKey: .durationBudgetPassedCaseCount)
        primaryExecutionFailedCaseCount = try container.decode(Int.self, forKey: .primaryExecutionFailedCaseCount)
        oracleCaseCount = try container.decode(Int.self, forKey: .oracleCaseCount)
        oracleAgreementPassedCaseCount = try container.decode(Int.self, forKey: .oracleAgreementPassedCaseCount)
        oracleExecutionFailedCaseCount = try container.decode(Int.self, forKey: .oracleExecutionFailedCaseCount)
        oracleReadinessBlockedCaseCount = try container.decode(Int.self, forKey: .oracleReadinessBlockedCaseCount)
        nonIndependentOracleCaseCount = try container.decodeIfPresent(
            Int.self,
            forKey: .nonIndependentOracleCaseCount
        ) ?? 0
        failureCategoryCounts = try container.decode([String: Int].self, forKey: .failureCategoryCounts)
        coverageTagCounts = try container.decode([String: Int].self, forKey: .coverageTagCounts)
        passRate = try container.decode(Double.self, forKey: .passRate)
        oracleAgreementRate = try container.decodeIfPresent(Double.self, forKey: .oracleAgreementRate)
    }

    private static func failureCategoryCounts(in caseResults: [DRCCorpusCaseResult]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for reason in caseResults.flatMap(\.failureReasons) {
            counts[category(for: reason), default: 0] += 1
        }
        return counts
    }

    private static func coverageTagCounts(in caseResults: [DRCCorpusCaseResult]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for tag in caseResults.flatMap(\.coverageTags) {
            counts[tag, default: 0] += 1
        }
        return counts
    }

    private static func category(for reason: String) -> String {
        if let separatorIndex = reason.firstIndex(of: ":") {
            return String(reason[..<separatorIndex])
        }
        return reason
    }

    private static func hasNonIndependentOracle(_ caseResult: DRCCorpusCaseResult) -> Bool {
        let failureReasonIndicatesNonIndependence = caseResult.oracleResult?.failureReasons.contains {
            switch category(for: $0) {
            case "same_backend_reference", "same_implementation_family_reference", "reference_independence_unproven":
                return true
            default:
                return false
            }
        } ?? false
        if failureReasonIndicatesNonIndependence {
            return true
        }
        guard let primaryBackendID = caseResult.primaryProvenance?.backendID,
              let oracleResult = caseResult.oracleResult else {
            return false
        }
        let primaryIdentity = caseResult.primaryProvenance?.backendIdentity
            ?? DRCBackendIdentity(backendID: primaryBackendID)
        let oracleIdentity = oracleResult.backendIdentity
            ?? DRCBackendIdentity(backendID: oracleResult.backendID)
        return !primaryIdentity.isIndependent(from: oracleIdentity)
    }
}
