import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    @Test func corpusEvidenceOptionsParseCheckedAtAndEvidenceID() throws {
        let options = try DRCCorpusEvidenceCLIOptions(arguments: [
            "--evidence-from-corpus-report", "/tmp/drc-corpus-report.json",
            "--evidence-id", "drc-release-corpus",
            "--checked-at", "2026-06-18T00:00:00Z",
            "--json",
        ])

        #expect(options.reportURL.path(percentEncoded: false) == "/tmp/drc-corpus-report.json")
        #expect(options.evidenceID == "drc-release-corpus")
        #expect(options.checkedAt.timeIntervalSince1970 == 1_781_740_800)
        #expect(options.emitJSON)
    }

    @Test func signedCorpusEvidenceCLIWritesVerifiableArtifact() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let evidenceURL = root.appending(path: "signed-evidence.json")
        let keyURL = root.appending(path: "evidence.key")
        let keyData = Data(repeating: 9, count: 32)
        let signer = try DRCEd25519ArtifactSigner(rawRepresentation: keyData)
        try keyData.write(to: keyURL, options: [.atomic])

        let corpusExitCode = await DRCCLI.run(arguments: [
            "--corpus", fixtureCorpusSpecURL("drc-corpus-tight-budget.json").path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])
        #expect(corpusExitCode == 2)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")

        let evidenceExitCode = await DRCCLI.run(arguments: [
            "--evidence-from-corpus-report", reportURL.path(percentEncoded: false),
            "--out", evidenceURL.path(percentEncoded: false),
            "--checked-at", "2026-06-18T00:00:00Z",
            "--require-signed-artifacts",
            "--trusted-artifact-public-key", signer.publicKey,
            "--artifact-signing-private-key", keyURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(evidenceExitCode == 2)
        #expect(try DRCCorpusToolEvidenceVerifier().verify(
            evidenceURL: evidenceURL,
            reportURL: reportURL,
            requireSignature: true,
            trustedPublicKey: signer.publicKey
        ).isEmpty)
    }

    @Test func corpusCoverageAuditOptionsParsePolicyOutputAndAuditID() throws {
        let options = try DRCCorpusCoverageAuditCLIOptions(arguments: [
            "--audit-corpus-coverage", "/tmp/drc-corpus-report.json",
            "--include-corpus-report", "/tmp/drc-magic-corpus-report.json",
            "--coverage-policy", "/tmp/drc-coverage-policy.json",
            "--out", "/tmp/drc-corpus-coverage-audit.json",
            "--audit-id", "drc-magic-expansion",
            "--checked-at", "2026-06-18T00:00:00Z",
            "--json",
        ])

        #expect(options.reportURL.path(percentEncoded: false) == "/tmp/drc-corpus-report.json")
        #expect(options.includedReportURLs.map { $0.path(percentEncoded: false) } == [
            "/tmp/drc-magic-corpus-report.json",
        ])
        #expect(options.policyURL?.path(percentEncoded: false) == "/tmp/drc-coverage-policy.json")
        #expect(options.outputURL?.path(percentEncoded: false) == "/tmp/drc-corpus-coverage-audit.json")
        #expect(options.auditID == "drc-magic-expansion")
        #expect(options.checkedAt?.timeIntervalSince1970 == 1_781_740_800)
        #expect(options.emitJSON)
    }

    @Test func evidencePacketOptionsParseReportOutputAndPacketID() throws {
        let options = try DRCEvidencePacketCLIOptions(arguments: [
            "--evidence-packet-from-corpus-report", "/tmp/drc-corpus-report.json",
            "--out", "/tmp/drc-evidence-packet.json",
            "--packet-id", "drc-evidence-release",
            "--json",
        ])

        #expect(options.reportURL.path(percentEncoded: false) == "/tmp/drc-corpus-report.json")
        #expect(options.outputURL?.path(percentEncoded: false) == "/tmp/drc-evidence-packet.json")
        #expect(options.packetID == "drc-evidence-release")
        #expect(options.emitJSON)
    }

    @Test func corpusCoverageAuditClassifiesMagicOracleExpansionGaps() throws {
        let report = failingDRCCorpusReport()

        let audit = DRCCorpusCoverageAuditor().audit(
            report: report,
            reportPath: "/tmp/drc-corpus-report.json"
        )

        #expect(audit.status == .incomplete)
        #expect(audit.policyID == "drc.magic-foundry-expansion.v1")
        #expect(audit.summary.caseCount == 1)
        #expect(audit.summary.oracleCaseCount == 1)
        #expect(audit.summary.oracleReadinessBlockedCaseCount == 1)
        #expect(audit.summary.oracleAgreementPassedCaseCount == 0)
        #expect(audit.summary.missingRequirementCount > 0)
        let missingIDs = Set(audit.missingRequirements.map(\.requirementID))
        #expect(missingIDs.contains("qualified-corpus"))
        #expect(missingIDs.contains("oracle-agreement"))
        #expect(missingIDs.contains("oracle-readiness"))
        #expect(missingIDs.contains("magic-oracle-baseline"))
        #expect(missingIDs.contains("sky130-standard-layout-oracle"))
        #expect(audit.suggestedActions.contains { $0.actionID == "fix_drc_magic_input_technology_mapping" })
        #expect(audit.suggestedActions.contains { $0.actionID == "retain_sky130_magic_gds_cases" })

        let widthFamily = try #require(audit.coverageFamilies.first { $0.familyID == "drc.width" })
        #expect(widthFamily.observedCoverageTags.contains("drc.width"))
        #expect(widthFamily.missingRequiredCoverageTags.contains("drc.width.external-oracle"))
        #expect(widthFamily.observedCaseCount == 1)
        #expect(widthFamily.missingRequirementCount > 0)

        let spacingFamily = try #require(audit.coverageFamilies.first { $0.familyID == "drc.spacing" })
        #expect(spacingFamily.observedCoverageTags.isEmpty)
        #expect(spacingFamily.requiredCoverageTags.contains("drc.spacing.external-oracle"))
        #expect(spacingFamily.coveragePassRate == 0)
        #expect(spacingFamily.observedCaseCount == 0)
    }

    @Test func magicOraclePolicySuggestedActionsDoNotPointToNativeCaseRepair() throws {
        let policy = DRCCorpusCoverageAuditPolicy.magicFoundryExpansion
        let actionIDs = Set(policy.requirements.flatMap(\.suggestedActions))

        #expect(!actionIDs.contains { $0.hasPrefix("add_magic_native_") })
        #expect(actionIDs.contains("add_magic_readable_via2_spacing_cases"))
        #expect(actionIDs.contains("add_magic_readable_via3_spacing_cases"))
        #expect(actionIDs.contains("add_magic_readable_via4_spacing_cases"))
        #expect(actionIDs.contains("add_magic_readable_via4_metal5_enclosure_cases"))
    }

    @Test func corpusCoverageAuditRejectsMissingCoverageFamilies() {
        let incompleteJSON = """
        {
          "schemaVersion": 1,
          "auditID": "incomplete-drc-audit",
          "status": "satisfied",
          "policyID": "incomplete-policy",
          "reportPath": "/tmp/drc-corpus-report.json",
          "summary": {
            "caseCount": 1,
            "matchedCaseCount": 1,
            "qualified": true,
            "durationBudgetPassedCaseCount": 1,
            "durationBudgetPassRate": 1,
            "oracleCaseCount": 1,
            "oracleAgreementPassedCaseCount": 1,
            "oracleReadinessBlockedCaseCount": 0,
            "oracleExecutionFailedCaseCount": 0,
            "requiredRequirementCount": 1,
            "satisfiedRequirementCount": 1,
            "missingRequirementCount": 0,
            "observedCoverageTagCount": 1,
            "requiredCoverageTagCount": 1,
            "coveredRequiredCoverageTagCount": 1
          },
          "observedCoverageTags": ["drc.width"],
          "missingRequirements": [],
          "suggestedActions": []
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DRCCorpusCoverageAudit.self, from: Data(incompleteJSON.utf8))
        }
    }

    @Test func corpusCoverageAuditCLIWritesSatisfiedCustomPolicyReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let reportURL = root.appending(path: "drc-corpus-report.json")
        let policyURL = root.appending(path: "drc-local-coverage-policy.json")
        let auditURL = root.appending(path: "drc-corpus-coverage-audit.json")
        try writeJSON(passingAuditCorpusReport(), to: reportURL)
        try writeJSON(DRCCorpusCoverageAuditPolicy(
            policyID: "drc.local-width-coverage.v1",
            minimumCaseCount: 2,
            requirements: [
                DRCCorpusCoverageAuditPolicy.Requirement(
                    requirementID: "width-diagnostics",
                    title: "Width diagnostics",
                    requiredCoverageTags: ["diagnostic.rule-id", "drc.width"],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_width_drc_cases"]
                ),
            ]
        ), to: policyURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--audit-corpus-coverage", reportURL.path(percentEncoded: false),
            "--coverage-policy", policyURL.path(percentEncoded: false),
            "--out", auditURL.path(percentEncoded: false),
            "--audit-id", "local-width-audit",
            "--json",
        ])

        #expect(exitCode == 0)
        let audit = try JSONDecoder().decode(DRCCorpusCoverageAudit.self, from: Data(contentsOf: auditURL))
        #expect(audit.auditID == "local-width-audit")
        #expect(audit.status == .satisfied)
        #expect(audit.summary.caseCount == 2)
        #expect(audit.summary.requiredRequirementCount == 6)
        #expect(audit.summary.satisfiedRequirementCount == 6)
        #expect(audit.summary.coveredRequiredCoverageTagCount == 2)
        #expect(audit.missingRequirements.isEmpty)

        let widthFamily = try #require(audit.coverageFamilies.first { $0.familyID == "drc.width" })
        #expect(widthFamily.observedCoverageTags == ["drc.width"])
        #expect(widthFamily.requiredCoverageTags == ["drc.width"])
        #expect(widthFamily.coveredRequiredCoverageTags == ["drc.width"])
        #expect(widthFamily.missingRequiredCoverageTags.isEmpty)
        #expect(widthFamily.observedCaseCount == 2)
        #expect(widthFamily.requiredRequirementCount == 1)
        #expect(widthFamily.satisfiedRequirementCount == 1)
        #expect(widthFamily.missingRequirementCount == 0)
        #expect(widthFamily.coveragePassRate == 1)

        let diagnosticFamily = try #require(audit.coverageFamilies.first { $0.familyID == "diagnostic" })
        #expect(diagnosticFamily.observedCoverageTags == ["diagnostic.rule-id"])
        #expect(diagnosticFamily.requiredCoverageTags == ["diagnostic.rule-id"])
        #expect(diagnosticFamily.observedCaseCount == 2)
    }

    @Test func corpusCoverageAuditCLIIncludesMagicExternalReportForDefaultPolicy() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let nativeReportURL = root.appending(path: "drc-native-corpus-report.json")
        let magicReportURL = root.appending(path: "drc-magic-corpus-report.json")
        let auditURL = root.appending(path: "drc-corpus-coverage-audit.json")
        let nativeReport = nativeGDSAuditCorpusReport()
        let magicReport = magicFoundryAuditCorpusReport()
        try writeJSON(nativeReport, to: nativeReportURL)
        try writeJSON(magicReport, to: magicReportURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--audit-corpus-coverage", nativeReportURL.path(percentEncoded: false),
            "--include-corpus-report", magicReportURL.path(percentEncoded: false),
            "--out", auditURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 2)
        let audit = try JSONDecoder().decode(DRCCorpusCoverageAudit.self, from: Data(contentsOf: auditURL))
        #expect(audit.status == .incomplete)
        #expect(audit.policyID == "drc.magic-foundry-expansion.v1")
        #expect(audit.summary.caseCount == 96)
        #expect(audit.summary.oracleCaseCount == 96)
        #expect(audit.summary.missingRequirementCount == 1)
        #expect(audit.summary.satisfiedRequirementCount + 1 == audit.summary.requiredRequirementCount)
        #expect(audit.missingRequirements.contains { $0.requirementID == "independent-oracle" })
        #expect(audit.observedCoverageTags.contains("external.magic"))
        #expect(audit.observedCoverageTags.contains("sky130"))
        #expect(audit.observedCoverageTags.contains("drc.cut.minimum.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.width.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.wide.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.large-attached.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.width.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.wide.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.large-attached.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.area.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.angle.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.area.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.angle.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.mcon"))
        #expect(audit.observedCoverageTags.contains("drc.contact.via1"))
        #expect(audit.observedCoverageTags.contains("drc.contact.width.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.spacing.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.width.via1.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.spacing.via1.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.via2"))
        #expect(audit.observedCoverageTags.contains("drc.contact.width.via2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.spacing.via2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via1.met1.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via1.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via2.met2.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via2.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.width.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.wide.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.large-attached.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.area.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.angle.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.via3"))
        #expect(audit.observedCoverageTags.contains("drc.contact.width.via3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.spacing.via3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via3.met3.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via3.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.via4"))
        #expect(audit.observedCoverageTags.contains("drc.contact.width.via4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.contact.spacing.via4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.enclosure.via4.met5.external-oracle"))
        #expect(audit.observedCoverageTags.contains("layout.magic"))
        #expect(audit.observedCoverageTags.contains("drc.width.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.wide.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.large-attached.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.area.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.angle.met4.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.width.met5.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.spacing.met5.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.area.met5.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.angle.met5.external-oracle"))
        #expect(audit.observedCoverageTags.contains("drc.input.gds"))

        let contactFamily = try #require(audit.coverageFamilies.first { $0.familyID == "drc.contact" })
        #expect(contactFamily.missingRequiredCoverageTags.isEmpty)
        #expect(contactFamily.requiredRequirementCount > 0)
        #expect(contactFamily.satisfiedRequirementCount == contactFamily.requiredRequirementCount)
        #expect(contactFamily.coveragePassRate == 1)

        let externalFamily = try #require(audit.coverageFamilies.first { $0.familyID == "external" })
        #expect(externalFamily.requiredCoverageTags == ["external.magic"])
        #expect(externalFamily.coveredRequiredCoverageTags == ["external.magic"])
        #expect(externalFamily.observedCaseCount == magicReport.caseCount)
    }

    @Test func corpusCoverageAuditRejectsStaleRetainedReport() throws {
        let sourceReport = passingAuditCorpusReport()
        let report = DRCCorpusReport(
            generatedAt: "2026-06-16T00:00:00Z",
            passed: sourceReport.passed,
            caseCount: sourceReport.caseCount,
            matchedCaseCount: sourceReport.matchedCaseCount,
            budgetExceededCaseCount: sourceReport.budgetExceededCaseCount,
            totalDurationSeconds: sourceReport.totalDurationSeconds,
            runOptions: sourceReport.runOptions,
            summary: sourceReport.summary,
            qualification: sourceReport.qualification,
            caseResults: sourceReport.caseResults
        )
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: "drc.freshness.v1",
            requireQualifiedCorpus: false,
            requireOracleAgreement: false,
            requireOracleReadiness: false,
            requireDurationBudget: false,
            minimumCaseCount: 0,
            maxReportAgeSeconds: 86_400,
            requirements: []
        )

        let audit = DRCCorpusCoverageAuditor().audit(
            report: report,
            policy: policy,
            checkedAt: try date("2026-06-18T00:00:00Z")
        )

        #expect(audit.status == .incomplete)
        #expect(audit.summary.reportGeneratedAt == "2026-06-16T00:00:00Z")
        #expect(audit.summary.checkedAt == "2026-06-18T00:00:00Z")
        #expect(audit.summary.reportAgeSeconds == 172_800)
        #expect(audit.missingRequirements.contains {
            $0.requirementID == "retained-report-freshness"
                && $0.suggestedActions == ["rerun_drc_corpus_and_retain_report"]
        })
    }

    @Test func corpusCoverageAuditRejectsBlockedOracleLaneEvenWhenReportIsMarkedPassed() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let result = DRCCorpusCaseResult(
            caseID: "blocked-oracle-marked-pass",
            matched: true,
            expectedPassed: true,
            actualPassed: true,
            expectedActiveErrorRuleIDs: [],
            actualActiveErrorRuleIDs: [],
            coverageTags: ["external.magic", "layout.gds"],
            expectationMatched: true,
            durationSeconds: 0.01,
            expectedMaxDurationSeconds: 1,
            durationBudgetPassed: true,
            failureReasons: [],
            diagnosticSummary: summary,
            reportPath: "/tmp/blocked-oracle-marked-pass/drc-report.json",
            manifestPath: "/tmp/blocked-oracle-marked-pass/drc-artifact-manifest.json",
            oracleResult: DRCCorpusOracleResult(
                backendID: "magic",
                passed: true,
                activeErrorRuleIDs: [],
                diagnosticSummary: summary,
                durationSeconds: 0,
                agreementPassed: true,
                readinessStatus: .blocked,
                readinessDiagnostics: ["Magic oracle was not available."],
                failureReasons: [],
                reportPath: nil,
                manifestPath: nil
            )
        )
        let report = DRCCorpusReport(
            generatedAt: "2026-06-18T00:00:00Z",
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.01,
            caseResults: [result]
        )
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: "drc.oracle-readiness.v1",
            requireQualifiedCorpus: false,
            requireOracleAgreement: true,
            requireOracleReadiness: true,
            requireDurationBudget: false,
            minimumCaseCount: 0,
            requirements: []
        )

        let audit = DRCCorpusCoverageAuditor().audit(
            report: report,
            policy: policy,
            checkedAt: try date("2026-06-18T00:00:00Z")
        )

        #expect(report.qualification.qualified)
        #expect(audit.status == .incomplete)
        #expect(audit.summary.oracleReadinessBlockedCaseCount == 1)
        #expect(audit.missingRequirements.contains {
            $0.requirementID == "oracle-readiness"
                && $0.suggestedActions.contains("inspect_drc_oracle_readiness")
        })
    }

    @Test func corpusCoverageAuditDoesNotEmitNegativeObservedCountsForInconsistentRetainedSummary() throws {
        let report = DRCCorpusReport(
            generatedAt: "2026-06-18T00:00:00Z",
            passed: false,
            caseCount: 1,
            matchedCaseCount: 0,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.01,
            summary: DRCCorpusSummary(
                expectationMatchedCaseCount: 0,
                durationBudgetPassedCaseCount: 1,
                primaryExecutionFailedCaseCount: 0,
                oracleCaseCount: 1,
                oracleAgreementPassedCaseCount: 0,
                oracleExecutionFailedCaseCount: 0,
                oracleReadinessBlockedCaseCount: 3,
                failureCategoryCounts: [:],
                passRate: 0,
                oracleAgreementRate: 0
            ),
            caseResults: []
        )
        let policy = DRCCorpusCoverageAuditPolicy(
            policyID: "drc.oracle-readiness-counts.v1",
            requireQualifiedCorpus: false,
            requireOracleAgreement: false,
            requireOracleReadiness: true,
            requireDurationBudget: false,
            minimumCaseCount: 0,
            requirements: []
        )

        let audit = DRCCorpusCoverageAuditor().audit(
            report: report,
            policy: policy,
            checkedAt: try date("2026-06-18T00:00:00Z")
        )

        let missing = try #require(audit.missingRequirements.first {
            $0.requirementID == "oracle-readiness"
        })
        #expect(missing.observedCaseCount == 0)
        #expect(missing.requiredCaseCount == 1)
    }

    @Test func corpusCoverageAuditIntegrityDetectsInvalidPublicArtifactValues() throws {
        let audit = DRCCorpusCoverageAudit(
            schemaVersion: 999,
            auditID: " ",
            status: .satisfied,
            policyID: "",
            reportPath: " https://example.invalid/report.json ",
            summary: DRCCorpusCoverageAudit.Summary(
                caseCount: 1,
                matchedCaseCount: 2,
                qualified: true,
                durationBudgetPassedCaseCount: 3,
                durationBudgetPassRate: .infinity,
                oracleCaseCount: 1,
                oracleAgreementPassedCaseCount: 2,
                oracleReadinessBlockedCaseCount: 2,
                oracleExecutionFailedCaseCount: -1,
                requiredRequirementCount: 1,
                satisfiedRequirementCount: 1,
                missingRequirementCount: 0,
                observedCoverageTagCount: 2,
                requiredCoverageTagCount: 1,
                coveredRequiredCoverageTagCount: 1,
                reportAgeSeconds: .nan
            ),
            observedCoverageTags: ["drc.width"],
            coverageFamilies: [
                DRCCorpusCoverageAudit.CoverageFamilySummary(
                    familyID: "drc.width",
                    observedCoverageTags: ["drc.width"],
                    requiredCoverageTags: ["drc.width"],
                    coveredRequiredCoverageTags: ["drc.width"],
                    missingRequiredCoverageTags: ["drc.width"],
                    observedCaseCount: -1,
                    requiredRequirementCount: 1,
                    satisfiedRequirementCount: 1,
                    missingRequirementCount: 1,
                    coveragePassRate: .nan
                ),
            ],
            missingRequirements: [
                DRCCorpusCoverageAudit.MissingRequirement(
                    requirementID: "missing-width",
                    title: "",
                    missingCoverageTags: ["drc.width"],
                    observedCaseCount: -1,
                    requiredCaseCount: 1,
                    reason: "",
                    suggestedActions: ["add_width_case"]
                ),
            ],
            suggestedActions: [
                DRCCorpusCoverageAudit.SuggestedAction(
                    actionID: "add_width_case",
                    requirementID: "unknown-requirement",
                    reason: ""
                ),
            ]
        )

        let issues = audit.validateIntegrity()
        let codes = Set(issues.map(\.code))

        #expect(codes.contains("drc_corpus_coverage_audit_schema_version_unsupported"))
        #expect(codes.contains("drc_corpus_coverage_audit_required_field_empty"))
        #expect(codes.contains("drc_corpus_coverage_audit_path_has_whitespace"))
        #expect(codes.contains("drc_corpus_coverage_audit_path_has_url_scheme"))
        #expect(codes.contains("drc_corpus_coverage_audit_invalid_unit_rate"))
        #expect(codes.contains("drc_corpus_coverage_audit_non_finite_report_age_seconds"))
        #expect(codes.contains("drc_corpus_coverage_audit_count_exceeds_total"))
        #expect(codes.contains("drc_corpus_coverage_audit_negative_count"))
        #expect(codes.contains("drc_corpus_coverage_audit_missing_requirement_count_mismatch"))
        #expect(codes.contains("drc_corpus_coverage_audit_observed_tag_count_mismatch"))
        #expect(codes.contains("drc_corpus_coverage_audit_tag_both_covered_and_missing"))
        #expect(codes.contains("drc_corpus_coverage_audit_dangling_suggested_action_requirement"))
        #expect(issues.allSatisfy { !$0.fieldPath.isEmpty && !$0.suggestedActions.isEmpty })
    }

    @Test func corpusCoverageAuditCLICanonicalizesInconsistentRetainedSummaryBeforeAudit() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let reportURL = root.appending(path: "drc-corpus-report.json")
        let auditURL = root.appending(path: "drc-corpus-coverage-audit.json")
        let report = DRCCorpusReport(
            generatedAt: "2026-06-18T00:00:00Z",
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            summary: DRCCorpusSummary(
                expectationMatchedCaseCount: 1,
                durationBudgetPassedCaseCount: 2,
                primaryExecutionFailedCaseCount: 0,
                oracleCaseCount: 0,
                oracleAgreementPassedCaseCount: 0,
                oracleExecutionFailedCaseCount: 0,
                oracleReadinessBlockedCaseCount: 0,
                failureCategoryCounts: [:],
                passRate: 1,
                oracleAgreementRate: nil
            ),
            caseResults: [
                DRCCorpusCaseResult(
                    caseID: "case-a",
                    matched: true,
                    expectedPassed: true,
                    actualPassed: true,
                    expectedActiveErrorRuleIDs: [],
                    actualActiveErrorRuleIDs: [],
                    expectationMatched: true,
                    durationSeconds: 0.01,
                    expectedMaxDurationSeconds: 1,
                    durationBudgetPassed: true,
                    failureReasons: [],
                    diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0),
                    reportPath: nil,
                    manifestPath: nil
                ),
            ]
        )
        try writeJSON(report, to: reportURL)

        let result = await DRCCLI.invoke(arguments: [
            "--audit-corpus-coverage", reportURL.path(percentEncoded: false),
            "--out", auditURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(result.exitCode == 2)
        #expect(result.standardError.isEmpty)
        let audit = try JSONDecoder().decode(DRCCorpusCoverageAudit.self, from: Data(contentsOf: auditURL))
        #expect(audit.validateIntegrity().isEmpty)
        #expect(audit.summary.caseCount == 1)
        #expect(audit.summary.durationBudgetPassedCaseCount == 1)
        #expect(audit.summary.durationBudgetPassRate == 1)
    }

    @Test func corpusToolEvidenceExportMatchesRuntimeEvidenceShape() throws {
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 2,
            matchedCaseCount: 2,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.25,
            summary: DRCCorpusSummary(
                expectationMatchedCaseCount: 2,
                durationBudgetPassedCaseCount: 2,
                primaryExecutionFailedCaseCount: 0,
                oracleCaseCount: 2,
                oracleAgreementPassedCaseCount: 2,
                oracleExecutionFailedCaseCount: 0,
                oracleReadinessBlockedCaseCount: 0,
                failureCategoryCounts: [:],
                passRate: 1,
                oracleAgreementRate: 1
            ),
            caseResults: []
        )

        let export = DRCCorpusToolEvidenceExport(
            reportPath: "/tmp/drc-corpus-report.json",
            reportSHA256: "abc123",
            report: report,
            evidenceID: "drc-release-corpus",
            checkedAt: Date(timeIntervalSince1970: 1_781_740_800)
        )

        #expect(export.status == "passed")
        #expect(export.toolEvidence.evidenceID == "drc-release-corpus")
        #expect(export.toolEvidence.kind == "corpus")
        #expect(export.toolEvidence.checkedAt == "2026-06-18T00:00:00Z")
        #expect(export.toolEvidence.artifact.kind == "report")
        #expect(export.toolEvidence.artifact.format == "JSON")
        #expect(export.toolEvidence.artifact.sha256 == "abc123")
        #expect(export.toolEvidence.qualification.qualified)
        #expect(export.toolEvidence.qualification.policyID == "strict")
        #expect(export.toolEvidence.qualification.observedMetrics["passRate"] == 1)
        #expect(export.toolEvidence.qualification.observedMetrics["durationBudgetPassRate"] == 1)
        #expect(export.toolEvidence.qualification.observedMetrics["oracleAgreementRate"] == 1)
        #expect(export.toolEvidence.qualification.observedCounts["caseCount"] == 2)
        #expect(export.toolEvidence.qualification.observedCounts["coverageTagCount"] == 0)
        #expect(export.toolEvidence.qualification.observedCounts["oracleReadinessBlockedCaseCount"] == 0)
        #expect(export.toolEvidence.qualification.observedCounts["requiredCoverageTagCount"] == 0)
        #expect(export.toolEvidence.qualification.observedCounts["coveredRequiredCoverageTagCount"] == 0)
        #expect(export.toolEvidence.qualification.failureCodes.isEmpty)
    }

    @Test func corpusEvidencePacketBuildsAgentDecisionMaterial() throws {
        let report = failingDRCCorpusReport()

        let packet = DRCCorpusEvidencePacketBuilder().build(
            report: report,
            reportPath: "/tmp/drc-corpus-report.json",
            reportSHA256: String(repeating: "a", count: 64),
            packetID: "drc-evidence-release"
        )

        #expect(packet.packetID == "drc-evidence-release")
        #expect(packet.domain == "drc.signoff-evidence")
        #expect(packet.inputs.first?.sha256 == String(repeating: "a", count: 64))
        #expect(packet.readiness.contains { $0.component == "drc-corpus-evidence" && $0.status == .ready })
        #expect(packet.readiness.contains { $0.component == "drc-oracle-comparison" && $0.status == .blocked })
        #expect(packet.metrics.contains { $0.metricID == "summary.pass-rate" && $0.value == 0 })
        #expect(packet.metrics.contains {
            $0.metricID == "case-spacing.actual-active-error-rule-count" && $0.count == 1
        })
        #expect(packet.diagnostics.contains { $0.category == "expectation_mismatch" })
        #expect(packet.diagnostics.contains { $0.category == "rule_set_mismatch" })
        #expect(packet.diagnostics.contains { $0.category == "oracle_readiness" })
        #expect(packet.diagnostics.contains { $0.category == "oracle_agreement" })
        #expect(packet.decisionHints.contains {
            $0.hintID == "drc:rule_set_mismatch"
                && $0.suggestedActions.contains("inspect_expected_rule_ids")
        })
        #expect(packet.confidence.level == .medium)
        #expect(packet.validateIntegrity().isEmpty)
    }

    @Test func evidencePacketIntegrityValidationReportsBrokenReferences() throws {
        let duplicateArtifactID = "artifact-a"
        let packet = DRCEvidencePacket(
            packetID: "packet-a",
            domain: "drc.signoff-evidence",
            subject: DRCEvidenceSubject(kind: "drc-corpus", identifier: "corpus-a"),
            intent: DRCEvidenceIntent(summary: "Validate packet integrity."),
            inputs: [
                DRCEvidenceArtifactRef(
                    artifactID: duplicateArtifactID,
                    path: " report.json ",
                    role: "evidence-source",
                    kind: "drc-corpus-report",
                    format: "JSON",
                    sha256: "abc"
                ),
            ],
            readiness: [
                DRCEvidenceReadiness(
                    component: "drc-corpus-evidence",
                    status: .ready,
                    reason: "ready",
                    artifactIDs: ["missing-artifact"]
                ),
            ],
            artifacts: [
                DRCEvidenceArtifactRef(
                    artifactID: duplicateArtifactID,
                    path: "../case/report.json",
                    role: "run-artifact",
                    kind: "drc-case-report",
                    format: "JSON"
                ),
            ],
            normalizedViews: [
                DRCEvidenceNormalizedView(
                    viewID: "summary",
                    kind: "summary",
                    scope: "corpus",
                    sourceArtifactIDs: ["missing-artifact"]
                ),
            ],
            metrics: [
                DRCEvidenceMetric(
                    metricID: "summary.pass-rate",
                    name: "passRate",
                    value: .infinity
                ),
            ],
            diagnostics: [
                DRCEvidenceDiagnostic(
                    diagnosticID: "diag-a",
                    severity: .error,
                    category: "artifact_integrity",
                    message: "broken",
                    artifactIDs: ["missing-artifact"]
                ),
            ],
            confidence: DRCEvidenceConfidence(
                level: .high,
                reason: "invalid",
                evidenceCount: -1,
                limitationCount: -1
            ),
            decisionHints: [
                DRCEvidenceDecisionHint(
                    hintID: "hint-a",
                    priority: .high,
                    summary: "hint",
                    diagnosticIDs: ["missing-diagnostic"]
                ),
            ]
        )

        let issues = packet.validateIntegrity()
        let codes = Set(issues.map(\.code))

        #expect(codes.contains("drc_evidence_duplicate_artifact_id"))
        #expect(codes.contains("drc_evidence_invalid_sha256"))
        #expect(codes.contains("drc_evidence_artifact_path_has_whitespace"))
        #expect(codes.contains("drc_evidence_artifact_path_has_relative_component"))
        #expect(codes.contains("drc_evidence_dangling_artifact_reference"))
        #expect(codes.contains("drc_evidence_non_finite_metric_value"))
        #expect(codes.contains("drc_evidence_dangling_diagnostic_reference"))
        #expect(codes.contains("drc_evidence_negative_confidence_evidence_count"))
        #expect(codes.contains("drc_evidence_negative_confidence_limitation_count"))
        #expect(issues.allSatisfy { !$0.fieldPath.isEmpty && !$0.suggestedActions.isEmpty })
    }

    @Test func corpusEvidencePacketQuarantinesArtifactPathsOutsideAllowedRoot() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let validReportURL = root.appending(path: "case-a/drc-report.json")
        let outsideManifestURL = root.deletingLastPathComponent().appending(path: "outside-manifest.json")
        let report = DRCCorpusReport(
            passed: true,
            caseCount: 1,
            matchedCaseCount: 1,
            caseResults: [
                DRCCorpusCaseResult(
                    caseID: "case-a",
                    matched: true,
                    expectedPassed: true,
                    actualPassed: true,
                    expectedActiveErrorRuleIDs: [],
                    actualActiveErrorRuleIDs: [],
                    expectationMatched: true,
                    durationSeconds: 0.01,
                    expectedMaxDurationSeconds: 1,
                    durationBudgetPassed: true,
                    failureReasons: [],
                    diagnosticSummary: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0),
                    reportPath: validReportURL.path(percentEncoded: false),
                    manifestPath: outsideManifestURL.path(percentEncoded: false)
                ),
            ]
        )

        let packet = DRCCorpusEvidencePacketBuilder().build(
            report: report,
            reportPath: root.appending(path: "drc-corpus-report.json").path(percentEncoded: false),
            packetID: "drc-evidence-root-check",
            allowedArtifactRootPath: root.path(percentEncoded: false)
        )

        #expect(packet.artifacts.map(\.artifactID) == ["case-a:reportPath"])
        #expect(packet.diagnostics.contains {
            $0.diagnosticID == "case-a:manifestPath-artifact-integrity"
                && $0.category == "artifact_integrity"
        })
        #expect(packet.readiness.contains {
            $0.component == "drc-evidence-artifacts" && $0.status == .blocked
        })
        #expect(packet.decisionHints.contains {
            $0.hintID == "drc:artifact_integrity" && $0.priority == .high
        })
        #expect(packet.confidence.level == .low)
    }

    @Test func corpusEvidencePacketUsesSafeNamespacesForUnsafeAndDuplicateCaseIDs() throws {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let caseIDs = ["case/one", "case one", "case/one"]
        let report = DRCCorpusReport(
            passed: true,
            caseCount: caseIDs.count,
            matchedCaseCount: caseIDs.count,
            caseResults: caseIDs.enumerated().map { index, caseID in
                DRCCorpusCaseResult(
                    caseID: caseID,
                    matched: true,
                    expectedPassed: true,
                    actualPassed: true,
                    expectedActiveErrorRuleIDs: [],
                    actualActiveErrorRuleIDs: [],
                    expectationMatched: true,
                    durationSeconds: Double(index + 1) / 100,
                    expectedMaxDurationSeconds: 1,
                    durationBudgetPassed: true,
                    failureReasons: [],
                    diagnosticSummary: summary,
                    reportPath: nil,
                    manifestPath: nil
                )
            }
        )

        let packet = DRCCorpusEvidencePacketBuilder().build(
            report: report,
            reportPath: "/tmp/drc-corpus-report.json",
            packetID: "drc-evidence-case-id-check"
        )
        let durationMetricIDs = packet.metrics
            .filter { $0.name == "durationSeconds" }
            .map(\.metricID)
        let diagnosticIDs = packet.diagnostics.map(\.diagnosticID)

        #expect(durationMetricIDs == [
            "case-one.duration-seconds",
            "case-one-2.duration-seconds",
            "case-one-3.duration-seconds",
        ])
        #expect(Set(durationMetricIDs).count == durationMetricIDs.count)
        #expect(Set(diagnosticIDs).count == diagnosticIDs.count)
        #expect(packet.diagnostics.contains {
            $0.diagnosticID == "case-one:case-id-unsafe"
                && $0.category == "artifact_integrity"
        })
        #expect(packet.diagnostics.contains {
            $0.diagnosticID == "case-one-2:case-id-namespace-collision"
                && $0.category == "artifact_integrity"
        })
        #expect(packet.diagnostics.contains {
            $0.diagnosticID == "case-one-3:case-id-duplicate"
                && $0.category == "artifact_integrity"
        })
    }

    @Test func evidencePacketCLIExportsFailedCorpusAsDecisionMaterial() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let reportURL = root.appending(path: "drc-corpus-report.json")
        let packetURL = root.appending(path: "drc-evidence-packet.json")
        try writeJSON(failingDRCCorpusReport(), to: reportURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--evidence-packet-from-corpus-report", reportURL.path(percentEncoded: false),
            "--out", packetURL.path(percentEncoded: false),
            "--packet-id", "drc-evidence-release",
        ])

        #expect(exitCode == 0)
        let packet = try JSONDecoder().decode(
            DRCEvidencePacket.self,
            from: Data(contentsOf: packetURL)
        )
        #expect(packet.packetID == "drc-evidence-release")
        #expect(packet.diagnostics.contains { $0.category == "rule_set_mismatch" })
        #expect(packet.decisionHints.contains { $0.hintID == "drc:oracle_readiness" })
        #expect(packet.validateIntegrity().isEmpty)
    }

    @Test func corpusEvidenceCLIUsesQualificationForExitStatus() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = fixtureCorpusSpecURL("drc-corpus-tight-budget.json")

        let corpusExitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])
        #expect(corpusExitCode == 2)

        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let evidenceExitCode = await DRCCLI.run(arguments: [
            "--evidence-from-corpus-report", reportURL.path(percentEncoded: false),
            "--checked-at", "2026-06-18T00:00:00Z",
            "--json",
        ])

        #expect(evidenceExitCode == 2)
    }

    private func date(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try #require(formatter.date(from: string))
    }
}
