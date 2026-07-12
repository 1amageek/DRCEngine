import Foundation
import DRCCore

/// Actor-isolated lifecycle for a resumable corpus execution.
public actor DRCCorpusRunSession {
    public nonisolated let events: AsyncStream<DRCCorpusRunEvent>

    private let runner: DRCCorpusRunner
    private let specURL: URL
    private let outputDirectory: URL
    private let options: DRCCorpusRunOptions
    private let continuation: AsyncStream<DRCCorpusRunEvent>.Continuation
    private var task: Task<DRCCorpusReport, Error>?
    private var state: DRCCorpusRunSessionState = .idle

    public init(
        runner: DRCCorpusRunner = DRCCorpusRunner(),
        specURL: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions = DRCCorpusRunOptions()
    ) {
        let streamPair = AsyncStream<DRCCorpusRunEvent>.makeStream()
        self.events = streamPair.stream
        self.continuation = streamPair.continuation
        self.runner = runner
        self.specURL = specURL
        self.outputDirectory = outputDirectory
        self.options = options
    }

    public func start() {
        guard state == .idle else { return }
        state = .running
        task = Task { [weak self, runner, specURL, outputDirectory, options] in
            try await runner.run(
                specURL: specURL,
                outputDirectory: outputDirectory,
                options: options,
                eventHandler: { [weak self] event in
                    await self?.forward(event)
                }
            )
        }
        guard let task else { return }
        Task { [weak self] in
            await self?.finish(task: task)
        }
    }

    public func cancel() {
        guard state == .running else { return }
        task?.cancel()
    }

    public func shutdown() {
        if state == .running {
            state = .cancelled
            continuation.yield(.cancelled(runID: options.runID ?? "unknown"))
        }
        task?.cancel()
        continuation.finish()
    }

    public func currentState() -> DRCCorpusRunSessionState {
        state
    }

    public func wait() async throws -> DRCCorpusReport {
        guard let task else {
            throw DRCError.invalidInput("DRC corpus run session has not started.")
        }
        return try await task.value
    }

    private func forward(_ event: DRCCorpusRunEvent) {
        continuation.yield(event)
    }

    private func finish(task: Task<DRCCorpusReport, Error>) async {
        do {
            _ = try await task.value
            guard state != .cancelled else {
                continuation.finish()
                return
            }
            state = .succeeded
        } catch is CancellationError {
            if state != .cancelled {
                state = .cancelled
                continuation.yield(.cancelled(runID: options.runID ?? "unknown"))
            }
        } catch {
            if state != .cancelled {
                state = .failed
            }
        }
        continuation.finish()
    }
}
