import Foundation
import Synchronization

/// One call queued on an ``EngineWorkerPool``.
///
/// Exactly one of ``run()`` (a worker claimed it), ``cancel()`` (the task was
/// cancelled while it waited) or ``fail(_:)`` (the pool shut down while it
/// waited) takes effect; the others do nothing.
final class EngineJob: Sendable {
    private let pending = Mutex(true)
    private let work: @Sendable () -> Void
    private let abandon: @Sendable (any Error) -> Void

    /// - Parameters:
    ///   - work: Runs the call and delivers its result, on a worker thread.
    ///   - abandon: Delivers an error instead; the call never runs.
    init(work: @escaping @Sendable () -> Void, abandon: @escaping @Sendable (any Error) -> Void) {
        self.work = work
        self.abandon = abandon
    }

    func run() {
        if claim() {
            work()
        }
    }

    func cancel() {
        fail(CancellationError())
    }

    func fail(_ error: any Error) {
        if claim() {
            abandon(error)
        }
    }

    private func claim() -> Bool {
        pending.withLock { pending in
            defer { pending = false }
            return pending
        }
    }
}

/// A fixed set of long-lived worker threads that run engine calls in FIFO
/// order.
///
/// The Senzing engine builds working state per OS thread on the thread's first
/// engine call and releases it when the thread exits, so the workers are
/// created once and reused. ``shutdown(failing:)`` fails the queued calls,
/// waits for the running ones, and joins every worker, so their per-thread
/// engine state is released before it returns.
final class EngineWorkerPool: @unchecked Sendable {
    let threadCount: Int

    private let condition = NSCondition()
    // Guarded by `condition`.
    private var queue: [EngineJob] = []
    private var head = 0
    /// Set by ``shutdown(failing:)``: the error later calls fail with.
    private var shutdownError: (any Error)?
    private var threads: [pthread_t] = []
    /// Serializes shutdowns, so every caller returns after the join.
    private let shutdownLock = NSLock()

    init(threadCount: Int, name: String) {
        self.threadCount = threadCount
        condition.lock()
        defer { condition.unlock() }
        for index in 0..<threadCount {
            if let thread = Self.startThread(WorkerContext(pool: self, name: "\(name)-\(index)")) {
                threads.append(thread)
            }
        }
    }

    /// The calls waiting for a worker.
    var pendingCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return queue.count - head
    }

    /// Whether ``shutdown(failing:)`` has started.
    var isShutDown: Bool {
        condition.lock()
        defer { condition.unlock() }
        return shutdownError != nil
    }

    /// Queues a job, or fails it with the shutdown error once the pool is
    /// shut down.
    func submit(_ job: EngineJob) {
        condition.lock()
        guard let shutdownError else {
            queue.append(job)
            condition.signal()
            condition.unlock()
            return
        }
        condition.unlock()
        job.fail(shutdownError)
    }

    /// Stops accepting calls, fails the queued ones with `error`, waits for the
    /// running ones, and joins the workers. Idempotent.
    func shutdown(failing error: any Error) {
        stop(failing: error)
        join()
    }

    /// Stops accepting calls and fails the queued ones with `error` (or with
    /// the error of an earlier stop). Does not wait.
    func stop(failing error: any Error) {
        condition.lock()
        let failure: any Error
        if let earlier = shutdownError {
            failure = earlier
        } else {
            shutdownError = error
            failure = error
        }
        let abandoned = queue[head...]
        queue = []
        head = 0
        condition.broadcast()
        condition.unlock()
        abandoned.forEach { $0.fail(failure) }
    }

    /// Waits for the running calls and joins the workers, after
    /// ``stop(failing:)``. Every caller returns after the join.
    ///
    /// Called from one of this pool's own workers, that worker is detached
    /// instead of joined (a thread cannot join itself).
    func join() {
        shutdownLock.lock()
        defer { shutdownLock.unlock() }
        condition.lock()
        let workers = threads
        threads = []
        condition.unlock()
        for worker in workers {
            if pthread_equal(worker, pthread_self()) != 0 {
                pthread_detach(worker)
            } else {
                pthread_join(worker, nil)
            }
        }
    }

    /// The worker loop: run jobs until shut down and the queue is empty.
    fileprivate func work() {
        while let job = nextJob() {
            job.run()
        }
    }

    private func nextJob() -> EngineJob? {
        condition.lock()
        defer { condition.unlock() }
        while head == queue.count && shutdownError == nil {
            condition.wait()
        }
        guard head < queue.count else {
            return nil
        }
        let job = queue[head]
        head += 1
        if head == queue.count {
            // Drained: reuse the storage.
            queue.removeAll(keepingCapacity: true)
            head = 0
        }
        return job
    }

    /// The worker stack size: as large as a main thread's, since native engine
    /// calls run on it.
    private static let stackSize = 8 << 20

    private static func startThread(_ context: WorkerContext) -> pthread_t? {
        var attributes = pthread_attr_t()
        pthread_attr_init(&attributes)
        defer { pthread_attr_destroy(&attributes) }
        pthread_attr_setstacksize(&attributes, stackSize)
        let argument = Unmanaged.passRetained(context).toOpaque()
        #if canImport(Darwin)
        var thread: pthread_t?
        #else
        var thread = pthread_t()
        #endif
        let status = pthread_create(&thread, &attributes, { WorkerContext.main($0) }, argument)
        // Fails only when the system is out of threads or memory.
        precondition(status == 0)
        return thread
    }
}

/// What a worker thread is started with.
private final class WorkerContext {
    let pool: EngineWorkerPool
    let name: String

    init(pool: EngineWorkerPool, name: String) {
        self.pool = pool
        self.name = name
    }

    static func main(_ argument: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
        argument.map { Unmanaged<WorkerContext>.fromOpaque($0).takeRetainedValue() }?.run()
        return nil
    }

    private func run() {
        Thread.current.name = name
        pool.work()
    }
}
