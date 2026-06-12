import Foundation
import DRCCore
import DRCPureSwift
import DRCAdapters
import DRCPersistence

public struct DefaultDRCEngine: Sendable {
    private let backends: [String: any DRCBackend]
    private let store: DRCArtifactStore

    public init(
        backend: (any DRCBackend)? = MagicDRCAdapter.locate(),
        store: DRCArtifactStore = DRCArtifactStore()
    ) {
        var backends: [any DRCBackend] = [PureSwiftDRCBackend()]
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
        guard let backend = backends[request.backendSelection.backendID] else {
            throw DRCError.backendUnavailable("Unsupported DRC backend: \(request.backendSelection.backendID)")
        }
        var result = try await backend.run(request)
        if let directory = request.workingDirectory {
            let reportURL = try store.save(result, to: directory)
            result = DRCExecutionResult(request: result.request, result: result.result, reportURL: reportURL)
        }
        return result
    }
}
