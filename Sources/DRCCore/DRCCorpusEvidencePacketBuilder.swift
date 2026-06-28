import Foundation

public struct DRCCorpusEvidencePacketBuilder: Sendable {
    public init() {}

    public func build(
        report: DRCCorpusReport,
        reportPath: String,
        reportSHA256: String? = nil,
        packetID: String? = nil
    ) -> DRCEvidencePacket {
        let inputs = inputRefs(reportPath: reportPath, reportSHA256: reportSHA256)
        let artifacts = artifactRefs(report: report)
        let diagnostics = diagnostics(report: report, artifactRefs: inputs + artifacts)
        return DRCEvidencePacket(
            packetID: packetID ?? defaultPacketID(reportPath: reportPath),
            domain: "drc.signoff-evidence",
            subject: DRCEvidenceSubject(
                kind: "drc-corpus",
                identifier: reportPath,
                backendID: report.runOptions.oracleBackendIDOverride
            ),
            intent: DRCEvidenceIntent(
                summary: "Expose retained DRC corpus observations as decision material.",
                designContext: "DRC corpus qualification with rule-ID expectations, oracle comparison, coverage, and runtime gates.",
                requestedObservations: [
                    "corpus-readiness",
                    "qualification-gates",
                    "rule-id-expectations",
                    "oracle-agreement",
                    "coverage-tags",
                    "duration-budget",
                    "repair-planning-diagnostics",
                ]
            ),
            inputs: inputs,
            readiness: readiness(report: report, reportArtifactID: inputs.first?.artifactID),
            artifacts: artifacts,
            normalizedViews: normalizedViews(report: report, artifactRefs: inputs + artifacts),
            metrics: metrics(report: report),
            diagnostics: diagnostics,
            confidence: confidence(report: report, diagnostics: diagnostics),
            decisionHints: decisionHints(diagnostics: diagnostics, report: report),
            coverageTags: report.summary.coverageTagCounts.keys.sorted(),
            relatedEvidenceIDs: ["drc-corpus:\(URL(filePath: reportPath).deletingPathExtension().lastPathComponent)"]
        )
    }

    private func defaultPacketID(reportPath: String) -> String {
        let filename = URL(filePath: reportPath).deletingPathExtension().lastPathComponent
        return filename.isEmpty ? "drc-evidence-packet:corpus" : "drc-evidence-packet:corpus:\(filename)"
    }

    private func inputRefs(reportPath: String, reportSHA256: String?) -> [DRCEvidenceArtifactRef] {
        [
            DRCEvidenceArtifactRef(
                artifactID: "drc-corpus-report",
                path: reportPath,
                role: "evidence-source",
                kind: "drc-corpus-report",
                format: "JSON",
                sha256: reportSHA256
            )
        ]
    }

    private func artifactRefs(report: DRCCorpusReport) -> [DRCEvidenceArtifactRef] {
        var refs: [DRCEvidenceArtifactRef] = []
        for result in report.caseResults {
            appendCaseRef(
                &refs,
                path: result.reportPath,
                caseID: result.caseID,
                role: "run-artifact",
                kind: "drc-case-report",
                format: "JSON",
                sourceField: "reportPath"
            )
            appendCaseRef(
                &refs,
                path: result.manifestPath,
                caseID: result.caseID,
                role: "run-artifact",
                kind: "drc-artifact-manifest",
                format: "JSON",
                sourceField: "manifestPath"
            )
            appendCaseRef(
                &refs,
                path: result.oracleResult?.reportPath,
                caseID: result.caseID,
                role: "oracle-artifact",
                kind: "drc-oracle-report",
                format: "JSON",
                sourceField: "oracleReportPath"
            )
            appendCaseRef(
                &refs,
                path: result.oracleResult?.manifestPath,
                caseID: result.caseID,
                role: "oracle-artifact",
                kind: "drc-oracle-artifact-manifest",
                format: "JSON",
                sourceField: "oracleManifestPath"
            )
        }
        return refs
    }

    private func appendCaseRef(
        _ refs: inout [DRCEvidenceArtifactRef],
        path: String?,
        caseID: String,
        role: String,
        kind: String,
        format: String,
        sourceField: String
    ) {
        guard let path, !path.isEmpty else { return }
        refs.append(DRCEvidenceArtifactRef(
            artifactID: "\(caseID):\(sourceField)",
            path: path,
            role: role,
            kind: kind,
            format: format,
            caseID: caseID
        ))
    }

    private func readiness(report: DRCCorpusReport, reportArtifactID: String?) -> [DRCEvidenceReadiness] {
        let caseCount = report.caseCount
        if caseCount == 0 {
            return [
                DRCEvidenceReadiness(
                    component: "drc-corpus-evidence",
                    status: .unknown,
                    reason: "The corpus report contains no cases.",
                    artifactIDs: [reportArtifactID].compactMap { $0 },
                    suggestedActions: ["add_drc_corpus_cases"]
                )
            ]
        }
        if report.summary.primaryExecutionFailedCaseCount == caseCount {
            return [
                DRCEvidenceReadiness(
                    component: "drc-corpus-evidence",
                    status: .blocked,
                    reason: "Every primary DRC corpus case failed before usable diagnostics were produced.",
                    artifactIDs: [reportArtifactID].compactMap { $0 },
                    suggestedActions: [
                        "inspect_drc_backend_logs",
                        "verify_drc_inputs_and_pdk_profile",
                    ]
                )
            ]
        }
        var values = [
            DRCEvidenceReadiness(
                component: "drc-corpus-evidence",
                status: .ready,
                reason: "At least one retained DRC corpus case produced usable signoff evidence.",
                artifactIDs: [reportArtifactID].compactMap { $0 }
            )
        ]
        if report.summary.oracleCaseCount > 0 {
            values.append(DRCEvidenceReadiness(
                component: "drc-oracle-comparison",
                status: report.summary.oracleReadinessBlockedCaseCount == 0 ? .ready : .blocked,
                reason: report.summary.oracleReadinessBlockedCaseCount == 0
                    ? "Oracle comparison evidence is available."
                    : "One or more oracle comparison cases were blocked before agreement could be evaluated.",
                suggestedActions: report.summary.oracleReadinessBlockedCaseCount == 0
                    ? []
                    : ["inspect_oracle_backend_readiness", "inspect_oracle_backend_logs"]
            ))
        } else {
            values.append(DRCEvidenceReadiness(
                component: "drc-oracle-comparison",
                status: .unknown,
                reason: "No oracle comparison cases are present in this corpus report.",
                suggestedActions: ["run_drc_corpus_with_oracle_backend_when_benchmarking"]
            ))
        }
        return values
    }

    private func normalizedViews(
        report: DRCCorpusReport,
        artifactRefs: [DRCEvidenceArtifactRef]
    ) -> [DRCEvidenceNormalizedView] {
        [
            DRCEvidenceNormalizedView(
                viewID: "drc-corpus-summary",
                kind: "signoff-corpus-summary",
                scope: "drc-corpus",
                summaryMetrics: summaryMetrics(report),
                summaryCounts: summaryCounts(report),
                sourceArtifactIDs: artifactRefs.map(\.artifactID)
            )
        ]
    }

    private func metrics(report: DRCCorpusReport) -> [DRCEvidenceMetric] {
        var values: [DRCEvidenceMetric] = [
            DRCEvidenceMetric(metricID: "summary.pass-rate", name: "passRate", value: report.summary.passRate),
            DRCEvidenceMetric(
                metricID: "summary.duration-budget-pass-rate",
                name: "durationBudgetPassRate",
                value: durationBudgetPassRate(report)
            ),
            DRCEvidenceMetric(
                metricID: "summary.total-duration-seconds",
                name: "totalDurationSeconds",
                value: report.totalDurationSeconds,
                unit: "s"
            ),
            DRCEvidenceMetric(metricID: "summary.case-count", name: "caseCount", count: report.caseCount),
            DRCEvidenceMetric(
                metricID: "summary.matched-case-count",
                name: "matchedCaseCount",
                count: report.matchedCaseCount
            ),
            DRCEvidenceMetric(
                metricID: "summary.budget-exceeded-case-count",
                name: "budgetExceededCaseCount",
                count: report.budgetExceededCaseCount
            ),
        ]
        if let oracleAgreementRate = report.summary.oracleAgreementRate {
            values.append(DRCEvidenceMetric(
                metricID: "summary.oracle-agreement-rate",
                name: "oracleAgreementRate",
                value: oracleAgreementRate
            ))
        }
        for result in report.caseResults {
            values.append(contentsOf: caseMetrics(result))
        }
        return values
    }

    private func caseMetrics(_ result: DRCCorpusCaseResult) -> [DRCEvidenceMetric] {
        [
            DRCEvidenceMetric(
                metricID: "\(result.caseID).duration-seconds",
                name: "durationSeconds",
                value: result.durationSeconds,
                unit: "s",
                caseID: result.caseID
            ),
            DRCEvidenceMetric(
                metricID: "\(result.caseID).expected-active-error-rule-count",
                name: "expectedActiveErrorRuleCount",
                count: result.expectedActiveErrorRuleIDs.count,
                caseID: result.caseID
            ),
            DRCEvidenceMetric(
                metricID: "\(result.caseID).actual-active-error-rule-count",
                name: "actualActiveErrorRuleCount",
                count: result.actualActiveErrorRuleIDs.count,
                caseID: result.caseID
            ),
            DRCEvidenceMetric(
                metricID: "\(result.caseID).error-count",
                name: "errorCount",
                count: result.diagnosticSummary.errorCount,
                caseID: result.caseID
            ),
            DRCEvidenceMetric(
                metricID: "\(result.caseID).waived-error-count",
                name: "waivedErrorCount",
                count: result.diagnosticSummary.waivedErrorCount,
                caseID: result.caseID
            ),
        ]
    }

    private func diagnostics(
        report: DRCCorpusReport,
        artifactRefs: [DRCEvidenceArtifactRef]
    ) -> [DRCEvidenceDiagnostic] {
        var values: [DRCEvidenceDiagnostic] = []
        for failure in report.qualification.failures {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "qualification:\(failure.code)",
                severity: .error,
                category: category(qualificationCode: failure.code),
                message: failure.message,
                observedValue: failure.observedDouble,
                requiredValue: failure.requiredDouble,
                artifactIDs: ["drc-corpus-report"],
                suggestedActions: suggestedActions(category: category(qualificationCode: failure.code))
            ))
        }
        for result in report.caseResults {
            let caseArtifacts = artifactRefs.filter { $0.caseID == result.caseID }.map(\.artifactID)
            appendCaseDiagnostics(&values, result: result, artifactIDs: caseArtifacts)
        }
        return values
    }

    private func appendCaseDiagnostics(
        _ values: inout [DRCEvidenceDiagnostic],
        result: DRCCorpusCaseResult,
        artifactIDs: [String]
    ) {
        if let executionError = result.executionError {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):primary-execution",
                severity: .error,
                category: "primary_execution",
                message: executionError,
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "primary_execution")
            ))
        }
        if !result.expectationMatched {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):expectation-mismatch",
                severity: .error,
                category: "expectation_mismatch",
                message: "Expected DRC pass state or active rule IDs did not match observed native DRC output.",
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "expectation_mismatch")
            ))
        }
        if !result.durationBudgetPassed {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):duration-budget",
                severity: .warning,
                category: "duration_budget",
                message: "The DRC case exceeded its expected duration budget.",
                caseID: result.caseID,
                observedValue: result.durationSeconds,
                requiredValue: result.expectedMaxDurationSeconds,
                unit: "s",
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "duration_budget")
            ))
        }
        for (index, reason) in result.failureReasons.enumerated() {
            let category = category(failureReason: reason)
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):failure:\(index)",
                severity: .error,
                category: category,
                message: reason,
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: category)
            ))
        }
        if let oracle = result.oracleResult {
            appendOracleDiagnostics(&values, result: result, oracle: oracle, artifactIDs: artifactIDs)
        }
    }

    private func appendOracleDiagnostics(
        _ values: inout [DRCEvidenceDiagnostic],
        result: DRCCorpusCaseResult,
        oracle: DRCCorpusOracleResult,
        artifactIDs: [String]
    ) {
        if oracle.readinessStatus == .blocked {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):oracle-readiness",
                severity: .error,
                category: "oracle_readiness",
                message: oracle.readinessDiagnostics.joined(separator: "; "),
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_readiness")
            ))
        }
        if let executionError = oracle.executionError {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):oracle-execution",
                severity: .error,
                category: "oracle_execution",
                message: executionError,
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_execution")
            ))
        }
        if !oracle.agreementPassed {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):oracle-agreement",
                severity: .error,
                category: "oracle_agreement",
                message: "Native DRC and oracle DRC did not agree for this case.",
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_agreement")
            ))
        }
        for (index, reason) in oracle.failureReasons.enumerated() {
            let category = category(failureReason: reason)
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(result.caseID):oracle-failure:\(index)",
                severity: .error,
                category: category,
                message: reason,
                caseID: result.caseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: category)
            ))
        }
    }

    private func confidence(
        report: DRCCorpusReport,
        diagnostics: [DRCEvidenceDiagnostic]
    ) -> DRCEvidenceConfidence {
        let evidenceCount = report.caseResults.filter { $0.executionError == nil }.count
        if report.caseCount == 0 {
            return DRCEvidenceConfidence(
                level: .low,
                reason: "No DRC corpus cases are available.",
                evidenceCount: 0,
                limitationCount: diagnostics.count
            )
        }
        if evidenceCount == 0 {
            return DRCEvidenceConfidence(
                level: .low,
                reason: "Every primary DRC case failed before diagnostics could be used.",
                evidenceCount: 0,
                limitationCount: diagnostics.count
            )
        }
        if report.qualification.qualified {
            return DRCEvidenceConfidence(
                level: .high,
                reason: "The DRC corpus is qualified under its policy.",
                evidenceCount: evidenceCount,
                limitationCount: diagnostics.count
            )
        }
        return DRCEvidenceConfidence(
            level: .medium,
            reason: "The DRC corpus produced usable evidence, but qualification diagnostics remain.",
            evidenceCount: evidenceCount,
            limitationCount: diagnostics.count
        )
    }

    private func decisionHints(
        diagnostics: [DRCEvidenceDiagnostic],
        report: DRCCorpusReport
    ) -> [DRCEvidenceDecisionHint] {
        if diagnostics.isEmpty {
            return [
                DRCEvidenceDecisionHint(
                    hintID: "drc-corpus-qualified",
                    priority: .low,
                    summary: "Use the qualified DRC corpus as a trusted native signoff evidence source.",
                    suggestedActions: ["use_drc_evidence_for_repair_gate"]
                )
            ]
        }
        var groups: [String: [DRCEvidenceDiagnostic]] = [:]
        for diagnostic in diagnostics {
            groups[diagnostic.category, default: []].append(diagnostic)
        }
        return groups.keys.sorted().map { category in
            let groupedDiagnostics = groups[category] ?? []
            return DRCEvidenceDecisionHint(
                hintID: "drc:\(category)",
                priority: priority(category: category, report: report),
                summary: summary(category: category, count: groupedDiagnostics.count),
                diagnosticIDs: groupedDiagnostics.map(\.diagnosticID),
                suggestedActions: suggestedActions(category: category)
            )
        }
    }

    private func summaryMetrics(_ report: DRCCorpusReport) -> [String: Double] {
        var values = [
            "passRate": report.summary.passRate,
            "durationBudgetPassRate": durationBudgetPassRate(report),
            "totalDurationSeconds": report.totalDurationSeconds,
        ]
        if let oracleAgreementRate = report.summary.oracleAgreementRate {
            values["oracleAgreementRate"] = oracleAgreementRate
        }
        return values
    }

    private func summaryCounts(_ report: DRCCorpusReport) -> [String: Int] {
        [
            "caseCount": report.caseCount,
            "matchedCaseCount": report.matchedCaseCount,
            "budgetExceededCaseCount": report.budgetExceededCaseCount,
            "durationBudgetPassedCaseCount": report.summary.durationBudgetPassedCaseCount,
            "primaryExecutionFailedCaseCount": report.summary.primaryExecutionFailedCaseCount,
            "oracleCaseCount": report.summary.oracleCaseCount,
            "oracleAgreementPassedCaseCount": report.summary.oracleAgreementPassedCaseCount,
            "oracleExecutionFailedCaseCount": report.summary.oracleExecutionFailedCaseCount,
            "oracleReadinessBlockedCaseCount": report.summary.oracleReadinessBlockedCaseCount,
            "coverageTagCount": report.summary.coverageTagCounts.count,
            "qualificationFailureCount": report.qualification.failures.count,
        ]
    }

    private func durationBudgetPassRate(_ report: DRCCorpusReport) -> Double {
        report.caseCount == 0
            ? 1
            : Double(report.summary.durationBudgetPassedCaseCount) / Double(report.caseCount)
    }

    private func category(qualificationCode: String) -> String {
        switch qualificationCode {
        case "required_coverage_missing":
            return "coverage_gap"
        case "primary_execution_failed":
            return "primary_execution"
        case "oracle_execution_failed":
            return "oracle_execution"
        case "oracle_case_count_below_minimum",
             "oracle_agreement_rate_missing",
             "oracle_agreement_rate_below_minimum":
            return "oracle_agreement"
        case "duration_budget_pass_rate_below_minimum":
            return "duration_budget"
        case "pass_rate_below_minimum",
             "corpus_not_passed":
            return "corpus_gate"
        default:
            return "qualification_failure"
        }
    }

    private func category(failureReason: String) -> String {
        if let separatorIndex = failureReason.firstIndex(of: ":") {
            return normalizedCategory(String(failureReason[..<separatorIndex]))
        }
        return normalizedCategory(failureReason)
    }

    private func normalizedCategory(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
    }

    private func suggestedActions(category: String) -> [String] {
        switch category {
        case "primary_execution":
            return ["inspect_drc_backend_logs", "verify_drc_inputs_and_pdk_profile"]
        case "oracle_execution":
            return ["inspect_oracle_backend_logs", "verify_oracle_tool_configuration"]
        case "oracle_readiness":
            return ["inspect_oracle_backend_readiness", "inspect_oracle_backend_logs"]
        case "oracle_agreement":
            return ["compare_native_and_oracle_rule_ids", "inspect_rule_mapping"]
        case "expectation_mismatch", "rule_set_mismatch":
            return ["inspect_expected_rule_ids", "inspect_native_drc_diagnostic_mapping"]
        case "duration_budget":
            return ["inspect_case_runtime_and_technology_complexity"]
        case "coverage_gap":
            return ["add_missing_drc_corpus_coverage"]
        case "corpus_gate":
            return ["inspect_failing_drc_corpus_cases"]
        default:
            return ["inspect_drc_corpus_diagnostics"]
        }
    }

    private func priority(category: String, report: DRCCorpusReport) -> DRCEvidenceDecisionPriority {
        switch category {
        case "primary_execution", "oracle_readiness", "oracle_execution":
            return .high
        case "oracle_agreement", "coverage_gap", "expectation_mismatch", "rule_set_mismatch", "corpus_gate":
            return .medium
        default:
            return report.qualification.qualified ? .low : .medium
        }
    }

    private func summary(category: String, count: Int) -> String {
        switch category {
        case "primary_execution":
            return "\(count) primary DRC execution issue(s) need backend or input inspection."
        case "oracle_execution":
            return "\(count) DRC oracle execution issue(s) need oracle tool inspection."
        case "oracle_readiness":
            return "\(count) DRC oracle readiness issue(s) blocked benchmark comparison."
        case "oracle_agreement":
            return "\(count) native-vs-oracle DRC agreement issue(s) need rule mapping inspection."
        case "coverage_gap":
            return "\(count) DRC coverage gap(s) prevent qualification under the current policy."
        case "expectation_mismatch", "rule_set_mismatch":
            return "\(count) DRC expected-vs-observed diagnostic mismatch issue(s) need rule-ID inspection."
        case "duration_budget":
            return "\(count) DRC duration budget issue(s) need runtime inspection."
        case "corpus_gate":
            return "\(count) DRC corpus gate issue(s) prevent qualification."
        default:
            return "\(count) DRC diagnostic issue(s) need inspection."
        }
    }
}
