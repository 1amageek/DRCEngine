import CircuiteFoundation
import DRCCore

extension DefaultDRCEngine: DRCEngineProtocol {
    public func execute(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request)
    }
}
