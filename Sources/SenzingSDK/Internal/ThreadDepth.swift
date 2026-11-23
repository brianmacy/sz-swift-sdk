import Foundation

/// A per-thread nesting counter, used to detect re-entrant calls on the
/// current thread (a log callback, or an engine call inside an engine call).
final class ThreadDepth: Sendable {
    private let key: pthread_key_t

    init() {
        var key = pthread_key_t()
        pthread_key_create(&key, nil)
        self.key = key
    }

    /// Whether the current thread is inside ``during(_:)``.
    var isInside: Bool {
        pthread_getspecific(key) != nil
    }

    /// Runs `body` one level deeper on the current thread.
    func during<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        let depth = Int(bitPattern: pthread_getspecific(key))
        pthread_setspecific(key, UnsafeRawPointer(bitPattern: depth + 1))
        defer { pthread_setspecific(key, UnsafeRawPointer(bitPattern: depth)) }
        return try body()
    }
}
