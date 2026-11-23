import Foundation

/// The kind of an ``SzError``, mirroring the C# SDK exception hierarchy.
///
/// The engine kinds form the same tree as the C# `SzException` classes:
///
/// ```
/// general (SzError)
/// ├── badInput
/// │   ├── notFound
/// │   └── unknownDataSource
/// ├── configuration
/// ├── replaceConflict
/// ├── retryable
/// │   ├── databaseConnectionLost
/// │   ├── databaseTransient
/// │   └── retryTimeoutExceeded
/// └── unrecoverable
///     ├── database
///     ├── license
///     ├── notInitialized
///     └── unhandled
/// ```
///
/// Native error codes are assigned to kinds by the `szerrors.json` file that
/// ships with the Senzing runtime (see `tools/generate-sdk-tables.swift`).
///
/// Two kinds sit outside the engine tree because they are raised by this SDK,
/// not by the engine: ``environmentDestroyed`` (C#
/// `SzEnvironmentDestroyedException`, which is not an `SzException` either)
/// and ``json`` (a typed record or result could not be converted to or from
/// the engine's JSON).
public enum SzErrorKind: String, CaseIterable, Sendable {
    /// Any engine error (C# `SzException`). Every engine kind is a ``general``.
    case general = "SzError"
    /// The input was invalid (C# `SzBadInputException`).
    case badInput = "SzBadInputError"
    /// The requested entity or record does not exist (C# `SzNotFoundException`).
    case notFound = "SzNotFoundError"
    /// The data source is not registered (C# `SzUnknownDataSourceException`).
    case unknownDataSource = "SzUnknownDataSourceError"
    /// The configuration is missing or invalid (C# `SzConfigurationException`).
    case configuration = "SzConfigurationError"
    /// The default configuration changed concurrently (C# `SzReplaceConflictException`).
    case replaceConflict = "SzReplaceConflictError"
    /// The operation may succeed if retried (C# `SzRetryableException`).
    case retryable = "SzRetryableError"
    /// The database connection was lost (C# `SzDatabaseConnectionLostException`).
    case databaseConnectionLost = "SzDatabaseConnectionLostError"
    /// A transient database error occurred (C# `SzDatabaseTransientException`).
    case databaseTransient = "SzDatabaseTransientError"
    /// A retry timeout was exceeded (C# `SzRetryTimeoutExceededException`).
    case retryTimeoutExceeded = "SzRetryTimeoutExceededError"
    /// The engine cannot continue (C# `SzUnrecoverableException`).
    case unrecoverable = "SzUnrecoverableError"
    /// A non-transient database error occurred (C# `SzDatabaseException`).
    case database = "SzDatabaseError"
    /// The license is invalid or exceeded (C# `SzLicenseException`).
    case license = "SzLicenseError"
    /// The engine is not initialized (C# `SzNotInitializedException`).
    case notInitialized = "SzNotInitializedError"
    /// An unhandled engine error occurred (C# `SzUnhandledException`).
    case unhandled = "SzUnhandledError"
    /// The ``SzEnvironment`` was used after ``SzEnvironment/destroy()``
    /// (C# `SzEnvironmentDestroyedException`). Not an engine error.
    case environmentDestroyed = "SzEnvironmentDestroyedError"
    /// A value could not be encoded to, or decoded from, the JSON the engine
    /// exchanges (typed records and results). Not an engine error.
    case json = "SzJsonError"

    /// The parent kind in the hierarchy, or `nil` for the roots.
    public var parent: SzErrorKind? {
        switch self {
        case .general, .environmentDestroyed, .json:
            nil
        case .badInput, .configuration, .replaceConflict, .retryable, .unrecoverable:
            .general
        case .notFound, .unknownDataSource:
            .badInput
        case .databaseConnectionLost, .databaseTransient, .retryTimeoutExceeded:
            .retryable
        case .database, .license, .notInitialized, .unhandled:
            .unrecoverable
        }
    }

    /// Whether this kind is `other` or descends from it.
    public func isKind(of other: SzErrorKind) -> Bool {
        var current: SzErrorKind? = self
        while let kind = current {
            if kind == other {
                return true
            }
            current = kind.parent
        }
        return false
    }

    /// The kind that `szerrors.json` assigns to a native error code.
    public static func forErrorCode(_ errorCode: Int64) -> SzErrorKind {
        kindsByErrorCode[errorCode] ?? .general
    }
}

/// An error reported by the Senzing engine or by this SDK.
///
/// Every throwing SDK method uses typed throws, `throws(SzError)`. Match on the
/// ``kind`` hierarchy with ``isKind(of:)`` or with the kind patterns
/// (`SzError.notFound`, `SzError.retryable`, ...), which honor the hierarchy:
///
/// ```swift
/// do {
///     let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001")
/// } catch SzError.notFound {
///     // no such record
/// } catch SzError.retryable {
///     // retry later
/// } catch {
///     print(error.kind, error.errorCode ?? 0, error.message)
/// }
/// ```
public struct SzError: Error, Sendable, Equatable, CustomStringConvertible, LocalizedError {
    /// The most specific kind of this error.
    public let kind: SzErrorKind
    /// The native Senzing error code (the number in `SENZnnnn`), if any.
    public let errorCode: Int64?
    /// The error message.
    public let message: String

    /// Creates an error of the given kind.
    public init(_ kind: SzErrorKind, errorCode: Int64? = nil, message: String) {
        self.kind = kind
        self.errorCode = errorCode
        self.message = message
    }

    /// Creates the error that `szerrors.json` assigns to a native error code.
    public init(errorCode: Int64, message: String) {
        self.init(SzErrorKind.forErrorCode(errorCode), errorCode: errorCode, message: message)
    }

    /// Whether this error is of `kind` or of one of its descendants.
    public func isKind(of kind: SzErrorKind) -> Bool {
        self.kind.isKind(of: kind)
    }

    /// Whether retrying the operation may succeed.
    public var isRetryable: Bool { isKind(of: .retryable) }

    /// Whether the engine cannot continue.
    public var isUnrecoverable: Bool { isKind(of: .unrecoverable) }

    public var description: String {
        if let errorCode {
            return "\(kind.rawValue)(\(errorCode)): \(message)"
        }
        return "\(kind.rawValue): \(message)"
    }

    public var errorDescription: String? { description }

    /// Matches an error against a kind pattern, honoring the hierarchy, so
    /// `catch SzError.badInput` also catches ``SzErrorKind/notFound``.
    public static func ~= (pattern: SzErrorKind, error: SzError) -> Bool {
        error.isKind(of: pattern)
    }

    // MARK: Kind patterns for `catch` clauses

    /// Pattern for ``SzErrorKind/general`` and its descendants: `catch SzError.general`.
    public static let general: SzErrorKind = .general
    /// Pattern for ``SzErrorKind/badInput`` and its descendants: `catch SzError.badInput`.
    public static let badInput: SzErrorKind = .badInput
    /// Pattern for ``SzErrorKind/notFound`` and its descendants: `catch SzError.notFound`.
    public static let notFound: SzErrorKind = .notFound
    /// Pattern for ``SzErrorKind/unknownDataSource`` and its descendants: `catch SzError.unknownDataSource`.
    public static let unknownDataSource: SzErrorKind = .unknownDataSource
    /// Pattern for ``SzErrorKind/configuration`` and its descendants: `catch SzError.configuration`.
    public static let configuration: SzErrorKind = .configuration
    /// Pattern for ``SzErrorKind/replaceConflict`` and its descendants: `catch SzError.replaceConflict`.
    public static let replaceConflict: SzErrorKind = .replaceConflict
    /// Pattern for ``SzErrorKind/retryable`` and its descendants: `catch SzError.retryable`.
    public static let retryable: SzErrorKind = .retryable
    /// Pattern for ``SzErrorKind/databaseConnectionLost`` and its descendants: `catch SzError.databaseConnectionLost`.
    public static let databaseConnectionLost: SzErrorKind = .databaseConnectionLost
    /// Pattern for ``SzErrorKind/databaseTransient`` and its descendants: `catch SzError.databaseTransient`.
    public static let databaseTransient: SzErrorKind = .databaseTransient
    /// Pattern for ``SzErrorKind/retryTimeoutExceeded`` and its descendants: `catch SzError.retryTimeoutExceeded`.
    public static let retryTimeoutExceeded: SzErrorKind = .retryTimeoutExceeded
    /// Pattern for ``SzErrorKind/unrecoverable`` and its descendants: `catch SzError.unrecoverable`.
    public static let unrecoverable: SzErrorKind = .unrecoverable
    /// Pattern for ``SzErrorKind/database`` and its descendants: `catch SzError.database`.
    public static let database: SzErrorKind = .database
    /// Pattern for ``SzErrorKind/license`` and its descendants: `catch SzError.license`.
    public static let license: SzErrorKind = .license
    /// Pattern for ``SzErrorKind/notInitialized`` and its descendants: `catch SzError.notInitialized`.
    public static let notInitialized: SzErrorKind = .notInitialized
    /// Pattern for ``SzErrorKind/unhandled`` and its descendants: `catch SzError.unhandled`.
    public static let unhandled: SzErrorKind = .unhandled
    /// Pattern for ``SzErrorKind/environmentDestroyed`` and its descendants: `catch SzError.environmentDestroyed`.
    public static let environmentDestroyed: SzErrorKind = .environmentDestroyed
    /// Pattern for ``SzErrorKind/json`` and its descendants: `catch SzError.json`.
    public static let json: SzErrorKind = .json
}

/// Matches any error against an ``SzErrorKind`` pattern, honoring the
/// hierarchy (for untyped `catch` clauses and `switch` over `any Error`).
public func ~= (pattern: SzErrorKind, error: any Error) -> Bool {
    (error as? SzError)?.isKind(of: pattern) ?? false
}
