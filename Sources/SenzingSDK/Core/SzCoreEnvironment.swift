import CSenzing
import Foundation

/// The ``SzEnvironment`` over the native Senzing engine, mirroring the C#
/// `SzCoreEnvironment`.
///
/// ```swift
/// let environment = try SzCoreEnvironment(
///     instanceName: "my-app",
///     settings: settingsJSON
/// )
/// defer { environment.destroy() }
/// let engine = try environment.getEngine()
/// ```
///
/// Only one environment may be active in a process at a time; destroy it (or
/// release it) before creating another. The environment and its subsystems
/// are `Sendable` and may be used from many threads.
public final class SzCoreEnvironment: SzEnvironment, @unchecked Sendable {
    /// The instance name used when none is given, as in the C# SDK.
    public static let defaultInstanceName = "Senzing Instance"
    /// The settings used when none are given, as in the C# SDK.
    public static let defaultSettings = "{ }"

    /// The instance name the native subsystems are initialized with.
    public let instanceName: String
    /// The settings JSON (`SENZING_ENGINE_CONFIGURATION_JSON`).
    public let settings: String
    /// Whether verbose native logging is enabled.
    public let verboseLogging: Bool

    let state: EnvironmentState
    private let subsystems = Locked(Subsystems())

    private struct Subsystems {
        var product: SzCoreProduct?
        var engine: SzCoreEngine?
        var configManager: SzCoreConfigManager?
        var diagnostic: SzCoreDiagnostic?
    }

    private struct ActiveInstance {
        let identifier: ObjectIdentifier
        weak var environment: SzCoreEnvironment?
    }

    /// Tracks the one active environment in the process.
    private static let activeInstance = Locked<ActiveInstance?>(nil)

    /// Creates an environment. Native subsystems are initialized lazily, on
    /// the first call to their `get...` accessor.
    ///
    /// - Parameters:
    ///   - instanceName: A name that identifies this process in native logs.
    ///     Blank means ``defaultInstanceName``.
    ///   - settings: The engine settings JSON. Blank means ``defaultSettings``.
    ///   - verboseLogging: Whether to enable verbose native logging.
    ///   - configID: A registered configuration to use instead of the
    ///     repository's default configuration.
    /// - Throws: ``SzErrorKind/general`` if another environment is active.
    public init(
        instanceName: String = SzCoreEnvironment.defaultInstanceName,
        settings: String = SzCoreEnvironment.defaultSettings,
        verboseLogging: Bool = false,
        configID: Int64? = nil
    ) throws(SzError) {
        self.instanceName = Self.normalize(instanceName, fallback: Self.defaultInstanceName)
        self.settings = Self.normalize(settings, fallback: Self.defaultSettings)
        self.verboseLogging = verboseLogging
        self.state = EnvironmentState(configID: configID)
        let instance = ActiveInstance(identifier: ObjectIdentifier(self), environment: self)
        try Self.activeInstance.withLock { (active) throws(SzError) in
            if active != nil {
                throw SzError(
                    .general,
                    message: "Only one active SzEnvironment is permitted per process; "
                        + "destroy the existing instance first."
                )
            }
            active = instance
        }
    }

    deinit {
        destroy()
    }

    /// Returns a builder, mirroring C# `SzCoreEnvironment.NewBuilder()`.
    public static func newBuilder() -> Builder {
        Builder()
    }

    /// Returns the active environment, if any (C# `GetActiveInstance`).
    ///
    /// Returns `nil` once the active environment is destroyed or released.
    /// While a ``destroy()`` is in progress, waits for it to finish and then
    /// returns `nil`, as the official SDKs do.
    public static func getActiveInstance() -> SzCoreEnvironment? {
        guard let environment = activeInstance.withLock({ $0?.environment }) else {
            return nil
        }
        if environment.state.isDestroyBegun {
            environment.state.waitForDestroy()
            return nil
        }
        return environment
    }

    /// The configuration the subsystems use: the ID given at creation or to
    /// ``reinitialize(configID:)``, or `nil` for the repository default.
    public var configID: Int64? {
        state.configID
    }

    public func getProduct() throws(SzError) -> any SzProduct {
        try initializeOnce(\.product) { () throws(SzError) in
            try Native.check(SzProduct_init(instanceName, settings, verboseFlag), .product)
            return SzCoreProduct(state: state)
        }
    }

    public func getEngine() throws(SzError) -> any SzEngine {
        try coreEngine()
    }

    public func getConfigManager() throws(SzError) -> any SzConfigManager {
        try initializeOnce(\.configManager) { () throws(SzError) in
            try Native.check(SzConfig_init(instanceName, settings, verboseFlag), .config)
            let returnCode = SzConfigMgr_init(instanceName, settings, verboseFlag)
            if returnCode != 0 {
                let error = Native.lastError(.configManager)
                SzConfig_destroy()
                throw error
            }
            return SzCoreConfigManager(state: state)
        }
    }

    public func getDiagnostic() throws(SzError) -> any SzDiagnostic {
        try initializeOnce(\.diagnostic) { () throws(SzError) in
            let returnCode =
                if let configID = state.configID {
                    SzDiagnostic_initWithConfigID(instanceName, settings, configID, verboseFlag)
                } else {
                    SzDiagnostic_init(instanceName, settings, verboseFlag)
                }
            try Native.check(returnCode, .diagnostic)
            return SzCoreDiagnostic(state: state)
        }
    }

    public func getLogging() -> any SzLogging {
        SzCoreLogging.getInstance()
    }

    public func getActiveConfigID() throws(SzError) -> Int64 {
        _ = try coreEngine()
        return try state.execute { () throws(SzError) -> Int64 in
            let result = Sz_getActiveConfigID_helper()
            try Native.check(result.returnCode, .engine)
            return result.configID
        }
    }

    public func reinitialize(configID: Int64) throws(SzError) {
        try state.execute { () throws(SzError) in
            try subsystems.withLock { (cache) throws(SzError) in
                if cache.engine != nil {
                    try Native.check(Sz_reinit(configID), .engine)
                }
                if cache.diagnostic != nil {
                    try Native.check(SzDiagnostic_reinit(configID), .diagnostic)
                }
                // Recorded only on success; subsystems created later use it.
                state.configID = configID
            }
        }
    }

    public func destroy() {
        // Captures no `self`: destroy() also runs from deinit, and may be
        // deferred to the end of an SDK call (see EnvironmentState.destroy).
        let subsystems = self.subsystems
        let identifier = ObjectIdentifier(self)
        state.destroy {
            subsystems.withLock { cache in
                if cache.diagnostic != nil {
                    SzDiagnostic_destroy()
                }
                if cache.configManager != nil {
                    SzConfigMgr_destroy()
                    SzConfig_destroy()
                }
                if cache.product != nil {
                    SzProduct_destroy()
                }
                if cache.engine != nil {
                    Sz_destroy()
                }
                cache = Subsystems()
            }
            Self.activeInstance.withLock { active in
                if active?.identifier == identifier {
                    active = nil
                }
            }
        }
    }

    public var isDestroyed: Bool {
        state.isDestroyed
    }

    private var verboseFlag: Int64 {
        verboseLogging ? 1 : 0
    }

    private func coreEngine() throws(SzError) -> SzCoreEngine {
        try initializeOnce(\.engine) { () throws(SzError) in
            let returnCode =
                if let configID = state.configID {
                    Sz_initWithConfigID(instanceName, settings, configID, verboseFlag)
                } else {
                    Sz_init(instanceName, settings, verboseFlag)
                }
            try Native.check(returnCode, .engine)
            return SzCoreEngine(state: state)
        }
    }

    /// Returns the cached subsystem, creating it on first use. Runs under the
    /// environment's shared lock, so ``destroy()`` cannot interleave.
    private func initializeOnce<T>(
        _ slot: WritableKeyPath<Subsystems, T?>,
        _ create: () throws(SzError) -> T
    ) throws(SzError) -> T {
        try state.execute { () throws(SzError) -> T in
            try subsystems.withLock { (cache) throws(SzError) -> T in
                if let existing = cache[keyPath: slot] {
                    return existing
                }
                let created = try create()
                cache[keyPath: slot] = created
                return created
            }
        }
    }

    private static func normalize(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

extension SzCoreEnvironment {
    /// A builder for ``SzCoreEnvironment``, mirroring the C# builder.
    ///
    /// ```swift
    /// let environment = try SzCoreEnvironment.newBuilder()
    ///     .instanceName("my-app")
    ///     .settings(settingsJSON)
    ///     .verboseLogging(false)
    ///     .build()
    /// ```
    public struct Builder: Sendable {
        private var instanceNameValue = SzCoreEnvironment.defaultInstanceName
        private var settingsValue = SzCoreEnvironment.defaultSettings
        private var verboseLoggingValue = false
        private var configIDValue: Int64?

        public init() {}

        /// Sets the instance name.
        public func instanceName(_ instanceName: String) -> Builder {
            var copy = self
            copy.instanceNameValue = instanceName
            return copy
        }

        /// Sets the engine settings JSON.
        public func settings(_ settings: String) -> Builder {
            var copy = self
            copy.settingsValue = settings
            return copy
        }

        /// Enables or disables verbose native logging.
        public func verboseLogging(_ verboseLogging: Bool) -> Builder {
            var copy = self
            copy.verboseLoggingValue = verboseLogging
            return copy
        }

        /// Pins a registered configuration instead of the repository default.
        public func configID(_ configID: Int64?) -> Builder {
            var copy = self
            copy.configIDValue = configID
            return copy
        }

        /// Creates the environment.
        public func build() throws(SzError) -> SzCoreEnvironment {
            try SzCoreEnvironment(
                instanceName: instanceNameValue,
                settings: settingsValue,
                verboseLogging: verboseLoggingValue,
                configID: configIDValue
            )
        }
    }
}
