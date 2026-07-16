import CircuiteFoundation

/// DRC execution contract shared by standalone and composed consumers.
public protocol DRCExecuting: Engine
where Request == DRCRequest, Output == DRCExecutionResult {
    func run(_ request: DRCRequest) async throws -> DRCExecutionResult
}

extension DRCRequest {
    /// Returns the Foundation hierarchy identity for the requested top cell.
    public func designObjectReference() throws -> DesignObjectReference {
        try DesignObjectReference(kind: .cell, identifier: topCell)
    }
}
