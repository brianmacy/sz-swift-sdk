import CSenzing
import Foundation
import Synchronization

/// The ``SzLogging`` over the native `libSzLogging` API, mirroring the C#
/// `SzCoreLogging`.
///
/// There is one instance per process (``getInstance()``), also returned by
/// ``SzEnvironment/getLogging()``.
public final class SzCoreLogging: SzLogging {
    private static let instance = SzCoreLogging()

    private init() {}

    /// Returns the process-wide logging controls (C# `GetInstance`).
    public static func getInstance() -> SzCoreLogging {
        instance
    }

    public func registerCallback(
        _ options: SzLogCallbackOptions,
        _ callback: @escaping SzLogCallback
    ) throws(SzError) -> any SzLogRegistration {
        try LogCallbackDepth.refuseInside("registering a log callback")
        let slot = LogCallbackSlot(callback)
        let userData = Unmanaged.passRetained(slot).toOpaque()
        let handle = SzLogging_registerCallbackWithFormat(
            logTrampoline,
            userData,
            options.minLevel.rawValue,
            options.format.rawValue
        )
        return try SzCoreLogRegistration.adopt(handle, slot: slot)
    }

    public func setDefaultCallback(
        _ options: SzLogCallbackOptions,
        _ callback: @escaping SzLogCallback
    ) throws(SzError) {
        try LogCallbackDepth.refuseInside("setDefaultCallback")
        // Retained for the process lifetime: native has no release hook for a
        // replaced default callback.
        let userData = Unmanaged.passRetained(LogCallbackSlot(callback)).toOpaque()
        _ = SzLogging_setDefaultCallback(logTrampoline, userData, options.minLevel.rawValue)
        // setDefaultCallback installs the legacy format; apply the requested one.
        if options.format != .legacy {
            SzLogging_setDefaultFormatter(options.format.rawValue)
        }
    }

    public func setDefaultOutput(_ output: SzLogOutput) throws(SzError) {
        try LogCallbackDepth.refuseInside("setDefaultOutput")
        guard case .file(let file) = output else {
            SzLogging_setDefaultOutput(output.outputType.rawValue, nil)
            return
        }
        let path = try Self.writableLogFile(file)
        SzLogging_setDefaultOutput(output.outputType.rawValue, path)
    }

    public func setDefaultFormat(_ format: SzLogFormat) throws(SzError) {
        try LogCallbackDepth.refuseInside("setDefaultFormat")
        SzLogging_setDefaultFormatter(format.rawValue)
    }

    public func setDefaultLogLevel(_ level: SzLogLevel) {
        SzLogging_setLogLevel(level.rawValue)
    }

    public func getEffectiveLogLevel() -> SzLogLevel {
        // Native returns a SzLogLevel value; clamp so the result is total.
        SzLogLevel.allCases[Int(min(max(SzLogging_getLogLevel(), 0), SzLogLevel.off.rawValue))]
    }

    /// Validates a log file path: creates its parent directories and opens it
    /// for appending, so an unusable path is reported instead of native
    /// silently dropping output.
    static func writableLogFile(_ path: String) throws(SzError) -> String {
        if path.isEmpty || path.contains("\0") {
            throw SzError(.badInput, message: "Log file path must be non-empty and contain no NUL: \"\(path)\"")
        }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        guard let file = fopen(path, "a") else {
            let reason = String(cString: strerror(errno))
            throw SzError(.badInput, message: "Cannot open log file \"\(path)\" for appending: \(reason)")
        }
        fclose(file)
        return path
    }
}

/// One registration's callback, passed to native as `user_data`.
final class LogCallbackSlot: Sendable {
    let callback: SzLogCallback
    let active = Atomic(true)

    init(_ callback: @escaping SzLogCallback) {
        self.callback = callback
    }

    /// Delivers a native message unless the registration was deactivated.
    func deliver(level: Int32, module: UnsafePointer<CChar>, message: UnsafePointer<CChar>) {
        // Out of range, or OFF (a filter value, never a message level): drop.
        guard active.load(ordering: .acquiring), let level = SzLogLevel(rawValue: level), level != .off else {
            return
        }
        let record = SzLogRecord(level: level, rawModule: String(cString: module), message: String(cString: message))
        LogCallbackDepth.during { callback(record) }
    }
}

/// The native entry point for every registration; `userData` is the
/// registration's own ``LogCallbackSlot``.
let logTrampoline: NativeLogCallback = { level, module, message, userData in
    guard let module, let message, let userData else {
        return
    }
    Unmanaged<LogCallbackSlot>.fromOpaque(userData).takeUnretainedValue()
        .deliver(level: level, module: module, message: message)
}

/// The C `SzLogCallback` signature from `libSzLogging.h`.
typealias NativeLogCallback =
    @convention(c) (
        Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?
    ) -> Void

final class SzCoreLogRegistration: SzLogRegistration {
    /// Wraps a native registration handle, or releases `slot` (retained once
    /// as native `user_data`) and throws when native refused it.
    static func adopt(
        _ handle: UnsafeMutableRawPointer?, slot: LogCallbackSlot
    ) throws(SzError) -> SzCoreLogRegistration {
        guard let handle else {
            Unmanaged.passUnretained(slot).release()
            throw SzError(.unrecoverable, message: "SzLogging_registerCallbackWithFormat: registration refused")
        }
        return SzCoreLogRegistration(handle: handle, slot: slot)
    }

    private enum State {
        case registered(UnsafeMutableRawPointer)
        case released
    }

    private let slot: LogCallbackSlot
    private let state: Locked<State>

    init(handle: UnsafeMutableRawPointer, slot: LogCallbackSlot) {
        self.slot = slot
        self.state = Locked(.registered(handle))
    }

    deinit {
        unregister()
    }

    var isRegistered: Bool {
        slot.active.load(ordering: .acquiring)
    }

    func unregister() {
        guard let handle = take() else {
            return
        }
        slot.active.store(false, ordering: .releasing)
        if LogCallbackDepth.isInside {
            // Native cannot unregister from inside a callback: delivery is
            // already off, and the slot stays retained for the process.
            return
        }
        SzLogging_unregisterCallback(handle)
        Unmanaged.passUnretained(slot).release()
    }

    func leak() {
        _ = take()
    }

    /// Takes the native handle, leaving the registration released.
    private func take() -> UnsafeMutableRawPointer? {
        state.withLock { state in
            guard case .registered(let handle) = state else {
                return nil
            }
            state = .released
            return handle
        }
    }
}

/// How deep the current thread is inside SDK log callbacks.
enum LogCallbackDepth {
    private static let key: pthread_key_t = {
        var key = pthread_key_t()
        pthread_key_create(&key, nil)
        return key
    }()

    static var isInside: Bool {
        pthread_getspecific(key) != nil
    }

    static func during(_ body: () -> Void) {
        let depth = Int(bitPattern: pthread_getspecific(key))
        pthread_setspecific(key, UnsafeRawPointer(bitPattern: depth + 1))
        defer { pthread_setspecific(key, UnsafeRawPointer(bitPattern: depth)) }
        body()
    }

    static func refuseInside(_ operation: String) throws(SzError) {
        if isInside {
            throw SzError(.configuration, message: "\(operation) is not allowed inside a log callback")
        }
    }
}
