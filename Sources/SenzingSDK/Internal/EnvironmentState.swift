/// The lifecycle state an environment shares with its subsystems.
///
/// Subsystems hold this object, not the environment, so there is no
/// reference cycle; releasing the environment destroys it.
final class EnvironmentState: @unchecked Sendable {
    private let lock = ReadWriteLock()
    /// Read under the shared lock, written under the exclusive lock.
    private var destroyed = false
    private let configIDValue: Locked<Int64?>

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
    /// Must not be nested: a reader waiting behind a writer would deadlock.
    func execute<T>(_ body: () throws(SzError) -> T) throws(SzError) -> T {
        try lock.withReadLock { () throws(SzError) -> T in
            if destroyed {
                throw Self.destroyedError
            }
            return try body()
        }
    }

    /// Runs `teardown` once, under the exclusive lock, after in-flight calls finish.
    func destroy(_ teardown: () -> Void) {
        lock.withWriteLock {
            if destroyed {
                return
            }
            teardown()
            destroyed = true
        }
    }

    static let destroyedError = SzError(
        .environmentDestroyed,
        message: "The Senzing environment has already been destroyed."
    )
}
