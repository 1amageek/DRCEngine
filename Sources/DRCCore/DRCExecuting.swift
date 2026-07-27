import CircuiteFoundation

/// DRC execution contract shared by standalone and composed consumers.
public protocol DRCExecuting: Engine
where Request == DRCRequest, Output == DRCExecutionResult {
    func run(_ request: DRCRequest) async throws -> DRCExecutionResult

    func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult
}

public extension DRCExecuting {
    func execute(_ request: DRCRequest) async throws -> DRCExecutionResult {
        try await run(request)
    }

    func run(
        _ request: DRCRequest,
        cancellationCheck: DRCExecutionCancellationCheck?
    ) async throws -> DRCExecutionResult {
        try await run(request)
    }
}

extension DRCRequest {
    /// Returns the unresolved physical path for the requested top cell.
    public func designSubjectReference() throws -> DesignSubjectReference {
        .path(
            try DesignPathReference(
                facetID: DesignFacetID(rawValue: "physical"),
                kindID: DesignEntityKindID(rawValue: "cell"),
                localIdentifier: topCell
            )
        )
    }
}
