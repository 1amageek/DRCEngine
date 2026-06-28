import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    @Test func corpusCLIRunsCasesAndWritesReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = fixtureCorpusSpecURL("drc-corpus.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        #expect(report.passed)
        #expect(report.caseCount == 35)
        #expect(report.matchedCaseCount == 35)
        #expect(report.budgetExceededCaseCount == 0)
        #expect(report.totalDurationSeconds >= 0)
        #expect(report.summary.passRate == 1)
        #expect(report.summary.oracleCaseCount == 35)
        #expect(report.summary.oracleAgreementPassedCaseCount == 35)
        #expect(report.summary.oracleAgreementRate == 1)
        #expect(report.summary.primaryExecutionFailedCaseCount == 0)
        #expect(report.summary.oracleExecutionFailedCaseCount == 0)
        #expect(report.summary.oracleReadinessBlockedCaseCount == 0)
        #expect(report.summary.failureCategoryCounts.isEmpty)
        #expect(report.summary.coverageTagCounts["drc.antenna"] == 4)
        #expect(report.summary.coverageTagCounts["drc.antenna.multi-layer"] == 1)
        #expect(report.summary.coverageTagCounts["drc.antenna.process-step"] == 1)
        #expect(report.summary.coverageTagCounts["drc.antenna.via-aware"] == 2)
        #expect(report.summary.coverageTagCounts["drc.antenna.via-topology"] == 1)
        #expect(report.summary.coverageTagCounts["drc.area"] == 1)
        #expect(report.summary.coverageTagCounts["drc.clean"] == 1)
        #expect(report.summary.coverageTagCounts["drc.cut"] == 6)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum"] == 6)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum.fail"] == 3)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum.multi-stack"] == 2)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum.pass"] == 3)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum.standard-input"] == 2)
        #expect(report.summary.coverageTagCounts["drc.density"] == 2)
        #expect(report.summary.coverageTagCounts["drc.density.maximum"] == 1)
        #expect(report.summary.coverageTagCounts["drc.density.minimum"] == 1)
        #expect(report.summary.coverageTagCounts["drc.enclosed-area"] == 1)
        #expect(report.summary.coverageTagCounts["drc.extension"] == 1)
        #expect(report.summary.coverageTagCounts["drc.extension.minimum"] == 1)
        #expect(report.summary.coverageTagCounts["drc.grid"] == 1)
        #expect(report.summary.coverageTagCounts["drc.grid.manufacturing"] == 1)
        #expect(report.summary.coverageTagCounts["drc.input.gds"] == 3)
        #expect(report.summary.coverageTagCounts["drc.input.oasis"] == 1)
        #expect(report.summary.coverageTagCounts["drc.input.cif"] == 1)
        #expect(report.summary.coverageTagCounts["drc.input.dxf"] == 1)
        #expect(report.summary.coverageTagCounts["drc.notch"] == 1)
        #expect(report.summary.coverageTagCounts["drc.overlap"] == 3)
        #expect(report.summary.coverageTagCounts["drc.overlap.different-net"] == 1)
        #expect(report.summary.coverageTagCounts["drc.overlap.exact"] == 1)
        #expect(report.summary.coverageTagCounts["drc.overlap.forbidden"] == 1)
        #expect(report.summary.coverageTagCounts["drc.short"] == 1)
        #expect(report.summary.coverageTagCounts["drc.width"] == 2)
        #expect(report.summary.coverageTagCounts["drc.spacing"] == 7)
        #expect(report.summary.coverageTagCounts["drc.spacing.different-net"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.directional"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.end-of-line"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.layer-pair"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.net-scope"] == 2)
        #expect(report.summary.coverageTagCounts["drc.spacing.parallel-run-length"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.same-net"] == 1)
        #expect(report.summary.coverageTagCounts["drc.spacing.wide"] == 1)
        #expect(report.summary.coverageTagCounts["drc.tech.layer-map"] == 6)
        #expect(report.summary.coverageTagCounts["drc.enclosure"] == 1)
        #expect(report.summary.coverageTagCounts["drc.waiver"] == 1)
        #expect(report.qualification.qualified)
        #expect(report.qualification.policy.requiredCoverageTags == [
            "drc.antenna",
            "drc.antenna.multi-layer",
            "drc.antenna.process-step",
            "drc.antenna.via-aware",
            "drc.antenna.via-topology",
            "drc.area",
            "drc.clean",
            "drc.cut",
            "drc.cut.minimum",
            "drc.cut.minimum.fail",
            "drc.cut.minimum.multi-stack",
            "drc.cut.minimum.pass",
            "drc.cut.minimum.standard-input",
            "drc.density",
            "drc.density.minimum",
            "drc.enclosed-area",
            "drc.enclosure",
            "drc.extension",
            "drc.extension.minimum",
            "drc.grid",
            "drc.grid.manufacturing",
            "drc.input.cif",
            "drc.input.dxf",
            "drc.input.gds",
            "drc.input.oasis",
            "drc.notch",
            "drc.overlap",
            "drc.overlap.different-net",
            "drc.overlap.exact",
            "drc.overlap.forbidden",
            "drc.short",
            "drc.spacing",
            "drc.spacing.different-net",
            "drc.spacing.directional",
            "drc.spacing.end-of-line",
            "drc.spacing.layer-pair",
            "drc.spacing.net-scope",
            "drc.spacing.parallel-run-length",
            "drc.spacing.same-net",
            "drc.spacing.wide",
            "drc.tech.layer-map",
            "drc.waiver",
            "drc.width",
        ])
        #expect(report.qualification.failures.isEmpty)
        #expect(report.caseResults.allSatisfy { $0.durationBudgetPassed })
        #expect(report.caseResults.allSatisfy { $0.expectedMaxDurationSeconds == 10 })
        #expect(report.caseResults.allSatisfy { $0.failureReasons.isEmpty })
        #expect(report.caseResults.allSatisfy { !$0.coverageTags.isEmpty })
        #expect(Set(report.caseResults.compactMap { $0.oracleResult?.backendID }) == ["native", "native-gds"])
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.agreementPassed == true })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.readinessStatus == .ready })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.readinessDiagnostics.isEmpty == true })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.reportPath != nil })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.manifestPath != nil })
        #expect(report.caseResults.allSatisfy { $0.primaryProvenance != nil })
        #expect(report.caseResults.allSatisfy {
            $0.primaryProvenance?.inputArtifacts.contains { $0.id == "input-layout" && $0.kind == .layout } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.primaryProvenance?.outputArtifacts.contains { $0.id == "report" && $0.kind == .report } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.primaryProvenance?.outputArtifacts.contains { $0.id == "manifest" && $0.kind == .manifest } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.oracleResult?.provenance?.inputArtifacts.contains { $0.id == "input-layout" && $0.kind == .layout } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.oracleResult?.provenance?.outputArtifacts.contains { $0.id == "report" && $0.kind == .report } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.oracleComparison?.agreementPassed == true
                && $0.oracleComparison?.mismatchReasons.isEmpty == true
        })
        #expect(report.caseResults.contains {
            $0.caseID == "manufacturing-grid-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.grid"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-gds-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.input.gds")
                && $0.coverageTags.contains("drc.tech.layer-map")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-oasis-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.input.oasis")
                && $0.coverageTags.contains("drc.tech.layer-map")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-cif-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.input.cif")
                && $0.coverageTags.contains("drc.tech.layer-map")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-dxf-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.input.dxf")
                && $0.coverageTags.contains("drc.tech.layer-map")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "width-violation" && $0.actualActiveErrorRuleIDs == ["met1.width"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "area-violation" && $0.actualActiveErrorRuleIDs == ["met1.area"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "antenna-violation" && $0.actualActiveErrorRuleIDs == ["met2.antenna"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "antenna-process-step-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.antenna.processStep"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "antenna-via-aware-violation"
                && $0.actualActiveErrorRuleIDs == ["met2.antenna.viaAware"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "antenna-via-aware-disconnected"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
        })
        #expect(report.caseResults.contains {
            $0.caseID == "density-violation" && $0.actualActiveErrorRuleIDs == ["met1.density"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-cut-violation"
                && $0.actualActiveErrorRuleIDs == ["via1.minimumCut"]
                && $0.coverageTags.contains("drc.cut.minimum.fail")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-cut-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.cut.minimum.pass")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-cut-multistack-violation"
                && $0.actualActiveErrorRuleIDs == ["via1.minimumCut"]
                && $0.coverageTags.contains("drc.cut.minimum.multi-stack")
                && $0.coverageTags.contains("drc.cut.minimum.fail")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-cut-multistack-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.cut.minimum.multi-stack")
                && $0.coverageTags.contains("drc.cut.minimum.pass")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-gds-minimum-cut-violation"
                && $0.actualActiveErrorRuleIDs == ["minimumCut.VIA1.cut.M1.drawing.M2.drawing.via1.minimumCut"]
                && $0.coverageTags.contains("drc.cut.minimum.standard-input")
                && $0.coverageTags.contains("drc.input.gds")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-gds-minimum-cut-clean"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.coverageTags.contains("drc.cut.minimum.standard-input")
                && $0.coverageTags.contains("drc.input.gds")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-density-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.minimumDensity"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "notch-violation" && $0.actualActiveErrorRuleIDs == ["met1.notch"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "forbidden-overlap-violation"
                && $0.actualActiveErrorRuleIDs == ["active.nwell.forbiddenOverlap"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "different-net-overlap-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.short"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "exact-overlap-violation"
                && $0.actualActiveErrorRuleIDs == ["via1.marker.exactOverlap"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-violation" && $0.actualActiveErrorRuleIDs == ["met1.spacing"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-different-net-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.spacingDifferentNet"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-same-net-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.spacingSameNet"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-layer-pair-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.via1.spacing"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-end-of-line-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.eol"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-prl-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.spacing.prl"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "spacing-wide-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.wideSpacing"]
                && $0.coverageTags.contains("drc.spacing.wide")
        })
        #expect(report.caseResults.contains {
            $0.caseID == "enclosure-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.via1.enclosure"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "minimum-extension-violation"
                && $0.actualActiveErrorRuleIDs == ["poly.active.extension"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "enclosed-area-violation"
                && $0.actualActiveErrorRuleIDs == ["met1.enclosedArea"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "waived-width-violation"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
                && $0.diagnosticSummary.waivedErrorCount == 1
        })
        #expect(report.caseResults.allSatisfy { $0.reportPath != nil && $0.manifestPath != nil })
    }

    @Test func cutCountMagicReadinessCorpusRecordsBlockedOracle() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "cut-count-magic-readiness-output")
        let specURL = fixtureExternalOracleSpecURL("drc-cut-count-magic-readiness-corpus.json")
        let spec = try JSONDecoder().decode(DRCCorpusSpec.self, from: Data(contentsOf: specURL))
        #expect(spec.cases.count == 2)
        #expect(Set(spec.cases.compactMap(\.oracleBackendID)) == ["magic"])

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--oracle-backend", "missing-magic-oracle",
            "--json",
        ])

        #expect(exitCode == 2)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        #expect(report.caseCount == 2)
        #expect(report.summary.coverageTagCounts["drc.cut.minimum.external-oracle"] == 2)
        #expect(report.summary.coverageTagCounts["external.magic"] == 2)
        #expect(report.summary.coverageTagCounts["layout.gds"] == 2)
        #expect(report.summary.oracleCaseCount == 2)
        #expect(report.summary.oracleReadinessBlockedCaseCount == 2)
        #expect(report.summary.oracleExecutionFailedCaseCount == 2)
        #expect(report.summary.failureCategoryCounts["oracle_execution_failed"] == 2)
        #expect(report.summary.failureCategoryCounts["oracle_agreement_mismatch"] == 2)
        #expect(report.summary.failureCategoryCounts["passed_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["active_error_rule_ids_mismatch"] == 1)
        #expect(report.summary.failureCategoryCounts["diagnostic_summary_mismatch"] == 1)
        #expect(report.caseResults.allSatisfy { $0.expectationMatched })
        #expect(report.caseResults.allSatisfy { $0.primaryProvenance != nil })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.backendID == "missing-magic-oracle" })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.readinessStatus == .blocked })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.provenance == nil })
        #expect(report.caseResults.allSatisfy { $0.oracleComparison != nil })
        #expect(report.caseResults.allSatisfy {
            $0.oracleComparison?.mismatchReasons.contains {
                $0.hasPrefix("oracle_execution_failed:")
            } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.oracleResult?.readinessDiagnostics.contains {
                $0.contains("Unsupported DRC backend: missing-magic-oracle")
            } == true
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-gds-minimum-cut-violation-magic-readiness"
                && $0.actualActiveErrorRuleIDs == ["minimumCut.VIA1.cut.M1.drawing.M2.drawing.via1.minimumCut"]
        })
        #expect(report.caseResults.contains {
            $0.caseID == "standard-gds-minimum-cut-clean-magic-readiness"
                && $0.actualPassed
                && $0.actualActiveErrorRuleIDs.isEmpty
        })
    }

    @Test func corpusCLIOverridesOracleBackendForQualificationLane() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = fixtureCorpusSpecURL("drc-corpus.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--oracle-backend", "missing-oracle",
            "--json",
        ])

        #expect(exitCode == 2)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        let expectedOracleCaseCount = report.caseResults.count
        #expect(report.runOptions.oracleBackendIDOverride == "missing-oracle")
        #expect(report.summary.oracleCaseCount == expectedOracleCaseCount)
        #expect(report.summary.oracleExecutionFailedCaseCount == expectedOracleCaseCount)
        #expect(report.summary.oracleReadinessBlockedCaseCount == expectedOracleCaseCount)
        #expect(report.summary.failureCategoryCounts["oracle_execution_failed"] == expectedOracleCaseCount)
        #expect(report.summary.failureCategoryCounts["oracle_agreement_mismatch"] == expectedOracleCaseCount)
        #expect((report.summary.failureCategoryCounts["passed_mismatch"] ?? 0) > 0)
        #expect((report.summary.failureCategoryCounts["active_error_rule_ids_mismatch"] ?? 0) > 0)
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.backendID == "missing-oracle" })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.agreementPassed == false })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.readinessStatus == .blocked })
        #expect(report.caseResults.allSatisfy { $0.primaryProvenance != nil })
        #expect(report.caseResults.allSatisfy { $0.oracleResult?.provenance == nil })
        #expect(report.caseResults.allSatisfy { $0.oracleComparison != nil })
        #expect(report.caseResults.allSatisfy {
            $0.oracleComparison?.mismatchReasons.contains {
                $0.hasPrefix("oracle_execution_failed:")
            } == true
        })
        #expect(report.caseResults.allSatisfy {
            $0.oracleResult?.readinessDiagnostics.contains {
                $0.contains("Unsupported DRC backend: missing-oracle")
            } == true
        })
        #expect(report.qualification.failures.map(\.code).contains("oracle_execution_failed"))
    }

    @Test func corpusCLIFailsWhenDurationBudgetIsExceeded() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = fixtureCorpusSpecURL("drc-corpus-tight-budget.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 2)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        #expect(!report.passed)
        #expect(report.caseCount == 1)
        #expect(report.matchedCaseCount == 0)
        #expect(report.budgetExceededCaseCount == 1)
        #expect(report.summary.passRate == 0)
        #expect(report.summary.failureCategoryCounts["duration_exceeded"] == 1)
        #expect(report.summary.oracleCaseCount == 0)
        #expect(!report.qualification.qualified)
        let failureCodes = Set(report.qualification.failures.map(\.code))
        #expect(failureCodes.contains("corpus_not_passed"))
        #expect(failureCodes.contains("pass_rate_below_minimum"))
        #expect(failureCodes.contains("duration_budget_pass_rate_below_minimum"))
        let result = try #require(report.caseResults.first)
        #expect(result.expectationMatched)
        #expect(!result.durationBudgetPassed)
        #expect(result.failureReasons.contains { $0.hasPrefix("duration_exceeded:") })
    }

    @Test func corpusCLIUsesQualificationPolicyForExitStatus() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = root.appending(path: "threshold-corpus.json")
        try writeJSON(DRCCorpusSpec(
            defaultMaxDurationSeconds: 0.000000000001,
            qualificationPolicy: DRCCorpusQualificationPolicy(
                requireCorpusPassed: false,
                minimumPassRate: 0,
                minimumDurationBudgetPassRate: 0
            ),
            cases: [
                DRCCorpusCase(
                    caseID: "clean-threshold",
                    layoutPath: fixtureCorpusSpecURL("clean.json").path(percentEncoded: false),
                    topCell: "inv",
                    backendID: "native",
                    expectedPassed: true
                ),
            ]
        ), to: specURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        #expect(!report.passed)
        #expect(report.summary.failureCategoryCounts["duration_exceeded"] == 1)
        #expect(report.qualification.qualified)
        #expect(!report.qualification.policy.requireCorpusPassed)
        #expect(report.qualification.policy.minimumDurationBudgetPassRate == 0)
    }

    @Test func corpusCLIRequiresCoverageTagsForQualification() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let specURL = root.appending(path: "coverage-corpus.json")
        try writeJSON(DRCCorpusSpec(
            qualificationPolicy: DRCCorpusQualificationPolicy(
                requiredCoverageTags: ["drc.clean", "drc.spacing"]
            ),
            cases: [
                DRCCorpusCase(
                    caseID: "clean-coverage",
                    layoutPath: fixtureCorpusSpecURL("clean.json").path(percentEncoded: false),
                    topCell: "inv",
                    backendID: "native",
                    expectedPassed: true,
                    coverageTags: ["drc.clean"]
                ),
            ]
        ), to: specURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 2)
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let report = try JSONDecoder().decode(DRCCorpusReport.self, from: Data(contentsOf: reportURL))
        #expect(report.passed)
        #expect(report.summary.coverageTagCounts == ["drc.clean": 1])
        let failure = try #require(report.qualification.failures.first { $0.code == "required_coverage_missing" })
        #expect(failure.observedCount == 1)
        #expect(failure.requiredCount == 2)
        #expect(failure.observedText == "drc.clean")
        #expect(failure.requiredText == "drc.spacing")
    }

    @Test func corpusReportQualificationCLIRechecksSavedReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let outputDirectory = root.appending(path: "corpus-output")
        let policyURL = root.appending(path: "permissive-policy.json")
        let specURL = fixtureCorpusSpecURL("drc-corpus-tight-budget.json")

        let corpusExitCode = await DRCCLI.run(arguments: [
            "--corpus", specURL.path(percentEncoded: false),
            "--out", outputDirectory.path(percentEncoded: false),
            "--json",
        ])
        #expect(corpusExitCode == 2)

        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let embeddedExitCode = await DRCCLI.run(arguments: [
            "--qualify-corpus-report", reportURL.path(percentEncoded: false),
            "--json",
        ])
        #expect(embeddedExitCode == 2)

        try writeJSON(DRCCorpusQualificationPolicy(
            requireCorpusPassed: false,
            minimumPassRate: 0,
            minimumDurationBudgetPassRate: 0
        ), to: policyURL)

        let overriddenExitCode = await DRCCLI.run(arguments: [
            "--qualify-corpus-report", reportURL.path(percentEncoded: false),
            "--qualification-policy", policyURL.path(percentEncoded: false),
            "--json",
        ])
        #expect(overriddenExitCode == 0)
    }
}
