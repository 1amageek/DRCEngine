import Foundation
import Testing
import DRCCore

@Suite("DRC corpus evidence kind")
struct DRCCorpusEvidenceKindTests {
    @Test func corpusSpecDecodingRequiresCurrentSchemaVersion() {
        let missingSchema = Data(#"{"cases":[]}"#.utf8)
        let unsupportedSchema = Data(#"{"schemaVersion":0,"cases":[]}"#.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusSpec.self, from: missingSchema)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusSpec.self, from: unsupportedSchema)
        }
    }

    @Test func corpusSpecDecodingRequiresCurrentEvidenceContract() throws {
        let spec = DRCCorpusSpec(cases: [])

        for key in ["evidenceKind", "acceptanceCriteria"] {
            let data = try encoded(spec, removing: key)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusSpec.self, from: data)
            }
        }
    }

    @Test func corpusReportDecodingRequiresCurrentEvidenceContract() throws {
        let report = DRCCorpusReport(
            passed: false,
            caseCount: 0,
            matchedCaseCount: 0,
            caseResults: []
        )

        for key in ["completed", "evidenceKind"] {
            let data = try encoded(report, removing: key)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusReport.self, from: data)
            }
        }
    }

    @Test func oracleComparisonDecodingRequiresMarkerContract() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let comparison = DRCCorpusOracleComparison(
            primaryBackendID: "native-gds",
            oracleBackendID: "magic",
            passedMatched: true,
            activeErrorRuleIDsMatched: true,
            ruleAssertionsMatched: true,
            diagnosticSummaryMatched: true,
            primaryPassed: true,
            oraclePassed: true,
            primaryActiveErrorRuleIDs: [],
            oracleActiveErrorRuleIDs: [],
            primaryDiagnosticSummary: summary,
            oracleDiagnosticSummary: summary,
            mismatchReasons: []
        )
        let requiredKeys = [
            "markerCorrelationRequired",
            "primaryMarkerFingerprints",
            "oracleMarkerFingerprints",
            "markerSetMatched",
            "agreementPassed",
        ]

        for key in requiredKeys {
            let data = try encoded(comparison, removing: key)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusOracleComparison.self, from: data)
            }
        }
    }

    @Test func oracleResultDecodingRequiresMarkerFingerprints() throws {
        let result = DRCCorpusOracleResult(
            backendID: "magic",
            passed: true,
            activeErrorRuleIDs: [],
            diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0),
            durationSeconds: 0.1,
            agreementPassed: true,
            failureReasons: [],
            reportPath: nil,
            manifestPath: nil
        )
        let data = try encoded(result, removing: "markerFingerprints")

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusOracleResult.self, from: data)
        }
    }

    @Test func coveragePolicyDecodingRequiresCurrentSchemaVersion() {
        let missingSchema = Data(#"{"policyID":"strict","requirements":[]}"#.utf8)
        let unsupportedSchema = Data(
            #"{"schemaVersion":0,"policyID":"strict","requirements":[]}"#.utf8
        )

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: missingSchema)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: unsupportedSchema)
        }
    }

    @Test func coveragePolicyDecodingRequiresEveryFailClosedGate() throws {
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: "strict",
            requirePassingAssessment: true,
            requireOracleAgreement: true,
            requireIndependentOracle: true,
            requireOracleReadiness: true,
            requireDurationBudget: true,
            minimumCaseCount: 1,
            requirements: [DRCCorpusCoverageAuditPolicy.Requirement(
                requirementID: "coverage",
                title: "Coverage",
                requiredCoverageTags: ["drc.width"]
            )]
        )
        let encoded = try JSONEncoder().encode(policy)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        for key in [
            "requirePassingAssessment",
            "requireOracleAgreement",
            "requireIndependentOracle",
            "requireOracleReadiness",
            "requireDurationBudget",
            "minimumCaseCount",
            "maxReportAgeSeconds",
            "requirements",
        ] {
            var incomplete = object
            incomplete.removeValue(forKey: key)
            let data = try JSONSerialization.data(withJSONObject: incomplete)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: data)
            }
        }
    }

    @Test func coveragePolicyDecodingRejectsInvalidStructure() throws {
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: "strict",
            minimumCaseCount: 1,
            requirements: [DRCCorpusCoverageAuditPolicy.Requirement(
                requirementID: "coverage",
                title: "Coverage",
                requiredCoverageTags: ["drc.width"]
            )]
        )
        let encoded = try JSONEncoder().encode(policy)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        let mutations: [(inout [String: Any]) -> Void] = [
            { value in value["policyID"] = " " },
            { value in value["minimumCaseCount"] = 0 },
            { value in value["requirements"] = [] },
        ]
        for mutation in mutations {
            var invalid = object
            mutation(&invalid)
            let data = try JSONSerialization.data(withJSONObject: invalid)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusCoverageAuditPolicy.self, from: data)
            }
        }
    }

    @Test func programmaticInvalidCoveragePolicyFailsClosed() {
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: " ",
            requirePassingAssessment: false,
            requireOracleAgreement: false,
            requireOracleReadiness: false,
            requireDurationBudget: false,
            minimumCaseCount: 0,
            maxReportAgeSeconds: -.infinity,
            requirements: []
        )

        #expect(throws: EncodingError.self) {
            _ = try JSONEncoder().encode(policy)
        }

        let report = DRCCorpusReport(
            passed: false,
            caseCount: 0,
            matchedCaseCount: 0,
            caseResults: []
        )
        let audit = DRCCorpusCoverageAuditor().audit(report: report, policy: policy)
        #expect(audit.status == .incomplete)
        #expect(audit.policyID == "invalid-policy")
        #expect(audit.missingRequirements.contains {
            $0.requirementID.hasPrefix("coverage-policy-invalid-")
        })
    }

    @Test func corpusRunOptionsDecodingRequiresTrustGates() throws {
        let options = DRCCorpusRunOptions()
        for key in ["requireSignedArtifacts", "requireAntennaRules"] {
            let data = try encoded(options, removing: key)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DRCCorpusRunOptions.self, from: data)
            }
        }
    }

    @Test func corpusCaseCanonicalIdentityIsValidated() {
        let invalid = DRCCorpusSpec(cases: [
            DRCCorpusCase(
                caseID: "identity",
                layoutPath: "layout.json",
                topCell: "top",
                canonicalStateDigest: "not-a-digest",
                expectedPassed: true
            ),
        ])

        #expect(throws: DRCError.self) {
            try invalid.validate()
        }
    }

    @Test func independentCorrelationAutomaticallyRequiresIndependentOracle() {
        let spec = DRCCorpusSpec(
            evidenceKind: .independentCorrelation,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(),
            cases: []
        )
        #expect(spec.effectiveAcceptanceCriteria.requireIndependentOracle)
    }

    @Test func independentRuleCorrelationAutomaticallyRequiresIndependentOracle() {
        let spec = DRCCorpusSpec(
            evidenceKind: .independentRuleCorrelation,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(),
            cases: []
        )
        #expect(spec.effectiveAcceptanceCriteria.requireIndependentOracle)
    }

    @Test func regressionKeepsExplicitPolicyWithoutPromotingEvidence() {
        let spec = DRCCorpusSpec(
            evidenceKind: .regression,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(),
            cases: []
        )
        #expect(spec.evidenceKind == .regression)
        #expect(!spec.effectiveAcceptanceCriteria.requireIndependentOracle)
    }

    @Test func corpusSpecValidationRejectsDuplicateCaseIDsBeforeExecution() {
        let caseValue = DRCCorpusCase(
            caseID: "duplicate",
            layoutPath: "layout.json",
            topCell: "top",
            expectedPassed: true
        )
        let spec = DRCCorpusSpec(cases: [caseValue, caseValue])

        #expect(throws: DRCError.self) {
            try spec.validate()
        }
    }

    @Test func corpusSpecValidationRejectsInvalidCaseEnvironment() {
        let spec = DRCCorpusSpec(cases: [DRCCorpusCase(
            caseID: "invalid-environment",
            layoutPath: "layout.json",
            topCell: "top",
            additionalEnvironment: ["1INVALID": "value"],
            expectedPassed: true
        )])

        #expect(throws: DRCError.self) {
            try spec.validate()
        }
    }

    @Test func oracleRuleAssertionsRequireDeclaredOracleBackend() {
        let spec = DRCCorpusSpec(cases: [DRCCorpusCase(
            caseID: "missing-oracle-backend",
            layoutPath: "layout.gds",
            topCell: "top",
            backendID: "native-gds",
            expectedPassed: false,
            expectedActiveErrorRuleIDs: ["native.width"],
            expectedOracleActiveErrorRuleIDs: ["magic.width"]
        )])

        #expect(throws: DRCError.self) {
            try spec.validate()
        }
    }

    @Test func independentAssessmentRejectsMissingOracleCases() {
        let summary = DRCCorpusSummary(
            expectationMatchedCaseCount: 1,
            durationBudgetPassedCaseCount: 1,
            primaryExecutionFailedCaseCount: 0,
            oracleCaseCount: 0,
            oracleAgreementPassedCaseCount: 0,
            oracleExecutionFailedCaseCount: 0,
            failureCategoryCounts: [:],
            passRate: 1,
            oracleAgreementRate: nil
        )
        let result = DRCCorpusAcceptanceCriteria(requireIndependentOracle: true).evaluate(
            passed: true,
            caseCount: 1,
            summary: summary
        )

        #expect(result.findings.contains { $0.code == "independent_oracle_missing" })
    }

    @Test func missingOracleAgreementDoesNotHideOtherAssessmentFindings() {
        let summary = DRCCorpusSummary(
            expectationMatchedCaseCount: 0,
            durationBudgetPassedCaseCount: 0,
            primaryExecutionFailedCaseCount: 1,
            oracleCaseCount: 0,
            oracleAgreementPassedCaseCount: 0,
            oracleExecutionFailedCaseCount: 0,
            failureCategoryCounts: [:],
            passRate: 0,
            oracleAgreementRate: nil
        )
        let policy = DRCCorpusAcceptanceCriteria(
            minimumOracleAgreementRate: 1,
            requireIndependentOracle: true
        )
        let result = policy.evaluate(passed: false, caseCount: 1, summary: summary)

        #expect(result.findings.contains { $0.code == "oracle_agreement_rate_missing" })
        #expect(result.findings.contains { $0.code == "independent_oracle_missing" })
        #expect(result.findings.contains { $0.code == "primary_execution_failed" })
    }

    @Test func corpusReportValidationRejectsTamperedCaseCounts() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseResult = DRCCorpusCaseResult(
            caseID: "case",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            expectationMatched: true,
            durationSeconds: 0.1,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: nil,
            manifestPath: nil
        )
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 2,
            matchedCaseCount: 2,
            caseResults: [caseResult]
        )

        #expect(throws: DRCError.self) {
            try report.validate()
        }
    }

    @Test func independentReportConstructorUsesIndependentAssessmentCriteria() {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseResult = DRCCorpusCaseResult(
            caseID: "independent-without-oracle",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            expectationMatched: true,
            durationSeconds: 0.1,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: nil,
            manifestPath: nil
        )
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            evidenceKind: .independentCorrelation,
            caseResults: [caseResult]
        )

        #expect(!report.assessment.meetsCriteria)
        #expect(report.assessment.findings.contains { $0.code == "independent_oracle_missing" })
    }

    private func encoded<T: Encodable>(_ value: T, removing key: String) throws -> Data {
        let encoded = try JSONEncoder().encode(value)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: object)
    }
}
