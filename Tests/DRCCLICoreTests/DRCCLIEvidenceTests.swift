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

    @Test func corpusCoverageAuditOptionsParsePolicyOutputAndAuditID() throws {
        let options = try DRCCorpusCoverageAuditCLIOptions(arguments: [
            "--audit-corpus-coverage", "/tmp/drc-corpus-report.json",
            "--include-corpus-report", "/tmp/drc-magic-corpus-report.json",
            "--coverage-policy", "/tmp/drc-coverage-policy.json",
            "--out", "/tmp/drc-corpus-coverage-audit.json",
            "--audit-id", "drc-magic-expansion",
            "--json",
        ])

        #expect(options.reportURL.path(percentEncoded: false) == "/tmp/drc-corpus-report.json")
        #expect(options.includedReportURLs.map { $0.path(percentEncoded: false) } == [
            "/tmp/drc-magic-corpus-report.json",
        ])
        #expect(options.policyURL?.path(percentEncoded: false) == "/tmp/drc-coverage-policy.json")
        #expect(options.outputURL?.path(percentEncoded: false) == "/tmp/drc-corpus-coverage-audit.json")
        #expect(options.auditID == "drc-magic-expansion")
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
    }

    @Test func corpusCoverageAuditCLIIncludesMagicExternalReportForDefaultPolicy() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let nativeReportURL = root.appending(path: "drc-native-corpus-report.json")
        let magicReportURL = root.appending(path: "drc-magic-corpus-report.json")
        let auditURL = root.appending(path: "drc-corpus-coverage-audit.json")
        try writeJSON(nativeGDSAuditCorpusReport(), to: nativeReportURL)
        try writeJSON(magicFoundryAuditCorpusReport(), to: magicReportURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--audit-corpus-coverage", nativeReportURL.path(percentEncoded: false),
            "--include-corpus-report", magicReportURL.path(percentEncoded: false),
            "--out", auditURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let audit = try JSONDecoder().decode(DRCCorpusCoverageAudit.self, from: Data(contentsOf: auditURL))
        #expect(audit.status == .satisfied)
        #expect(audit.policyID == "drc.magic-foundry-expansion.v1")
        #expect(audit.summary.caseCount == 90)
        #expect(audit.summary.oracleCaseCount == 90)
        #expect(audit.summary.missingRequirementCount == 0)
        #expect(audit.summary.satisfiedRequirementCount == audit.summary.requiredRequirementCount)
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
            reportSHA256: "abc123",
            packetID: "drc-evidence-release"
        )

        #expect(packet.packetID == "drc-evidence-release")
        #expect(packet.domain == "drc.signoff-evidence")
        #expect(packet.inputs.first?.sha256 == "abc123")
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
}
