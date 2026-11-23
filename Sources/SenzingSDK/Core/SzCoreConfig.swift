import CSenzing

/// The ``SzConfig`` over the native engine, mirroring the C# `SzCoreConfig`.
///
/// Holds the configuration definition in memory; each change loads it into a
/// native configuration handle, applies the change, exports the result and
/// closes the handle.
public final class SzCoreConfig: SzConfig {
    let state: EnvironmentState
    private let definition: Locked<String>

    init(state: EnvironmentState, definition: String) {
        self.state = state
        self.definition = Locked(definition)
    }

    public func export() throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            definition.withLock { $0 }
        }
    }

    public func getDataSourceRegistry() throws(SzError) -> String {
        try withHandle { (handle) throws(SzError) -> String in
            let result = SzConfig_getDataSourceRegistry_helper(handle)
            return try Native.take(result.response, result.returnCode, .config)
        }
    }

    @discardableResult
    public func registerDataSource(_ dataSourceCode: String) throws(SzError) -> String {
        let input = JSONText.dataSourceCode(dataSourceCode)
        return try withHandle(saving: true) { (handle) throws(SzError) -> String in
            let result = SzConfig_registerDataSource_helper(handle, input)
            return try Native.take(result.response, result.returnCode, .config)
        }
    }

    public func unregisterDataSource(_ dataSourceCode: String) throws(SzError) {
        let input = JSONText.dataSourceCode(dataSourceCode)
        try withHandle(saving: true) { (handle) throws(SzError) in
            try Native.check(SzConfig_unregisterDataSource_helper(handle, input), .config)
        }
    }

    /// Loads the definition into a native handle, runs `body`, optionally
    /// exports the changed definition, and always closes the handle.
    private func withHandle<T>(
        saving: Bool = false,
        _ body: (UInt) throws(SzError) -> T
    ) throws(SzError) -> T {
        try state.execute { () throws(SzError) -> T in
            try definition.withLock { (current) throws(SzError) -> T in
                let handle = try NativeConfig.load(current)
                defer { SzConfig_close_helper(handle) }
                let value = try body(handle)
                if saving {
                    current = try NativeConfig.export(handle)
                }
                return value
            }
        }
    }
}

/// Native configuration-handle helpers shared by the config types.
enum NativeConfig {
    /// Loads a configuration definition into a new native handle.
    static func load(_ definition: String) throws(SzError) -> UInt {
        let result = SzConfig_load_helper(definition)
        try Native.check(result.returnCode, .config)
        return UInt(bitPattern: result.response)
    }

    /// Exports the definition held by a native handle.
    static func export(_ handle: UInt) throws(SzError) -> String {
        let result = SzConfig_export_helper(handle)
        return try Native.take(result.response, result.returnCode, .config)
    }

    /// Normalizes a definition: load it, export it, close the handle.
    static func roundTrip(_ definition: String) throws(SzError) -> String {
        let handle = try load(definition)
        defer { SzConfig_close_helper(handle) }
        return try export(handle)
    }

    /// Creates the default template definition.
    static func template() throws(SzError) -> String {
        let result = SzConfig_create_helper()
        try Native.check(result.returnCode, .config)
        let handle = result.response
        defer { SzConfig_close_helper(handle) }
        return try export(handle)
    }
}
