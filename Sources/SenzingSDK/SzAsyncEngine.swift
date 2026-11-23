import Foundation
import Synchronization

/// ``SzEngine`` for Swift concurrency: every engine method as an `async`
/// method that runs on a fixed pool of worker threads.
///
/// The Senzing engine is synchronous: each call blocks its thread until it
/// finishes. `SzAsyncEngine` is a Swift-only convenience, with no counterpart
/// in the official Senzing SDKs, that keeps that blocking work off the main
/// actor and off Swift's cooperative thread pool. `await` does not make a call
/// faster or non-blocking.
///
/// ```swift
/// let engine = SzAsyncEngine(try environment.getEngine())
/// try await engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1001", recordDefinition: json)
/// let entity = try await engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
/// ```
///
/// ## Worker threads
///
/// The engine builds working state per OS thread on the thread's first call
/// and releases it when the thread exits. `SzAsyncEngine` therefore creates
/// ``maxConcurrentCalls`` long-lived worker threads once and runs every call
/// on one of them, in submission order. At most that many calls run at once,
/// in parallel inside the engine, which is thread-safe. The workers are joined
/// when the environment is destroyed (before native teardown), on
/// ``shutdown()``, or when the `SzAsyncEngine` is released.
///
/// ## Cancellation
///
/// A call whose task is cancelled before a worker picks it up throws
/// `CancellationError` and never reaches the engine. A call a worker has
/// started cannot be interrupted: it runs to completion, and its changes are
/// committed.
///
/// ## Errors
///
/// The methods throw the engine's ``SzError``, `CancellationError`, or, after
/// the environment is destroyed or ``shutdown()``, an ``SzError`` of kind
/// ``SzErrorKind/environmentDestroyed`` or ``SzErrorKind/general``.
/// `catch SzError.notFound`-style patterns work as for the synchronous API.
///
/// Every ``SzEngine`` method has an `async` counterpart here, generated from
/// the ``SzEngine`` declarations by `tools/generate-async-engine.swift`. Any
/// other work with the engine runs through ``perform(_:)``.
public final class SzAsyncEngine: Sendable {
    /// The default ``maxConcurrentCalls``: the active processor count, at most
    /// 4.
    ///
    /// Each engine thread holds its own native working state (Senzing's
    /// published guidance sizes it at 0.5–1 GB per engine thread), so the
    /// default stays small enough for desktop and mobile memory. A server
    /// loading data should raise it: Senzing's guidance for loading is 2–8
    /// threads per CPU core, tuned to the storage. More threads do not raise
    /// throughput on SQLite, which allows one writer at a time.
    public static let defaultMaxConcurrentCalls = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 4))

    /// The wrapped synchronous engine.
    public let engine: any SzEngine
    /// The number of worker threads: the most calls that run at once.
    public let maxConcurrentCalls: Int

    let workers: EngineWorkerPool

    /// Wraps an engine and starts its worker threads.
    ///
    /// - Parameters:
    ///   - engine: The engine to run calls on.
    ///   - maxConcurrentCalls: The number of worker threads; defaults to
    ///     ``defaultMaxConcurrentCalls``.
    public init(_ engine: any SzEngine, maxConcurrentCalls: Int? = nil) {
        self.engine = engine
        self.maxConcurrentCalls = max(1, maxConcurrentCalls ?? Self.defaultMaxConcurrentCalls)
        workers = EngineWorkerPool(threadCount: self.maxConcurrentCalls, name: "sz-async-engine")
        (engine as? SzCoreEngine)?.state.register(workers)
    }

    deinit {
        workers.shutdown(failing: Self.shutdownError)
    }

    /// Stops the worker threads: queued calls fail, running calls finish, and
    /// the workers are joined before this returns. Later calls throw. The
    /// environment's `destroy()` does this for you.
    ///
    /// Blocks until the running calls finish. Idempotent.
    public func shutdown() {
        workers.shutdown(failing: Self.shutdownError)
    }

    /// Whether the workers are shut down (by ``shutdown()`` or the
    /// environment's `destroy()`).
    public var isShutDown: Bool {
        workers.isShutDown
    }

    /// Runs `operation` with the engine on a worker thread and returns its
    /// result.
    ///
    /// - Throws: What `operation` throws; `CancellationError` if the task is
    ///   cancelled before a worker starts the call; an ``SzError`` once the
    ///   workers are shut down.
    @discardableResult
    public func perform<T: Sendable>(
        _ operation: @escaping @Sendable (any SzEngine) throws -> T
    ) async throws -> T {
        let engine = self.engine
        let slot = JobSlot()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let job = EngineJob(
                    work: { continuation.resume(with: Result { try operation(engine) }) },
                    abandon: { continuation.resume(throwing: $0) }
                )
                // onCancel may run before or after this point: either it finds
                // the job here, or the job sees the cancellation itself.
                if slot.install(job) || Task.isCancelled {
                    job.cancel()
                }
                workers.submit(job)
            }
        } onCancel: {
            slot.cancel()
        }
    }

    /// Processes pending redo records, on one worker, until none remain;
    /// returns how many ran.
    @discardableResult
    public func processRedoRecords() async throws -> Int {
        try await perform { engine in
            var processed = 0
            while let redo = try engine.getRedoRecord() {
                try engine.processRedoRecord(redo, flags: [])
                processed += 1
            }
            return processed
        }
    }

    static let shutdownError = SzError(.general, message: "The SzAsyncEngine has been shut down.")
}

/// Connects a task's cancellation handler to its queued job.
private final class JobSlot: Sendable {
    private struct State {
        var job: EngineJob?
        var cancelled = false
    }

    private let state = Mutex(State())

    /// Records the job; returns whether the task was already cancelled.
    func install(_ job: EngineJob) -> Bool {
        state.withLock { state in
            state.job = job
            return state.cancelled
        }
    }

    /// Cancels the job if it is installed (and still waiting for a worker).
    func cancel() {
        let job = state.withLock { state in
            state.cancelled = true
            return state.job
        }
        job?.cancel()
    }
}
