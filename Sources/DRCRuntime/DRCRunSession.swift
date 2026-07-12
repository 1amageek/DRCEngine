import Foundation
import DRCCore

/// Actor-isolated lifecycle for one bounded DRC execution.
public actor DRCRunSession {
    public nonisolated let events: AsyncStream<DRCRunEvent>

    private let engine: DefaultDRCEngine
    private let request: DRCRequest
    private let continuation: AsyncStream<DRCRunEvent>.Continuation
    private var task: Task<DRCExecutionResult, Error>?
    private var state: DRCRunSessionState = .idle
    private var cancellationReason: String?

    public init(engine: DefaultDRCEngine = DefaultDRCEngine(), request: DRCRequest) {
        let streamPair = AsyncStream<DRCRunEvent>.makeStream()
        self.events = streamPair.stream
        self.continuation = streamPair.continuation
        self.engine = engine
        self.request = request
    }

    public func start() {
        guard state == .idle else { return }
        state = .running
        continuation.yield(.started(at: Date()))
        continuation.yield(.stateChanged(.running))
        task = Task { [weak self, engine, request] in
            try await engine.run(request) { [weak self] in
                guard let self else { return Task.isCancelled }
                return await self.isCancellationRequested()
            }
        }
        guard let task else { return }
        Task { [weak self] in
            await self?.finish(task: task)
        }
    }

    public func cancel(reason: String = "DRC run cancellation requested.") {
        guard state == .running else { return }
        cancellationReason = reason
        task?.cancel()
    }

    public func shutdown() {
        if state == .running {
            let reason = cancellationReason ?? "DRC run session shutdown requested."
            cancellationReason = reason
            state = .cancelled
            continuation.yield(.cancelled(reason: reason))
            continuation.yield(.stateChanged(.cancelled))
        }
        task?.cancel()
        continuation.finish()
    }

    public func currentState() -> DRCRunSessionState {
        state
    }

    public func wait() async throws -> DRCExecutionResult {
        guard let task else {
            throw DRCError.invalidInput("DRC run session has not started.")
        }
        return try await task.value
    }

    private func isCancellationRequested() -> Bool {
        cancellationReason != nil
    }

    private func finish(task: Task<DRCExecutionResult, Error>) async {
        do {
            let result = try await task.value
            if state == .cancelled {
                continuation.finish()
                return
            }
            if let cancellationReason {
                state = .cancelled
                continuation.yield(.cancelled(reason: cancellationReason))
                continuation.yield(.stateChanged(.cancelled))
            } else {
                state = .succeeded
                continuation.yield(.completed(result))
                continuation.yield(.stateChanged(.succeeded))
            }
        } catch is CancellationError {
            if state == .cancelled {
                continuation.finish()
                return
            }
            let reason = cancellationReason ?? "DRC run task was cancelled."
            state = .cancelled
            continuation.yield(.cancelled(reason: reason))
            continuation.yield(.stateChanged(.cancelled))
        } catch let error as DRCError {
            if state == .cancelled {
                continuation.finish()
                return
            }
            if case .cancelled(let message) = error {
                let reason = cancellationReason ?? message
                state = .cancelled
                continuation.yield(.cancelled(reason: reason))
                continuation.yield(.stateChanged(.cancelled))
            } else {
                state = .failed
                continuation.yield(.failed(message: error.localizedDescription))
                continuation.yield(.stateChanged(.failed))
            }
        } catch {
            if state == .cancelled {
                continuation.finish()
                return
            }
            state = .failed
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.yield(.stateChanged(.failed))
        }
        continuation.finish()
    }
}
