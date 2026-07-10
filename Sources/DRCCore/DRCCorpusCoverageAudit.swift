public enum DRCCorpusCoverageAuditStatus: String, Sendable, Hashable, Codable {
    case satisfied
    case incomplete
}

public struct DRCCorpusCoverageAudit: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let auditID: String
    public let status: DRCCorpusCoverageAuditStatus
    public let policyID: String
    public let reportPath: String?
    public let summary: Summary
    public let observedCoverageTags: [String]
    public let coverageFamilies: [CoverageFamilySummary]
    public let missingRequirements: [MissingRequirement]
    public let suggestedActions: [SuggestedAction]

    public init(
        schemaVersion: Int = DRCCorpusCoverageAudit.currentSchemaVersion,
        auditID: String,
        status: DRCCorpusCoverageAuditStatus,
        policyID: String,
        reportPath: String? = nil,
        summary: Summary,
        observedCoverageTags: [String],
        coverageFamilies: [CoverageFamilySummary] = [],
        missingRequirements: [MissingRequirement] = [],
        suggestedActions: [SuggestedAction] = []
    ) {
        self.schemaVersion = schemaVersion
        self.auditID = auditID
        self.status = status
        self.policyID = policyID
        self.reportPath = reportPath
        self.summary = summary
        self.observedCoverageTags = Array(Set(observedCoverageTags.filter { !$0.isEmpty })).sorted()
        self.coverageFamilies = coverageFamilies.sorted { lhs, rhs in
            lhs.familyID < rhs.familyID
        }
        self.missingRequirements = missingRequirements.sorted { lhs, rhs in
            lhs.requirementID < rhs.requirementID
        }
        self.suggestedActions = suggestedActions.sorted { lhs, rhs in
            lhs.actionID < rhs.actionID
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case auditID
        case status
        case policyID
        case reportPath
        case summary
        case observedCoverageTags
        case coverageFamilies
        case missingRequirements
        case suggestedActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported DRC corpus coverage audit schema version: \(schemaVersion)."
            )
        }
        self.init(
            schemaVersion: schemaVersion,
            auditID: try container.decode(String.self, forKey: .auditID),
            status: try container.decode(DRCCorpusCoverageAuditStatus.self, forKey: .status),
            policyID: try container.decode(String.self, forKey: .policyID),
            reportPath: try container.decodeIfPresent(String.self, forKey: .reportPath),
            summary: try container.decode(Summary.self, forKey: .summary),
            observedCoverageTags: try container.decode([String].self, forKey: .observedCoverageTags),
            coverageFamilies: try container.decode([CoverageFamilySummary].self, forKey: .coverageFamilies),
            missingRequirements: try container.decode([MissingRequirement].self, forKey: .missingRequirements),
            suggestedActions: try container.decode([SuggestedAction].self, forKey: .suggestedActions)
        )
    }

    public struct Summary: Sendable, Hashable, Codable {
        public let caseCount: Int
        public let matchedCaseCount: Int
        public let qualified: Bool
        public let durationBudgetPassedCaseCount: Int
        public let durationBudgetPassRate: Double
        public let oracleCaseCount: Int
        public let oracleAgreementPassedCaseCount: Int
        public let oracleReadinessBlockedCaseCount: Int
        public let oracleExecutionFailedCaseCount: Int
        public let requiredRequirementCount: Int
        public let satisfiedRequirementCount: Int
        public let missingRequirementCount: Int
        public let observedCoverageTagCount: Int
        public let requiredCoverageTagCount: Int
        public let coveredRequiredCoverageTagCount: Int
        public let reportGeneratedAt: String?
        public let checkedAt: String?
        public let reportAgeSeconds: Double?

        public init(
            caseCount: Int,
            matchedCaseCount: Int,
            qualified: Bool,
            durationBudgetPassedCaseCount: Int,
            durationBudgetPassRate: Double,
            oracleCaseCount: Int,
            oracleAgreementPassedCaseCount: Int,
            oracleReadinessBlockedCaseCount: Int,
            oracleExecutionFailedCaseCount: Int,
            requiredRequirementCount: Int,
            satisfiedRequirementCount: Int,
            missingRequirementCount: Int,
            observedCoverageTagCount: Int,
            requiredCoverageTagCount: Int,
            coveredRequiredCoverageTagCount: Int,
            reportGeneratedAt: String? = nil,
            checkedAt: String? = nil,
            reportAgeSeconds: Double? = nil
        ) {
            self.caseCount = caseCount
            self.matchedCaseCount = matchedCaseCount
            self.qualified = qualified
            self.durationBudgetPassedCaseCount = durationBudgetPassedCaseCount
            self.durationBudgetPassRate = durationBudgetPassRate
            self.oracleCaseCount = oracleCaseCount
            self.oracleAgreementPassedCaseCount = oracleAgreementPassedCaseCount
            self.oracleReadinessBlockedCaseCount = oracleReadinessBlockedCaseCount
            self.oracleExecutionFailedCaseCount = oracleExecutionFailedCaseCount
            self.requiredRequirementCount = requiredRequirementCount
            self.satisfiedRequirementCount = satisfiedRequirementCount
            self.missingRequirementCount = missingRequirementCount
            self.observedCoverageTagCount = observedCoverageTagCount
            self.requiredCoverageTagCount = requiredCoverageTagCount
            self.coveredRequiredCoverageTagCount = coveredRequiredCoverageTagCount
            self.reportGeneratedAt = reportGeneratedAt
            self.checkedAt = checkedAt
            self.reportAgeSeconds = reportAgeSeconds
        }
    }

    public struct CoverageFamilySummary: Sendable, Hashable, Codable {
        public let familyID: String
        public let observedCoverageTags: [String]
        public let requiredCoverageTags: [String]
        public let coveredRequiredCoverageTags: [String]
        public let missingRequiredCoverageTags: [String]
        public let observedCaseCount: Int
        public let requiredRequirementCount: Int
        public let satisfiedRequirementCount: Int
        public let missingRequirementCount: Int
        public let coveragePassRate: Double

        public init(
            familyID: String,
            observedCoverageTags: [String],
            requiredCoverageTags: [String],
            coveredRequiredCoverageTags: [String],
            missingRequiredCoverageTags: [String],
            observedCaseCount: Int,
            requiredRequirementCount: Int,
            satisfiedRequirementCount: Int,
            missingRequirementCount: Int,
            coveragePassRate: Double
        ) {
            self.familyID = familyID
            self.observedCoverageTags = Self.normalized(observedCoverageTags)
            self.requiredCoverageTags = Self.normalized(requiredCoverageTags)
            self.coveredRequiredCoverageTags = Self.normalized(coveredRequiredCoverageTags)
            self.missingRequiredCoverageTags = Self.normalized(missingRequiredCoverageTags)
            self.observedCaseCount = observedCaseCount
            self.requiredRequirementCount = requiredRequirementCount
            self.satisfiedRequirementCount = satisfiedRequirementCount
            self.missingRequirementCount = missingRequirementCount
            self.coveragePassRate = coveragePassRate
        }

        private static func normalized(_ values: [String]) -> [String] {
            Array(Set(values.filter { !$0.isEmpty })).sorted()
        }
    }

    public struct MissingRequirement: Sendable, Hashable, Codable {
        public let requirementID: String
        public let title: String
        public let missingCoverageTags: [String]
        public let observedCaseCount: Int
        public let requiredCaseCount: Int
        public let reason: String
        public let suggestedActions: [String]

        public init(
            requirementID: String,
            title: String,
            missingCoverageTags: [String],
            observedCaseCount: Int,
            requiredCaseCount: Int,
            reason: String,
            suggestedActions: [String]
        ) {
            self.requirementID = requirementID
            self.title = title
            self.missingCoverageTags = Array(Set(missingCoverageTags.filter { !$0.isEmpty })).sorted()
            self.observedCaseCount = observedCaseCount
            self.requiredCaseCount = requiredCaseCount
            self.reason = reason
            self.suggestedActions = Array(Set(suggestedActions.filter { !$0.isEmpty })).sorted()
        }
    }

    public struct SuggestedAction: Sendable, Hashable, Codable {
        public let actionID: String
        public let requirementID: String
        public let reason: String

        public init(actionID: String, requirementID: String, reason: String) {
            self.actionID = actionID
            self.requirementID = requirementID
            self.reason = reason
        }
    }
}
