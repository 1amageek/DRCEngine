import Foundation

public struct DRCEvidencePacket: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let packetID: String
    public let domain: String
    public let subject: DRCEvidenceSubject
    public let intent: DRCEvidenceIntent
    public let inputs: [DRCEvidenceArtifactRef]
    public let readiness: [DRCEvidenceReadiness]
    public let artifacts: [DRCEvidenceArtifactRef]
    public let normalizedViews: [DRCEvidenceNormalizedView]
    public let metrics: [DRCEvidenceMetric]
    public let diagnostics: [DRCEvidenceDiagnostic]
    public let confidence: DRCEvidenceConfidence
    public let decisionHints: [DRCEvidenceDecisionHint]
    public let coverageTags: [String]
    public let relatedEvidenceIDs: [String]

    public init(
        schemaVersion: Int = DRCEvidencePacket.currentSchemaVersion,
        packetID: String,
        domain: String,
        subject: DRCEvidenceSubject,
        intent: DRCEvidenceIntent,
        inputs: [DRCEvidenceArtifactRef] = [],
        readiness: [DRCEvidenceReadiness] = [],
        artifacts: [DRCEvidenceArtifactRef] = [],
        normalizedViews: [DRCEvidenceNormalizedView] = [],
        metrics: [DRCEvidenceMetric] = [],
        diagnostics: [DRCEvidenceDiagnostic] = [],
        confidence: DRCEvidenceConfidence,
        decisionHints: [DRCEvidenceDecisionHint] = [],
        coverageTags: [String] = [],
        relatedEvidenceIDs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.packetID = packetID
        self.domain = domain
        self.subject = subject
        self.intent = intent
        self.inputs = inputs
        self.readiness = readiness
        self.artifacts = artifacts
        self.normalizedViews = normalizedViews
        self.metrics = metrics
        self.diagnostics = diagnostics
        self.confidence = confidence
        self.decisionHints = decisionHints
        self.coverageTags = Array(Set(coverageTags.filter { !$0.isEmpty })).sorted()
        self.relatedEvidenceIDs = Array(Set(relatedEvidenceIDs.filter { !$0.isEmpty })).sorted()
    }

    public func validateIntegrity() -> [DRCEvidenceIntegrityIssue] {
        var issues: [DRCEvidenceIntegrityIssue] = []
        appendRequiredFieldIssues(&issues)
        appendArtifactIssues(&issues)
        appendMetricIssues(&issues)
        appendDiagnosticIssues(&issues)
        appendDecisionHintIssues(&issues)
        appendConfidenceIssues(&issues)
        return issues
    }

    private func appendRequiredFieldIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        if schemaVersion != Self.currentSchemaVersion {
            issues.append(.issue(
                code: "drc_evidence_schema_version_unsupported",
                fieldPath: "schemaVersion",
                message: "DRC evidence packet schemaVersion \(schemaVersion) is not supported.",
                suggestedActions: ["regenerate_drc_evidence_packet"]
            ))
        }
        appendNonEmptyIssue(&issues, value: packetID, fieldPath: "packetID")
        appendNonEmptyIssue(&issues, value: domain, fieldPath: "domain")
        appendNonEmptyIssue(&issues, value: subject.kind, fieldPath: "subject.kind")
        appendNonEmptyIssue(&issues, value: subject.identifier, fieldPath: "subject.identifier")
        appendNonEmptyIssue(&issues, value: intent.summary, fieldPath: "intent.summary")
    }

    private func appendArtifactIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        var seenArtifactIDs: Set<String> = []
        for (collectionName, refs) in [("inputs", inputs), ("artifacts", artifacts)] {
            for (index, ref) in refs.enumerated() {
                let prefix = "\(collectionName)[\(index)]"
                appendNonEmptyIssue(&issues, value: ref.artifactID, fieldPath: "\(prefix).artifactID")
                appendNonEmptyIssue(&issues, value: ref.path, fieldPath: "\(prefix).path")
                appendNonEmptyIssue(&issues, value: ref.role, fieldPath: "\(prefix).role")
                appendNonEmptyIssue(&issues, value: ref.kind, fieldPath: "\(prefix).kind")
                appendNonEmptyIssue(&issues, value: ref.format, fieldPath: "\(prefix).format")
                if !ref.artifactID.isEmpty, !seenArtifactIDs.insert(ref.artifactID).inserted {
                    issues.append(.issue(
                        code: "drc_evidence_duplicate_artifact_id",
                        fieldPath: "\(prefix).artifactID",
                        message: "DRC evidence artifact ID \(ref.artifactID) is duplicated.",
                        suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_artifact_ids"]
                    ))
                }
                appendPathIssues(&issues, path: ref.path, fieldPath: "\(prefix).path")
                if let sha256 = ref.sha256, !Self.isValidSHA256(sha256) {
                    issues.append(.issue(
                        code: "drc_evidence_invalid_sha256",
                        fieldPath: "\(prefix).sha256",
                        message: "DRC evidence artifact \(ref.artifactID) has an invalid SHA-256 digest.",
                        suggestedActions: ["recompute_drc_evidence_artifact_hash", "regenerate_drc_evidence_packet"]
                    ))
                }
            }
        }

        let knownArtifactIDs = Set((inputs + artifacts).map(\.artifactID).filter { !$0.isEmpty })
        appendArtifactReferenceIssues(
            &issues,
            values: readiness.flatMap(\.artifactIDs),
            knownArtifactIDs: knownArtifactIDs,
            fieldPath: "readiness.artifactIDs"
        )
        appendArtifactReferenceIssues(
            &issues,
            values: normalizedViews.flatMap(\.sourceArtifactIDs),
            knownArtifactIDs: knownArtifactIDs,
            fieldPath: "normalizedViews.sourceArtifactIDs"
        )
        appendArtifactReferenceIssues(
            &issues,
            values: diagnostics.flatMap(\.artifactIDs),
            knownArtifactIDs: knownArtifactIDs,
            fieldPath: "diagnostics.artifactIDs"
        )
    }

    private func appendMetricIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        var seenMetricIDs: Set<String> = []
        for (index, metric) in metrics.enumerated() {
            let prefix = "metrics[\(index)]"
            appendNonEmptyIssue(&issues, value: metric.metricID, fieldPath: "\(prefix).metricID")
            appendNonEmptyIssue(&issues, value: metric.name, fieldPath: "\(prefix).name")
            if !metric.metricID.isEmpty, !seenMetricIDs.insert(metric.metricID).inserted {
                issues.append(.issue(
                    code: "drc_evidence_duplicate_metric_id",
                    fieldPath: "\(prefix).metricID",
                    message: "DRC evidence metric ID \(metric.metricID) is duplicated.",
                    suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_metric_ids"]
                ))
            }
            if let value = metric.value, !value.isFinite {
                issues.append(.issue(
                    code: "drc_evidence_non_finite_metric_value",
                    fieldPath: "\(prefix).value",
                    message: "DRC evidence metric \(metric.metricID) has a non-finite value.",
                    suggestedActions: ["inspect_drc_corpus_metrics", "regenerate_drc_evidence_packet"]
                ))
            }
            if let count = metric.count, count < 0 {
                issues.append(.issue(
                    code: "drc_evidence_negative_metric_count",
                    fieldPath: "\(prefix).count",
                    message: "DRC evidence metric \(metric.metricID) has a negative count.",
                    suggestedActions: ["inspect_drc_corpus_metrics", "regenerate_drc_evidence_packet"]
                ))
            }
        }
    }

    private func appendDiagnosticIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        var seenDiagnosticIDs: Set<String> = []
        for (index, diagnostic) in diagnostics.enumerated() {
            let prefix = "diagnostics[\(index)]"
            appendNonEmptyIssue(&issues, value: diagnostic.diagnosticID, fieldPath: "\(prefix).diagnosticID")
            appendNonEmptyIssue(&issues, value: diagnostic.category, fieldPath: "\(prefix).category")
            appendNonEmptyIssue(&issues, value: diagnostic.message, fieldPath: "\(prefix).message")
            if !diagnostic.diagnosticID.isEmpty, !seenDiagnosticIDs.insert(diagnostic.diagnosticID).inserted {
                issues.append(.issue(
                    code: "drc_evidence_duplicate_diagnostic_id",
                    fieldPath: "\(prefix).diagnosticID",
                    message: "DRC evidence diagnostic ID \(diagnostic.diagnosticID) is duplicated.",
                    suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_diagnostic_ids"]
                ))
            }
            if let observedValue = diagnostic.observedValue, !observedValue.isFinite {
                issues.append(.issue(
                    code: "drc_evidence_non_finite_observed_value",
                    fieldPath: "\(prefix).observedValue",
                    message: "DRC evidence diagnostic \(diagnostic.diagnosticID) has a non-finite observed value.",
                    suggestedActions: ["inspect_drc_diagnostic_values", "regenerate_drc_evidence_packet"]
                ))
            }
            if let requiredValue = diagnostic.requiredValue, !requiredValue.isFinite {
                issues.append(.issue(
                    code: "drc_evidence_non_finite_required_value",
                    fieldPath: "\(prefix).requiredValue",
                    message: "DRC evidence diagnostic \(diagnostic.diagnosticID) has a non-finite required value.",
                    suggestedActions: ["inspect_drc_diagnostic_values", "regenerate_drc_evidence_packet"]
                ))
            }
        }
    }

    private func appendDecisionHintIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        var seenHintIDs: Set<String> = []
        let knownDiagnosticIDs = Set(diagnostics.map(\.diagnosticID).filter { !$0.isEmpty })
        for (index, hint) in decisionHints.enumerated() {
            let prefix = "decisionHints[\(index)]"
            appendNonEmptyIssue(&issues, value: hint.hintID, fieldPath: "\(prefix).hintID")
            appendNonEmptyIssue(&issues, value: hint.summary, fieldPath: "\(prefix).summary")
            if !hint.hintID.isEmpty, !seenHintIDs.insert(hint.hintID).inserted {
                issues.append(.issue(
                    code: "drc_evidence_duplicate_decision_hint_id",
                    fieldPath: "\(prefix).hintID",
                    message: "DRC evidence decision hint ID \(hint.hintID) is duplicated.",
                    suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_decision_hint_ids"]
                ))
            }
            for diagnosticID in hint.diagnosticIDs where !knownDiagnosticIDs.contains(diagnosticID) {
                issues.append(.issue(
                    code: "drc_evidence_dangling_diagnostic_reference",
                    fieldPath: "\(prefix).diagnosticIDs",
                    message: "DRC evidence decision hint \(hint.hintID) references unknown diagnostic ID \(diagnosticID).",
                    suggestedActions: ["inspect_drc_evidence_decision_hints", "regenerate_drc_evidence_packet"]
                ))
            }
        }
    }

    private func appendConfidenceIssues(_ issues: inout [DRCEvidenceIntegrityIssue]) {
        appendNonEmptyIssue(&issues, value: confidence.reason, fieldPath: "confidence.reason")
        if confidence.evidenceCount < 0 {
            issues.append(.issue(
                code: "drc_evidence_negative_confidence_evidence_count",
                fieldPath: "confidence.evidenceCount",
                message: "DRC evidence confidence evidenceCount cannot be negative.",
                suggestedActions: ["inspect_drc_evidence_confidence", "regenerate_drc_evidence_packet"]
            ))
        }
        if confidence.limitationCount < 0 {
            issues.append(.issue(
                code: "drc_evidence_negative_confidence_limitation_count",
                fieldPath: "confidence.limitationCount",
                message: "DRC evidence confidence limitationCount cannot be negative.",
                suggestedActions: ["inspect_drc_evidence_confidence", "regenerate_drc_evidence_packet"]
            ))
        }
    }

    private func appendNonEmptyIssue(
        _ issues: inout [DRCEvidenceIntegrityIssue],
        value: String,
        fieldPath: String
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.issue(
                code: "drc_evidence_required_field_empty",
                fieldPath: fieldPath,
                message: "DRC evidence field \(fieldPath) must not be empty.",
                suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_required_fields"]
            ))
        }
    }

    private func appendPathIssues(
        _ issues: inout [DRCEvidenceIntegrityIssue],
        path: String,
        fieldPath: String
    ) {
        guard !path.isEmpty else {
            return
        }
        if path.trimmingCharacters(in: .whitespacesAndNewlines) != path {
            issues.append(.issue(
                code: "drc_evidence_artifact_path_has_whitespace",
                fieldPath: fieldPath,
                message: "DRC evidence artifact path \(path) contains leading or trailing whitespace.",
                suggestedActions: ["normalize_drc_evidence_artifact_path", "regenerate_drc_evidence_packet"]
            ))
        }
        if path.contains("://") {
            issues.append(.issue(
                code: "drc_evidence_artifact_path_has_url_scheme",
                fieldPath: fieldPath,
                message: "DRC evidence artifact path \(path) contains a URL scheme.",
                suggestedActions: ["use_local_drc_evidence_artifact_path", "regenerate_drc_evidence_packet"]
            ))
        }
        if path.hasPrefix("~") {
            issues.append(.issue(
                code: "drc_evidence_artifact_path_has_home_shortcut",
                fieldPath: fieldPath,
                message: "DRC evidence artifact path \(path) starts with a home-directory shortcut.",
                suggestedActions: ["expand_drc_evidence_artifact_path", "regenerate_drc_evidence_packet"]
            ))
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if components.contains(".") || components.contains("..") {
            issues.append(.issue(
                code: "drc_evidence_artifact_path_has_relative_component",
                fieldPath: fieldPath,
                message: "DRC evidence artifact path \(path) contains current-directory or parent-directory components.",
                suggestedActions: ["normalize_drc_evidence_artifact_path", "regenerate_drc_evidence_packet"]
            ))
        }
    }

    private func appendArtifactReferenceIssues(
        _ issues: inout [DRCEvidenceIntegrityIssue],
        values: [String],
        knownArtifactIDs: Set<String>,
        fieldPath: String
    ) {
        for artifactID in values {
            if artifactID.isEmpty {
                issues.append(.issue(
                    code: "drc_evidence_empty_artifact_reference",
                    fieldPath: fieldPath,
                    message: "DRC evidence artifact reference in \(fieldPath) must not be empty.",
                    suggestedActions: ["regenerate_drc_evidence_packet", "inspect_drc_evidence_artifact_references"]
                ))
            } else if !knownArtifactIDs.contains(artifactID) {
                issues.append(.issue(
                    code: "drc_evidence_dangling_artifact_reference",
                    fieldPath: fieldPath,
                    message: "DRC evidence references unknown artifact ID \(artifactID).",
                    suggestedActions: ["inspect_drc_evidence_artifact_references", "regenerate_drc_evidence_packet"]
                ))
            }
        }
    }

    private static func isValidSHA256(_ value: String) -> Bool {
        let hexCharacters = Set("0123456789abcdefABCDEF")
        return value.count == 64 && value.allSatisfy { hexCharacters.contains($0) }
    }
}

public struct DRCEvidenceIntegrityIssue: Sendable, Hashable, Codable {
    public let code: String
    public let fieldPath: String
    public let message: String
    public let suggestedActions: [String]

    public init(
        code: String,
        fieldPath: String,
        message: String,
        suggestedActions: [String] = []
    ) {
        self.code = code
        self.fieldPath = fieldPath
        self.message = message
        self.suggestedActions = suggestedActions
    }

    public static func issue(
        code: String,
        fieldPath: String,
        message: String,
        suggestedActions: [String]
    ) -> DRCEvidenceIntegrityIssue {
        DRCEvidenceIntegrityIssue(
            code: code,
            fieldPath: fieldPath,
            message: message,
            suggestedActions: suggestedActions
        )
    }
}

public struct DRCEvidenceSubject: Sendable, Hashable, Codable {
    public let kind: String
    public let identifier: String
    public let backendID: String?

    public init(
        kind: String,
        identifier: String,
        backendID: String? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.backendID = backendID
    }
}

public struct DRCEvidenceIntent: Sendable, Hashable, Codable {
    public let summary: String
    public let designContext: String?
    public let requestedObservations: [String]

    public init(
        summary: String,
        designContext: String? = nil,
        requestedObservations: [String] = []
    ) {
        self.summary = summary
        self.designContext = designContext
        self.requestedObservations = Array(Set(requestedObservations.filter { !$0.isEmpty })).sorted()
    }
}

public struct DRCEvidenceArtifactRef: Sendable, Hashable, Codable {
    public let artifactID: String
    public let path: String
    public let role: String
    public let kind: String
    public let format: String
    public let sha256: String?
    public let caseID: String?

    public init(
        artifactID: String,
        path: String,
        role: String,
        kind: String,
        format: String,
        sha256: String? = nil,
        caseID: String? = nil
    ) {
        self.artifactID = artifactID
        self.path = path
        self.role = role
        self.kind = kind
        self.format = format
        self.sha256 = sha256
        self.caseID = caseID
    }
}

public enum DRCEvidenceReadinessStatus: String, Sendable, Hashable, Codable {
    case ready
    case blocked
    case unknown
}

public struct DRCEvidenceReadiness: Sendable, Hashable, Codable {
    public let component: String
    public let status: DRCEvidenceReadinessStatus
    public let reason: String
    public let artifactIDs: [String]
    public let suggestedActions: [String]

    public init(
        component: String,
        status: DRCEvidenceReadinessStatus,
        reason: String,
        artifactIDs: [String] = [],
        suggestedActions: [String] = []
    ) {
        self.component = component
        self.status = status
        self.reason = reason
        self.artifactIDs = Array(Set(artifactIDs.filter { !$0.isEmpty })).sorted()
        self.suggestedActions = suggestedActions.filter { !$0.isEmpty }
    }
}

public struct DRCEvidenceNormalizedView: Sendable, Hashable, Codable {
    public let viewID: String
    public let kind: String
    public let scope: String
    public let summaryMetrics: [String: Double]
    public let summaryCounts: [String: Int]
    public let sourceArtifactIDs: [String]

    public init(
        viewID: String,
        kind: String,
        scope: String,
        summaryMetrics: [String: Double] = [:],
        summaryCounts: [String: Int] = [:],
        sourceArtifactIDs: [String] = []
    ) {
        self.viewID = viewID
        self.kind = kind
        self.scope = scope
        self.summaryMetrics = summaryMetrics
        self.summaryCounts = summaryCounts
        self.sourceArtifactIDs = Array(Set(sourceArtifactIDs.filter { !$0.isEmpty })).sorted()
    }
}

public struct DRCEvidenceMetric: Sendable, Hashable, Codable {
    public let metricID: String
    public let name: String
    public let value: Double?
    public let count: Int?
    public let unit: String?
    public let caseID: String?
    public let ruleID: String?

    public init(
        metricID: String,
        name: String,
        value: Double? = nil,
        count: Int? = nil,
        unit: String? = nil,
        caseID: String? = nil,
        ruleID: String? = nil
    ) {
        self.metricID = metricID
        self.name = name
        self.value = value
        self.count = count
        self.unit = unit
        self.caseID = caseID
        self.ruleID = ruleID
    }
}

public enum DRCEvidenceSeverity: String, Sendable, Hashable, Codable {
    case info
    case warning
    case error
}

public struct DRCEvidenceDiagnostic: Sendable, Hashable, Codable {
    public let diagnosticID: String
    public let severity: DRCEvidenceSeverity
    public let category: String
    public let message: String
    public let caseID: String?
    public let ruleID: String?
    public let kind: String?
    public let layer: String?
    public let observedValue: Double?
    public let requiredValue: Double?
    public let unit: String?
    public let artifactIDs: [String]
    public let suggestedActions: [String]

    public init(
        diagnosticID: String,
        severity: DRCEvidenceSeverity,
        category: String,
        message: String,
        caseID: String? = nil,
        ruleID: String? = nil,
        kind: String? = nil,
        layer: String? = nil,
        observedValue: Double? = nil,
        requiredValue: Double? = nil,
        unit: String? = nil,
        artifactIDs: [String] = [],
        suggestedActions: [String] = []
    ) {
        self.diagnosticID = diagnosticID
        self.severity = severity
        self.category = category
        self.message = message
        self.caseID = caseID
        self.ruleID = ruleID
        self.kind = kind
        self.layer = layer
        self.observedValue = observedValue
        self.requiredValue = requiredValue
        self.unit = unit
        self.artifactIDs = Array(Set(artifactIDs.filter { !$0.isEmpty })).sorted()
        self.suggestedActions = suggestedActions.filter { !$0.isEmpty }
    }
}

public enum DRCEvidenceConfidenceLevel: String, Sendable, Hashable, Codable {
    case high
    case medium
    case low
}

public struct DRCEvidenceConfidence: Sendable, Hashable, Codable {
    public let level: DRCEvidenceConfidenceLevel
    public let reason: String
    public let evidenceCount: Int
    public let limitationCount: Int

    public init(
        level: DRCEvidenceConfidenceLevel,
        reason: String,
        evidenceCount: Int,
        limitationCount: Int
    ) {
        self.level = level
        self.reason = reason
        self.evidenceCount = evidenceCount
        self.limitationCount = limitationCount
    }
}

public enum DRCEvidenceDecisionPriority: String, Sendable, Hashable, Codable {
    case high
    case medium
    case low
}

public struct DRCEvidenceDecisionHint: Sendable, Hashable, Codable {
    public let hintID: String
    public let priority: DRCEvidenceDecisionPriority
    public let summary: String
    public let diagnosticIDs: [String]
    public let suggestedActions: [String]

    public init(
        hintID: String,
        priority: DRCEvidenceDecisionPriority,
        summary: String,
        diagnosticIDs: [String] = [],
        suggestedActions: [String] = []
    ) {
        self.hintID = hintID
        self.priority = priority
        self.summary = summary
        self.diagnosticIDs = Array(Set(diagnosticIDs.filter { !$0.isEmpty })).sorted()
        self.suggestedActions = suggestedActions.filter { !$0.isEmpty }
    }
}
