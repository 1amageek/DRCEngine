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
