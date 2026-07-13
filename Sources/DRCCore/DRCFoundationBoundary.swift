@_exported import CircuiteFoundation

/// Canonical evidence view exposed by DRC at the cross-engine boundary.
///
/// DRC-specific manifests remain available for signoff policy and waiver
/// details. This value provides the stable Foundation representation that a
/// flow coordinator or an agent can consume without depending on those
/// implementation details.
public struct DRCFoundationEvidence: Sendable, Hashable, Codable, ArtifactProducing,
    EvidenceProviding, DiagnosticReporting
{
    public let evidence: EvidenceManifest
    public let diagnostics: [DesignDiagnostic]

    public var artifacts: [ArtifactReference] { evidence.artifacts }

    public init(
        execution: DRCExecutionResult,
        provenance: ExecutionProvenance,
        artifacts: [ArtifactReference] = []
    ) throws {
        self.evidence = EvidenceManifest(
            provenance: provenance,
            artifacts: artifacts
        )
        self.diagnostics = try execution.result.diagnostics.map(Self.makeDiagnostic)
    }

    private static func makeDiagnostic(_ diagnostic: DRCDiagnostic) throws -> DesignDiagnostic {
        let rawCode = diagnostic.ruleID.map { "drc.\($0)" } ?? "drc.\(diagnostic.severity.rawValue)"
        let code = try DiagnosticCode(rawValue: rawCode)
        let severity: DiagnosticSeverity
        switch diagnostic.severity {
        case .info:
            severity = .information
        case .warning:
            severity = .warning
        case .error:
            severity = .error
        }
        let detail = diagnostic.rawLine.isEmpty ? nil : diagnostic.rawLine
        let suggestedActions = diagnostic.suggestedFix.map {
            [SuggestedAction(code: "drc.repair", summary: $0)]
        } ?? []
        return DesignDiagnostic(
            code: code,
            severity: severity,
            summary: diagnostic.message,
            detail: detail,
            suggestedActions: suggestedActions
        )
    }
}

/// Engine boundary shared by DRC consumers and flow coordinators.
public protocol DRCEngineProtocol: Engine
where Request == DRCRequest, Output == DRCExecutionResult {
    func run(_ request: DRCRequest) async throws -> DRCExecutionResult
}

extension DRCRequest {
    /// Returns the Foundation hierarchy identity for the requested top cell.
    public func designObjectReference() throws -> DesignObjectReference {
        try DesignObjectReference(kind: .cell, identifier: topCell)
    }
}
