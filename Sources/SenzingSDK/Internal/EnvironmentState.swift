/// The lifecycle state an environment shares with its subsystems.
///
/// Subsystems hold this object, not the environment, so there is no
/// reference cycle; releasing the environment destroys it.
final class EnvironmentState: @unchecked Sendable {
    private let lock = ReadWriteLock()
    /// Read under the shared lock, written under the exclusive lock.
    private var destroyed = false
    private let configIDValue: Locked<Int64?>
    /// The worker pools of the `SzAsyncEngine`s over this environment, shut
    /// down (joined) before native teardown; `nil` once destroy has begun.
    private let workerPools = Locked<[WeakWorkerPool]?>([])
    /// Detects an engine call made from inside an engine call on one thread.
    private static let callDepth = ThreadDepth()
    /// A teardown requested from inside an SDK call, run when a call returns.
    private let deferredTeardown = Locked<(() -> Void)?>(nil)

    init(configID: Int64?) {
        configIDValue = Locked(configID)
    }

    var configID: Int64? {
        get { configIDValue.withLock { $0 } }
        set { configIDValue.withLock { $0 = newValue } }
    }

    var isDestroyed: Bool {
        lock.withReadLock { destroyed }
    }

    /// Runs a native call under the shared lock, failing with
    /// ``SzErrorKind/environmentDestroyed`` after ``destroy(_:)``.
    ///
    /// A call made from inside another call on the same thread (from a log
    /// callback) fails instead of nesting the shared lock, which would
    /// deadlock behind a waiting ``destroy(_:)``.
    func execute<T>(_ body: () throws(SzError) -> T) throws(SzError) -> T {
        if Self.callDepth.isInside {
            throw SzError(
                .general,
                message: "Re-entrant Senzing call: the SDK cannot be called from inside an SDK call "
                    + "(for example, from a log callback)."
            )
        }
        defer { runDeferredTeardown() }
        return try Self.callDepth.during { () throws(SzError) -> T in
            try lock.withReadLock { () throws(SzError) -> T in
                if destroyed {
                    throw Self.destroyedError
                }
                return try body()
            }
        }
    }

    /// Adds an `SzAsyncEngine` worker pool to shut down before native
    /// teardown; shuts it down at once if ``destroy(_:)`` has begun.
    func register(_ pool: EngineWorkerPool) {
        let registered = workerPools.withLock { pools in
            pools?.removeAll { $0.pool == nil }
            pools?.append(WeakWorkerPool(pool: pool))
            return pools != nil
        }
        if !registered {
            pool.shutdown(failing: Self.destroyedError)
        }
    }

    /// Shuts down the registered worker pools (queued calls fail, running
    /// calls finish, workers are joined), then runs `teardown` once, under the
    /// exclusive lock, after in-flight calls finish.
    ///
    /// Called from inside an SDK call on this thread (from a log callback),
    /// waiting would deadlock: the teardown runs as soon as an SDK call
    /// returns instead, and this returns at once.
    func destroy(_ teardown: @escaping () -> Void) {
        if Self.callDepth.isInside {
            deferredTeardown.withLock { $0 = teardown }
            return
        }
        let pools = workerPools.withLock { pools in
            defer { pools = nil }
            return pools ?? []
        }
        let live = pools.compactMap(\.pool)
        // Stop every pool before joining any, so no queued call waits on
        // another pool's running call.
        live.forEach { $0.stop(failing: Self.destroyedError) }
        live.forEach { $0.join() }
        lock.withWriteLock {
            if destroyed {
                return
            }
            teardown()
            destroyed = true
        }
    }

    private func runDeferredTeardown() {
        if let teardown = deferredTeardown.withLock({ pending in
            defer { pending = nil }
            return pending
        }) {
            destroy(teardown)
        }
    }

    static let destroyedError = SzError(
        .environmentDestroyed,
        message: "The Senzing environment has already been destroyed."
    )
}

private struct WeakWorkerPool {
    weak var pool: EngineWorkerPool?
}
