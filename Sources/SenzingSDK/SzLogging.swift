import Foundation

/// A native log severity, from most to least verbose, mirroring the C#
/// `SzLogLevel` (`libSzLogging.h` `SzLogLevel`).
///
/// Levels are ordered, so `level >= .warn` reads naturally. ``off`` is a
/// filter value only: no message is ever logged at it.
public enum SzLogLevel: Int32, CaseIterable, Comparable, Sendable, CustomStringConvertible {
    /// `SZ_LOG_LEVEL_TRACE`: execution flow.
    case trace = 0
    /// `SZ_LOG_LEVEL_DEBUG`: debug information.
    case debug = 1
    /// `SZ_LOG_LEVEL_INFO`: informational messages.
    case info = 2
    /// `SZ_LOG_LEVEL_WARN`: warnings.
    case warn = 3
    /// `SZ_LOG_LEVEL_ERROR`: errors.
    case error = 4
    /// `SZ_LOG_LEVEL_CRITICAL`: critical errors.
    case critical = 5
    /// `SZ_LOG_LEVEL_OFF`: disables logging.
    case off = 6

    /// Parses a level name, mirroring C# `ParseSzLogLevel`.
    ///
    /// Case-insensitive; surrounding whitespace is ignored and `WARNING` is
    /// accepted for ``warn``.
    ///
    /// - Throws: ``SzErrorKind/badInput`` for an unknown name.
    public init(parsing text: String) throws(SzError) {
        var name = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if name == "WARNING" {
            name = "WARN"
        }
        guard let level = Self.allCases.first(where: { $0.description == name }) else {
            throw SzError(.badInput, message: "Unknown log level: \"\(text)\"")
        }
        self = level
    }

    /// The canonical upper-case name: `TRACE`, `DEBUG`, `INFO`, `WARN`,
    /// `ERROR`, `CRITICAL` or `OFF`.
    public var description: String {
        switch self {
        case .trace: "TRACE"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warn: "WARN"
        case .error: "ERROR"
        case .critical: "CRITICAL"
        case .off: "OFF"
        }
    }

    public static func < (lhs: SzLogLevel, rhs: SzLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// How native formats a log message, mirroring the C# `SzLogFormat`
/// (`libSzLogging.h` `SzLogFormat`).
public enum SzLogFormat: Int32, CaseIterable, Sendable, CustomStringConvertible {
    /// `SZ_LOG_FORMAT_LEGACY`: `YYYY-MM-DD HH:MM:SS.mmm [module:hash] SEV: msg`.
    case legacy = 0
    /// `SZ_LOG_FORMAT_JSONL`: one JSON object per message.
    case jsonl = 1
    /// `SZ_LOG_FORMAT_BARE`: the message only, no metadata.
    case bare = 2
    /// `SZ_LOG_FORMAT_DEFAULT`: the raw payload, unformatted.
    case `default` = 3

    /// Parses a format name, mirroring C# `ParseSzLogFormat`.
    ///
    /// Case-insensitive; surrounding whitespace is ignored and `JSON` is
    /// accepted for ``jsonl``.
    ///
    /// - Throws: ``SzErrorKind/badInput`` for an unknown name.
    public init(parsing text: String) throws(SzError) {
        var name = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if name == "JSON" {
            name = "JSONL"
        }
        guard let format = Self.allCases.first(where: { $0.description == name }) else {
            throw SzError(.badInput, message: "Unknown log format: \"\(text)\"")
        }
        self = format
    }

    /// The canonical upper-case name: `LEGACY`, `JSONL`, `BARE` or `DEFAULT`.
    public var description: String {
        switch self {
        case .legacy: "LEGACY"
        case .jsonl: "JSONL"
        case .bare: "BARE"
        case .default: "DEFAULT"
        }
    }
}

/// Where the default sink writes, mirroring the C# `SzLogOutputType`
/// (`libSzLogging.h` `SzLogOutputType`).
public enum SzLogOutputType: Int32, CaseIterable, Sendable {
    /// `SZ_LOG_OUTPUT_STDERR`: standard error (the native default).
    case stderr = 0
    /// `SZ_LOG_OUTPUT_STDOUT`: standard output.
    case stdout = 1
    /// `SZ_LOG_OUTPUT_FILE`: a file, truncated when opened.
    case file = 2
    /// `SZ_LOG_OUTPUT_NULL`: discarded (registered callbacks still receive).
    case null = 3
}

/// A default-sink destination for ``SzLogging/setDefaultOutput(_:)``,
/// mirroring the C# `SzLogOutput`.
public enum SzLogOutput: Hashable, Sendable {
    /// Standard error (the native default).
    case stderr
    /// Standard output.
    case stdout
    /// Discard default output; registered callbacks still receive messages.
    case null
    /// A file, created (with its parent directories) if missing. Native
    /// truncates an existing file when it opens it.
    case file(String)

    /// The destination kind.
    public var outputType: SzLogOutputType {
        switch self {
        case .stderr: .stderr
        case .stdout: .stdout
        case .null: .null
        case .file: .file
        }
    }

    /// The file path for ``file(_:)``; `nil` otherwise.
    public var path: String? {
        if case .file(let path) = self {
            return path
        }
        return nil
    }
}

/// The level and format a log callback receives, mirroring the C#
/// `SzLogCallbackOptions`.
public struct SzLogCallbackOptions: Hashable, Sendable {
    /// Messages below this level are filtered out.
    public var minLevel: SzLogLevel
    /// How native formats each message. Defaults to ``SzLogFormat/bare``, so
    /// ``SzLogRecord/message`` is the message alone.
    public var format: SzLogFormat

    /// Creates options.
    public init(minLevel: SzLogLevel, format: SzLogFormat = .bare) {
        self.minLevel = minLevel
        self.format = format
    }

    /// Returns a copy with another format (C# `WithFormat`).
    public func withFormat(_ format: SzLogFormat) -> SzLogCallbackOptions {
        var copy = self
        copy.format = format
        return copy
    }
}

/// One native log message delivered to a callback, mirroring the C#
/// `SzLogRecord`.
public struct SzLogRecord: Hashable, Sendable {
    /// The message severity (never ``SzLogLevel/off``).
    public let level: SzLogLevel
    /// The native module, `rawModule` up to its last `:`.
    public let module: String
    /// The logging thread's hash, `rawModule` after its last `:` (empty if
    /// `rawModule` has none).
    public let threadHash: String
    /// The message, formatted as the registration's ``SzLogFormat`` asks.
    public let message: String
    /// The module exactly as native reported it, e.g. `szstatic:82eb15f5faba9bab`.
    public let rawModule: String

    /// Creates a record, splitting `rawModule` into ``module`` and
    /// ``threadHash``.
    public init(level: SzLogLevel, rawModule: String, message: String) {
        self.level = level
        self.rawModule = rawModule
        self.message = message
        if let colon = rawModule.lastIndex(of: ":") {
            module = String(rawModule[..<colon])
            threadHash = String(rawModule[rawModule.index(after: colon)...])
        } else {
            module = rawModule
            threadHash = ""
        }
    }
}

/// A log callback. Native may call it concurrently from many threads, so it
/// must be thread-safe and fast. Errors cannot escape it.
public typealias SzLogCallback = @Sendable (SzLogRecord) -> Void

/// A registered log callback, mirroring the C# `SzLogRegistration`.
///
/// The callback stays registered until ``unregister()`` or until the
/// registration is released. ``leak()`` keeps it for the process lifetime.
public protocol SzLogRegistration: AnyObject, Sendable {
    /// Stops delivery and unregisters the callback. Idempotent.
    ///
    /// Called from inside a log callback, delivery stops at once but native
    /// unregistration is skipped (it cannot run inside a callback); the
    /// callback's memory is then kept for the process lifetime.
    func unregister()

    /// Keeps the callback registered for the process lifetime, even after
    /// this object is released.
    func leak()

    /// Whether the callback still receives messages.
    var isRegistered: Bool { get }
}

/// The process-wide native logging controls, mirroring the C# `SzLogging`.
///
/// Obtain it from ``SzEnvironment/getLogging()``. Logging is process-wide and
/// independent of any environment's lifetime.
///
/// Change registrations, the default callback, output or format only before
/// the first engine subsystem is initialized or after the environment is
/// destroyed: native applies them to loggers as they are created.
/// ``setDefaultLogLevel(_:)`` and ``getEffectiveLogLevel()`` are safe at any
/// time.
///
/// Calls that change sinks throw ``SzErrorKind/configuration`` when made from
/// inside a log callback.
public protocol SzLogging: AnyObject, Sendable {
    /// Registers a process-wide callback that receives messages from all
    /// threads at or above `options.minLevel`, lowering the native level if
    /// needed (`SzLogging_registerCallbackWithFormat`).
    ///
    /// - Throws: ``SzErrorKind/configuration`` inside a log callback;
    ///   ``SzErrorKind/unrecoverable`` if native refuses the registration.
    func registerCallback(
        _ options: SzLogCallbackOptions,
        _ callback: @escaping SzLogCallback
    ) throws(SzError) -> any SzLogRegistration

    /// Makes `callback` the default sink in place of stderr, stdout or a file
    /// (`SzLogging_setDefaultCallback`). A replaced default callback is kept
    /// for the process lifetime.
    ///
    /// - Throws: ``SzErrorKind/configuration`` inside a log callback.
    func setDefaultCallback(
        _ options: SzLogCallbackOptions,
        _ callback: @escaping SzLogCallback
    ) throws(SzError)

    /// Sends the default sink to stderr, stdout, a file or nowhere
    /// (`SzLogging_setDefaultOutput`).
    ///
    /// Native resets the default format to ``SzLogFormat/legacy`` when the
    /// output changes, so call ``setDefaultFormat(_:)`` afterwards. A file is
    /// flushed when the output is replaced and at process exit.
    ///
    /// - Throws: ``SzErrorKind/badInput`` for an empty file path or one that
    ///   cannot be opened for appending; ``SzErrorKind/configuration`` inside
    ///   a log callback.
    func setDefaultOutput(_ output: SzLogOutput) throws(SzError)

    /// Sets how the default sink formats messages
    /// (`SzLogging_setDefaultFormatter`).
    ///
    /// - Throws: ``SzErrorKind/configuration`` inside a log callback.
    func setDefaultFormat(_ format: SzLogFormat) throws(SzError)

    /// Sets the native log level (`SzLogging_setLogLevel`). Native keeps it no
    /// higher than the lowest registered callback's minimum level.
    func setDefaultLogLevel(_ level: SzLogLevel)

    /// Returns the level native currently logs at (`SzLogging_getLogLevel`).
    func getEffectiveLogLevel() -> SzLogLevel
}

extension SzLogging {
    /// Registers a callback for messages at or above `minLevel` in the
    /// ``SzLogFormat/bare`` format.
    public func registerCallback(
        minLevel: SzLogLevel,
        _ callback: @escaping SzLogCallback
    ) throws(SzError) -> any SzLogRegistration {
        try registerCallback(SzLogCallbackOptions(minLevel: minLevel), callback)
    }
}
