import Foundation
import DRCCore
import DRCNative
import DRCAdapters
import DRCPersistence

public struct DefaultDRCEngine: DRCExecuting, Sendable {
    private let backends: [String: any DRCBackend]
    private let backendIdentities: [String: DRCBackendIdentity]
    private let store: DRCArtifactStore

    public init(
        backend: (any DRCBackend)? = MagicDRCAdapter.locate(),
        store: DRCArtifactStore = DRCArtifactStore()
    ) {
        var backends: [any DRCBackend] = [NativeDRCBackend(), LayoutGDSDRCBackend()]
        if let backend {
            backends.append(backend)
        }
        self.init(backends: backends, store: store)
    }

    public init(
        backends: [any DRCBackend],
        store: DRCArtifactStore = DRCArtifactStore()
    ) {
        var backendsByID: [String: any DRCBackend] = [:]
        var identitiesByID: [String: DRCBackendIdentity] = [:]
        for backend in backends {
            backendsByID[backend.backendID] = backend
            identitiesByID[backend.backendID] = backend.identity
        }
        self.backends = backendsByID
        self.backendIdentities = identitiesByID
        self.store = store
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request, cancellationCheck: nil)
    }

    public func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult {
        try request.validate()
        let backendID = request.backendSelection.backendID
        guard let backend = backends[backendID] else {
            throw DRCError.backendUnavailable("Unsupported DRC backend: \(request.backendSelection.backendID)")
        }
        let executionRequest = try requestWithBoundInputArtifacts(request)
        let deadline = Date().addingTimeInterval(executionRequest.options.timeoutSeconds)
        var result: DRCExecutionResult
        do {
            if let cancellableBackend = backend as? any DRCCancellableBackend {
                let combinedCancellationCheck: DRCExecutionCancellationCheck = { [deadline] in
                    if let cancellationCheck, try await cancellationCheck() {
                        return true
                    }
                    return Date() >= deadline
                }
                result = try await cancellableBackend.run(
                    executionRequest,
                    cancellationCheck: combinedCancellationCheck
                )
            } else {
                result = try await backend.run(executionRequest)
            }
        } catch {
            if Task.isCancelled {
                throw DRCError.cancelled("DRC execution was cancelled.")
            }
            if Date() >= deadline, !Task.isCancelled {
                throw DRCError.timedOut(
                    "DRC backend '\(backendID)' exceeded \(executionRequest.options.timeoutSeconds) seconds."
                )
            }
            throw error
        }
        try await throwIfCallerCancelled(cancellationCheck)
        try throwIfDeadlineExceeded(
            deadline,
            backendID: backendID,
            timeoutSeconds: executionRequest.options.timeoutSeconds
        )
        guard result.result.backendID == backendID else {
            throw DRCError.backendFailed(
                "Backend '\(backendID)' returned result backend ID '\(result.result.backendID)'."
            )
        }
        let backendIdentity = backendIdentities[backendID] ?? backend.identity
        let expectedImplementationID = DRCExecutionProvenance.implementationID(for: backendIdentity)
        let expectedImplementationVersion = backendIdentity.toolVersion
            ?? DRCExecutionProvenance.implementationVersion(for: backendID)
        let expectedImplementationBuild: String
        if let executableDigest = backendIdentity.executableDigest {
            expectedImplementationBuild = executableDigest
        } else {
            expectedImplementationBuild = try DRCExecutionProvenance.currentExecutableDigest()
        }
        guard result.provenance.producer.kind == .engine,
              result.provenance.producer.identifier == expectedImplementationID,
              result.provenance.producer.version == expectedImplementationVersion,
              result.provenance.producer.build == expectedImplementationBuild else {
            throw DRCError.backendFailed(
                "Backend '\(backendID)' returned an execution producer that does not match its implementation identity and executable digest."
            )
        }
        guard result.provenance.invocation != nil,
              result.provenance.environment != nil else {
            throw DRCError.backendFailed(
                "Backend '\(backendID)' returned incomplete execution provenance."
            )
        }
        if result.provenance.inputs != executionRequest.executionInputArtifacts {
            throw DRCError.backendFailed(
                "Backend '\(backendID)' returned execution provenance for different input artifacts."
            )
        }
        result = withBackendIdentity(
            result,
            identity: backendIdentity
        )
        result = try applyWaivers(to: result)
        try throwIfDeadlineExceeded(
            deadline,
            backendID: backendID,
            timeoutSeconds: executionRequest.options.timeoutSeconds
        )
        if let directory = executionRequest.workingDirectory {
            let artifacts = try store.save(result, to: directory)
            try throwIfDeadlineExceeded(
                deadline,
                backendID: backendID,
                timeoutSeconds: executionRequest.options.timeoutSeconds
            )
            let integrityIssues = try DRCArtifactManifestVerifier().verify(
                manifestURL: artifacts.manifestURL,
                requireSignature: result.request.options.requireSignedArtifacts,
                trustedPublicKey: result.request.options.trustedArtifactPublicKey
            )
            try throwIfDeadlineExceeded(
                deadline,
                backendID: backendID,
                timeoutSeconds: executionRequest.options.timeoutSeconds
            )
            guard integrityIssues.isEmpty else {
                let issueCodes = integrityIssues.map(\.code).joined(separator: ",")
                throw DRCError.artifactWriteFailed(
                    "Persisted DRC artifact manifest failed integrity verification: \(issueCodes)"
                )
            }
            result = DRCExecutionResult(
                request: result.request,
                result: result.result,
                waiverReport: result.waiverReport,
                repairHintGeometry: result.repairHintGeometry,
                reportURL: artifacts.reportURL,
                artifactManifestURL: artifacts.manifestURL,
                artifactRunID: artifacts.runID,
                provenance: result.provenance
            )
        }
        return result
    }

    private func requestWithBoundInputArtifacts(_ request: DRCRequest) throws -> DRCRequest {
        guard request.executionInputArtifacts.isEmpty else {
            return request
        }
        return DRCRequest(
            layoutURL: request.layoutURL,
            topCell: request.topCell,
            layoutFormat: request.layoutFormat,
            technologyURL: request.technologyURL,
            waiverURL: request.waiverURL,
            workingDirectory: request.workingDirectory,
            backendSelection: request.backendSelection,
            options: request.options,
            designRevision: request.designRevision,
            canonicalStateDigest: request.canonicalStateDigest,
            executionInputArtifacts: try DRCExecutionProvenance.captureInputArtifacts(for: request)
        )
    }

    private func throwIfDeadlineExceeded(
        _ deadline: Date,
        backendID: String,
        timeoutSeconds: Double
    ) throws {
        guard Date() < deadline else {
            throw DRCError.timedOut(
                "DRC backend '\(backendID)' exceeded \(timeoutSeconds) seconds."
            )
        }
    }

    private func throwIfCallerCancelled(
        _ cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws {
        if Task.isCancelled {
            throw DRCError.cancelled("DRC execution was cancelled.")
        }
        if let cancellationCheck, try await cancellationCheck() {
            throw DRCError.cancelled("DRC execution was cancelled.")
        }
    }

    public func hasBackend(_ backendID: String) -> Bool {
        backends[backendID] != nil
    }

    public func backendIdentity(for backendID: String) -> DRCBackendIdentity? {
        backendIdentities[backendID]
    }

    private func applyWaivers(to executionResult: DRCExecutionResult) throws -> DRCExecutionResult {
        guard let waiverURL = executionResult.request.waiverURL else {
            return executionResult
        }
        let waiverFile = try loadWaiverFile(from: waiverURL)
        var usedWaiverIDs = Set<String>()
        var appliedWaivers: [DRCAppliedWaiver] = []
        let diagnostics = executionResult.result.diagnostics.map { diagnostic in
            guard diagnostic.severity == .error,
                  diagnostic.waiverID == nil,
                  let waiver = waiverFile.waivers.first(where: { matches(diagnostic: diagnostic, waiver: $0) }) else {
                return diagnostic
            }
            usedWaiverIDs.insert(waiver.id)
            appliedWaivers.append(DRCAppliedWaiver(
                waiverID: waiver.id,
                ruleID: diagnostic.ruleID,
                diagnosticMessage: diagnostic.message
            ))
            return diagnostic.applyingWaiver(waiver)
        }
        let result = DRCResult(
            backendID: executionResult.result.backendID,
            backendIdentity: executionResult.result.backendIdentity,
            toolName: executionResult.result.toolName,
            success: executionResult.result.success,
            completed: executionResult.result.completed,
            logPath: executionResult.result.logPath,
            diagnostics: diagnostics,
            provenance: executionResult.result.provenance
        )
        let report = DRCWaiverApplicationReport(
            waivedDiagnosticCount: appliedWaivers.count,
            appliedWaivers: appliedWaivers,
            unusedWaiverIDs: waiverFile.waivers.map(\.id).filter { !usedWaiverIDs.contains($0) }
        )
        return DRCExecutionResult(
            request: executionResult.request,
            result: result,
            waiverReport: report,
            repairHintGeometry: executionResult.repairHintGeometry,
            reportURL: executionResult.reportURL,
            artifactManifestURL: executionResult.artifactManifestURL,
            artifactRunID: executionResult.artifactRunID,
            provenance: executionResult.provenance
        )
    }

    private func withBackendIdentity(
        _ executionResult: DRCExecutionResult,
        identity: DRCBackendIdentity
    ) -> DRCExecutionResult {
        let result = DRCResult(
            backendID: executionResult.result.backendID,
            backendIdentity: identity,
            toolName: executionResult.result.toolName,
            success: executionResult.result.success,
            completed: executionResult.result.completed,
            logPath: executionResult.result.logPath,
            diagnostics: executionResult.result.diagnostics,
            provenance: executionResult.result.provenance
        )
        return DRCExecutionResult(
            request: executionResult.request,
            result: result,
            waiverReport: executionResult.waiverReport,
            repairHintGeometry: executionResult.repairHintGeometry,
            reportURL: executionResult.reportURL,
            artifactManifestURL: executionResult.artifactManifestURL,
            artifactRunID: executionResult.artifactRunID,
            provenance: executionResult.provenance
        )
    }

    private func loadWaiverFile(from url: URL) throws -> DRCWaiverFile {
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(DRCWaiverFile.self, from: data)
            let validationIssues = file.validate()
            guard validationIssues.isEmpty else {
                let issueSummary = validationIssues
                    .map { issue in
                        [issue.code, issue.waiverID, issue.fieldPath, issue.message]
                            .compactMap { $0 }
                            .joined(separator: " ")
                    }
                    .joined(separator: "; ")
                throw DRCError.waiverApplicationFailed("Waiver file failed validation: \(issueSummary)")
            }
            return file
        } catch let error as DRCError {
            throw error
        } catch {
            throw DRCError.waiverApplicationFailed(error.localizedDescription)
        }
    }

    private func matches(diagnostic: DRCDiagnostic, waiver: DRCWaiver) -> Bool {
        if let ruleID = waiver.ruleID, diagnostic.ruleID != ruleID {
            return false
        }
        if let kind = waiver.kind, diagnostic.kind != kind {
            return false
        }
        if let layer = waiver.layer, diagnostic.layer != layer {
            return false
        }
        if !waiver.relatedShapeIDs.isEmpty {
            let diagnosticShapeIDs = Set(diagnostic.relatedShapeIDs)
            guard Set(waiver.relatedShapeIDs).isSubset(of: diagnosticShapeIDs) else {
                return false
            }
        }
        if let messageContains = waiver.messageContains,
           !diagnostic.message.localizedCaseInsensitiveContains(messageContains) {
            return false
        }
        return true
    }
}
