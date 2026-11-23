import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// A readers-writer lock: engine calls share it, `destroy()` takes it
/// exclusively so it waits for in-flight calls to finish.
final class ReadWriteLock: @unchecked Sendable {
    private let lock: UnsafeMutablePointer<pthread_rwlock_t>

    init() {
        lock = .allocate(capacity: 1)
        lock.initialize(to: pthread_rwlock_t())
        pthread_rwlock_init(lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(lock)
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func withReadLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        pthread_rwlock_rdlock(lock)
        defer { pthread_rwlock_unlock(lock) }
        return try body()
    }

    func withWriteLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        pthread_rwlock_wrlock(lock)
        defer { pthread_rwlock_unlock(lock) }
        return try body()
    }
}

/// A value protected by a mutex.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T, E: Error>(_ body: (inout Value) throws(E) -> T) throws(E) -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
