import CSenzing

/// The native Senzing modules; each keeps its own last-exception state.
enum NativeComponent: Sendable {
    case engine
    case config
    case configManager
    case diagnostic
    case product
}

/// Helpers for calling the Senzing C API.
///
/// The native last-exception state is per thread, so an error must be read on
/// the thread that made the failing call: every helper here runs synchronously
/// right after the native call.
enum Native {
    /// Size of the buffer used to read a native error message.
    static let exceptionBufferSize = 4096

    /// Reads and clears the last native error of `component`.
    static func lastError(_ component: NativeComponent) -> SzError {
        var buffer = [CChar](repeating: 0, count: exceptionBufferSize)
        let errorCode: Int64
        let copied: Int64
        switch component {
        case .engine:
            errorCode = Sz_getLastExceptionCode()
            copied = Sz_getLastException(&buffer, buffer.count)
            Sz_clearLastException()
        case .config:
            errorCode = SzConfig_getLastExceptionCode()
            copied = SzConfig_getLastException(&buffer, buffer.count)
            SzConfig_clearLastException()
        case .configManager:
            errorCode = SzConfigMgr_getLastExceptionCode()
            copied = SzConfigMgr_getLastException(&buffer, buffer.count)
            SzConfigMgr_clearLastException()
        case .diagnostic:
            errorCode = SzDiagnostic_getLastExceptionCode()
            copied = SzDiagnostic_getLastException(&buffer, buffer.count)
            SzDiagnostic_clearLastException()
        case .product:
            errorCode = SzProduct_getLastExceptionCode()
            copied = SzProduct_getLastException(&buffer, buffer.count)
            SzProduct_clearLastException()
        }
        let message = copied > 0 ? string(from: buffer) : ""
        return SzError(errorCode: errorCode, message: message)
    }

    /// Throws the last native error of `component` when `returnCode` is non-zero.
    static func check(_ returnCode: Int64, _ component: NativeComponent) throws(SzError) {
        if returnCode != 0 {
            throw lastError(component)
        }
    }

    /// Takes ownership of a helper response buffer: frees it with
    /// `SzHelper_free` (also on failure) and returns its text, or throws the
    /// native error when `returnCode` is non-zero.
    static func take(
        _ response: UnsafeMutablePointer<CChar>?,
        _ returnCode: Int64,
        _ component: NativeComponent
    ) throws(SzError) -> String {
        defer {
            if let response {
                SzHelper_free(response)
            }
        }
        try check(returnCode, component)
        guard let response else {
            return ""
        }
        return String(cString: response)
    }

    /// Validates a native count: a negative value is a native error code.
    static func count(_ value: Int64, _ component: NativeComponent) throws(SzError) -> Int64 {
        if value < 0 {
            throw lastError(component)
        }
        return value
    }

    /// Copies a string the engine owns (it is not freed), or throws the last
    /// native error when the engine returned NULL.
    static func borrowedString(
        _ pointer: UnsafePointer<CChar>?, _ component: NativeComponent
    ) throws(SzError)
        -> String
    {
        guard let pointer else {
            throw lastError(component)
        }
        return String(cString: pointer)
    }

    /// Reads the text before the first NUL (or the whole buffer when it has none).
    static func string(from buffer: [CChar]) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
