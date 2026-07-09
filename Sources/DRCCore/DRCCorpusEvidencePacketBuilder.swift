import Foundation

public struct DRCCorpusEvidencePacketBuilder: Sendable {
    public init() {}

    public func build(
        report: DRCCorpusReport,
        reportPath: String,
        reportSHA256: String? = nil,
        packetID: String? = nil,
        allowedArtifactRootPath: String? = nil
    ) -> DRCEvidencePacket {
        let caseContexts = caseContexts(report.caseResults)
        let inputs = inputRefs(reportPath: reportPath, reportSHA256: reportSHA256)
        let artifactBuild = artifactRefs(
            contexts: caseContexts,
            allowedArtifactRootPath: allowedArtifactRootPath
        )
        let artifacts = artifactBuild.refs
        let integrityDiagnostics = caseContexts.flatMap(\.diagnostics) + artifactBuild.diagnostics
        let diagnostics = diagnostics(
            report: report,
            contexts: caseContexts,
            artifactRefs: inputs + artifacts
        ) + integrityDiagnostics
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
            readiness: readiness(
                report: report,
                reportArtifactID: inputs.first?.artifactID,
                integrityDiagnostics: integrityDiagnostics
            ),
            artifacts: artifacts,
            normalizedViews: normalizedViews(report: report, artifactRefs: inputs + artifacts),
            metrics: metrics(report: report, contexts: caseContexts),
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

    private struct EvidenceCaseContext {
        let result: DRCCorpusCaseResult
        let caseKey: String
        let payloadCaseID: String?
        let diagnostics: [DRCEvidenceDiagnostic]
    }

    private struct ArtifactRefBuildResult {
        var refs: [DRCEvidenceArtifactRef]
        var diagnostics: [DRCEvidenceDiagnostic]
    }

    private func caseContexts(_ results: [DRCCorpusCaseResult]) -> [EvidenceCaseContext] {
        var rawCaseIDCounts: [String: Int] = [:]
        for result in results {
            let trimmedCaseID = result.caseID.trimmingCharacters(in: .whitespacesAndNewlines)
            rawCaseIDCounts[trimmedCaseID, default: 0] += 1
        }

        var namespaceCounts: [String: Int] = [:]
        return results.enumerated().map { index, result in
            let trimmedCaseID = result.caseID.trimmingCharacters(in: .whitespacesAndNewlines)
            var baseKey = sanitizedIdentifierToken(trimmedCaseID)
            if baseKey.isEmpty {
                baseKey = "case-\(index + 1)"
            }
            let namespaceOccurrence = namespaceCounts[baseKey, default: 0] + 1
            namespaceCounts[baseKey] = namespaceOccurrence
            let caseKey = namespaceOccurrence == 1 ? baseKey : "\(baseKey)-\(namespaceOccurrence)"
            var diagnostics: [DRCEvidenceDiagnostic] = []

            if trimmedCaseID.isEmpty {
                diagnostics.append(caseIDDiagnostic(
                    caseKey: caseKey,
                    issueID: "case-id-empty",
                    caseID: nil,
                    reason: "The DRC corpus case ID is empty and cannot be used as a stable evidence namespace."
                ))
            } else if trimmedCaseID != result.caseID || trimmedCaseID != baseKey {
                diagnostics.append(caseIDDiagnostic(
                    caseKey: caseKey,
                    issueID: "case-id-unsafe",
                    caseID: trimmedCaseID,
                    reason: "The DRC corpus case ID contains characters that are not valid in evidence artifact IDs."
                ))
            }

            if rawCaseIDCounts[trimmedCaseID, default: 0] > 1 {
                diagnostics.append(caseIDDiagnostic(
                    caseKey: caseKey,
                    issueID: "case-id-duplicate",
                    caseID: trimmedCaseID.isEmpty ? nil : trimmedCaseID,
                    reason: "The DRC corpus case ID is duplicated and would otherwise collide in evidence IDs."
                ))
            } else if namespaceOccurrence > 1 {
                diagnostics.append(caseIDDiagnostic(
                    caseKey: caseKey,
                    issueID: "case-id-namespace-collision",
                    caseID: trimmedCaseID.isEmpty ? nil : trimmedCaseID,
                    reason: "The DRC corpus case ID normalizes to an evidence namespace already used by another case."
                ))
            }

            return EvidenceCaseContext(
                result: result,
                caseKey: caseKey,
                payloadCaseID: trimmedCaseID.isEmpty ? nil : trimmedCaseID,
                diagnostics: diagnostics
            )
        }
    }

    private func artifactRefs(
        contexts: [EvidenceCaseContext],
        allowedArtifactRootPath: String?
    ) -> ArtifactRefBuildResult {
        var result = ArtifactRefBuildResult(refs: [], diagnostics: [])
        for context in contexts {
            appendCaseRef(
                &result,
                path: context.result.reportPath,
                context: context,
                role: "run-artifact",
                kind: "drc-case-report",
                format: "JSON",
                sourceField: "reportPath",
                allowedArtifactRootPath: allowedArtifactRootPath
            )
            appendCaseRef(
                &result,
                path: context.result.manifestPath,
                context: context,
                role: "run-artifact",
                kind: "drc-artifact-manifest",
                format: "JSON",
                sourceField: "manifestPath",
                allowedArtifactRootPath: allowedArtifactRootPath
            )
            appendCaseRef(
                &result,
                path: context.result.oracleResult?.reportPath,
                context: context,
                role: "oracle-artifact",
                kind: "drc-oracle-report",
                format: "JSON",
                sourceField: "oracleReportPath",
                allowedArtifactRootPath: allowedArtifactRootPath
            )
            appendCaseRef(
                &result,
                path: context.result.oracleResult?.manifestPath,
                context: context,
                role: "oracle-artifact",
                kind: "drc-oracle-artifact-manifest",
                format: "JSON",
                sourceField: "oracleManifestPath",
                allowedArtifactRootPath: allowedArtifactRootPath
            )
        }
        return result
    }

    private func appendCaseRef(
        _ result: inout ArtifactRefBuildResult,
        path: String?,
        context: EvidenceCaseContext,
        role: String,
        kind: String,
        format: String,
        sourceField: String,
        allowedArtifactRootPath: String?
    ) {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let reason = artifactPathValidationFailure(path, allowedArtifactRootPath: allowedArtifactRootPath) {
            result.diagnostics.append(artifactPathDiagnostic(
                caseKey: context.caseKey,
                caseID: context.payloadCaseID,
                sourceField: sourceField,
                reason: reason
            ))
            return
        }
        result.refs.append(DRCEvidenceArtifactRef(
            artifactID: "\(context.caseKey):\(sourceField)",
            path: path,
            role: role,
            kind: kind,
            format: format,
            caseID: context.payloadCaseID
        ))
    }

    private func readiness(
        report: DRCCorpusReport,
        reportArtifactID: String?,
        integrityDiagnostics: [DRCEvidenceDiagnostic]
    ) -> [DRCEvidenceReadiness] {
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
        let integrityReadiness = integrityDiagnostics.isEmpty
            ? []
            : [
                DRCEvidenceReadiness(
                    component: "drc-evidence-artifacts",
                    status: .blocked,
                    reason: "One or more DRC corpus evidence identifiers or artifact references are not safe to trust.",
                    artifactIDs: [reportArtifactID].compactMap { $0 },
                    suggestedActions: ["inspect_drc_corpus_artifact_paths", "regenerate_drc_corpus_report"]
                ),
            ]
        if report.summary.primaryExecutionFailedCaseCount == caseCount {
            return integrityReadiness + [
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
        var values = integrityReadiness + [
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

    private func metrics(report: DRCCorpusReport, contexts: [EvidenceCaseContext]) -> [DRCEvidenceMetric] {
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
        for context in contexts {
            values.append(contentsOf: caseMetrics(context))
        }
        return values
    }

    private func caseMetrics(_ context: EvidenceCaseContext) -> [DRCEvidenceMetric] {
        let result = context.result
        return [
            DRCEvidenceMetric(
                metricID: "\(context.caseKey).duration-seconds",
                name: "durationSeconds",
                value: result.durationSeconds,
                unit: "s",
                caseID: context.payloadCaseID
            ),
            DRCEvidenceMetric(
                metricID: "\(context.caseKey).expected-active-error-rule-count",
                name: "expectedActiveErrorRuleCount",
                count: result.expectedActiveErrorRuleIDs.count,
                caseID: context.payloadCaseID
            ),
            DRCEvidenceMetric(
                metricID: "\(context.caseKey).actual-active-error-rule-count",
                name: "actualActiveErrorRuleCount",
                count: result.actualActiveErrorRuleIDs.count,
                caseID: context.payloadCaseID
            ),
            DRCEvidenceMetric(
                metricID: "\(context.caseKey).error-count",
                name: "errorCount",
                count: result.diagnosticSummary.errorCount,
                caseID: context.payloadCaseID
            ),
            DRCEvidenceMetric(
                metricID: "\(context.caseKey).waived-error-count",
                name: "waivedErrorCount",
                count: result.diagnosticSummary.waivedErrorCount,
                caseID: context.payloadCaseID
            ),
        ]
    }

    private func diagnostics(
        report: DRCCorpusReport,
        contexts: [EvidenceCaseContext],
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
        for context in contexts {
            let caseArtifacts = artifactRefs.filter {
                $0.artifactID.hasPrefix("\(context.caseKey):")
            }.map(\.artifactID)
            appendCaseDiagnostics(&values, context: context, artifactIDs: caseArtifacts)
        }
        return values
    }

    private func appendCaseDiagnostics(
        _ values: inout [DRCEvidenceDiagnostic],
        context: EvidenceCaseContext,
        artifactIDs: [String]
    ) {
        let result = context.result
        if let executionError = result.executionError {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):primary-execution",
                severity: .error,
                category: "primary_execution",
                message: executionError,
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "primary_execution")
            ))
        }
        if !result.expectationMatched {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):expectation-mismatch",
                severity: .error,
                category: "expectation_mismatch",
                message: "Expected DRC pass state or active rule IDs did not match observed native DRC output.",
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "expectation_mismatch")
            ))
        }
        if !result.durationBudgetPassed {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):duration-budget",
                severity: .warning,
                category: "duration_budget",
                message: "The DRC case exceeded its expected duration budget.",
                caseID: context.payloadCaseID,
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
                diagnosticID: "\(context.caseKey):failure:\(index)",
                severity: .error,
                category: category,
                message: reason,
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: category)
            ))
        }
        if let oracle = result.oracleResult {
            appendOracleDiagnostics(&values, context: context, oracle: oracle, artifactIDs: artifactIDs)
        }
    }

    private func appendOracleDiagnostics(
        _ values: inout [DRCEvidenceDiagnostic],
        context: EvidenceCaseContext,
        oracle: DRCCorpusOracleResult,
        artifactIDs: [String]
    ) {
        if oracle.readinessStatus == .blocked {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):oracle-readiness",
                severity: .error,
                category: "oracle_readiness",
                message: oracle.readinessDiagnostics.joined(separator: "; "),
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_readiness")
            ))
        }
        if let executionError = oracle.executionError {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):oracle-execution",
                severity: .error,
                category: "oracle_execution",
                message: executionError,
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_execution")
            ))
        }
        if !oracle.agreementPassed {
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):oracle-agreement",
                severity: .error,
                category: "oracle_agreement",
                message: "Native DRC and oracle DRC did not agree for this case.",
                caseID: context.payloadCaseID,
                artifactIDs: artifactIDs,
                suggestedActions: suggestedActions(category: "oracle_agreement")
            ))
        }
        for (index, reason) in oracle.failureReasons.enumerated() {
            let category = category(failureReason: reason)
            values.append(DRCEvidenceDiagnostic(
                diagnosticID: "\(context.caseKey):oracle-failure:\(index)",
                severity: .error,
                category: category,
                message: reason,
                caseID: context.payloadCaseID,
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
        if diagnostics.contains(where: { $0.category == "artifact_integrity" }) {
            return DRCEvidenceConfidence(
                level: .low,
                reason: "The DRC corpus evidence packet contains unsafe identifiers or artifact references.",
                evidenceCount: evidenceCount,
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
            ? 0
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
        case "artifact_integrity":
            return ["inspect_drc_corpus_artifact_paths", "regenerate_drc_corpus_report"]
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
        case "artifact_integrity", "primary_execution", "oracle_readiness", "oracle_execution":
            return .high
        case "oracle_agreement", "coverage_gap", "expectation_mismatch", "rule_set_mismatch", "corpus_gate":
            return .medium
        default:
            return report.qualification.qualified ? .low : .medium
        }
    }

    private func summary(category: String, count: Int) -> String {
        switch category {
        case "artifact_integrity":
            return "\(count) DRC evidence artifact integrity issue(s) need corpus report inspection."
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

    private func caseIDDiagnostic(
        caseKey: String,
        issueID: String,
        caseID: String?,
        reason: String
    ) -> DRCEvidenceDiagnostic {
        DRCEvidenceDiagnostic(
            diagnosticID: "\(caseKey):\(issueID)",
            severity: .error,
            category: "artifact_integrity",
            message: reason,
            caseID: caseID,
            suggestedActions: suggestedActions(category: "artifact_integrity")
        )
    }

    private func artifactPathDiagnostic(
        caseKey: String,
        caseID: String?,
        sourceField: String,
        reason: String
    ) -> DRCEvidenceDiagnostic {
        DRCEvidenceDiagnostic(
            diagnosticID: "\(caseKey):\(sourceField)-artifact-integrity",
            severity: .error,
            category: "artifact_integrity",
            message: "The DRC corpus \(sourceField) artifact reference is not safe to trust: \(reason)",
            caseID: caseID,
            suggestedActions: suggestedActions(category: "artifact_integrity")
        )
    }

    private func artifactPathValidationFailure(
        _ path: String,
        allowedArtifactRootPath: String?
    ) -> String? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath == path else {
            return "path contains leading or trailing whitespace"
        }
        if path.contains("://") {
            return "path contains a URL scheme"
        }
        if path.hasPrefix("~") {
            return "path starts with a home-directory shortcut"
        }
        let components = (path as NSString).pathComponents
        if components.contains(".") || components.contains("..") {
            return "path contains current-directory or parent-directory components"
        }
        guard let allowedArtifactRootPath else {
            return nil
        }
        let rootURL = URL(filePath: allowedArtifactRootPath).standardizedFileURL
        let artifactURL = path.hasPrefix("/")
            ? URL(filePath: path).standardizedFileURL
            : rootURL.appendingPathComponent(path).standardizedFileURL
        let rootPath = rootURL.path(percentEncoded: false)
        let artifactPath = artifactURL.path(percentEncoded: false)
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard artifactPath == rootPath || artifactPath.hasPrefix(rootPrefix) else {
            return "path is outside the allowed corpus artifact root"
        }
        return nil
    }

    private func sanitizedIdentifierToken(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        var result = ""
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    }
}
