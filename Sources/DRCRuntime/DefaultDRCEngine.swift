import Foundation
import DRCCore
import DRCNative
import DRCAdapters
import DRCPersistence

public struct DefaultDRCEngine: Sendable {
    private let backends: [String: any DRCBackend]
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
        for backend in backends {
            backendsByID[backend.backendID] = backend
        }
        self.backends = backendsByID
        self.store = store
    }

    public func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request, cancellationCheck: nil)
    }

    public func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult {
        let backendID = Self.canonicalBackendID(request.backendSelection.backendID)
        guard let backend = backends[backendID] else {
            throw DRCError.backendUnavailable("Unsupported DRC backend: \(request.backendSelection.backendID)")
        }
        var result: DRCExecutionResult
        if let cancellableBackend = backend as? any DRCCancellableBackend {
            result = try await cancellableBackend.run(request, cancellationCheck: cancellationCheck)
        } else {
            result = try await backend.run(request)
        }
        result = try applyWaivers(to: result)
        if let directory = request.workingDirectory {
            let artifacts = try store.save(result, to: directory)
            result = DRCExecutionResult(
                request: result.request,
                result: result.result,
                waiverReport: result.waiverReport,
                repairHintGeometry: result.repairHintGeometry,
                reportURL: artifacts.reportURL,
                artifactManifestURL: artifacts.manifestURL
            )
        }
        return result
    }

    private static func canonicalBackendID(_ backendID: String) -> String {
        switch backendID {
        // Legacy aliases are accepted so persisted run specs remain resumable.
        case "pure-swift":
            return "native"
        case "pure-swift-gds":
            return "native-gds"
        default:
            return backendID
        }
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
            artifactManifestURL: executionResult.artifactManifestURL
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
