/// Manages the configurations persisted in the repository, mirroring the C#
/// `SzConfigManager` interface.
public protocol SzConfigManager: Sendable {
    /// Creates an in-memory configuration from the default template.
    func createConfig() throws(SzError) -> any SzConfig

    /// Creates an in-memory configuration from a configuration definition.
    func createConfig(configDefinition: String) throws(SzError) -> any SzConfig

    /// Creates an in-memory configuration from a registered configuration.
    func createConfig(configID: Int64) throws(SzError) -> any SzConfig

    /// Registers a configuration definition and returns its configuration ID.
    func registerConfig(configDefinition: String, configComment: String) throws(SzError) -> Int64

    /// Returns the registered configurations as JSON.
    func getConfigRegistry() throws(SzError) -> String

    /// Returns the default configuration ID, or `0` when none is set.
    func getDefaultConfigID() throws(SzError) -> Int64

    /// Replaces the default configuration ID, failing with
    /// ``SzErrorKind/replaceConflict`` if it is no longer `currentDefaultConfigID`.
    func replaceDefaultConfigID(currentDefaultConfigID: Int64, newDefaultConfigID: Int64) throws(SzError)

    /// Sets the default configuration ID.
    func setDefaultConfigID(_ configID: Int64) throws(SzError)

    /// Registers a configuration definition, makes it the default, and returns its ID.
    func setDefaultConfig(configDefinition: String, configComment: String) throws(SzError) -> Int64
}

extension SzConfigManager {
    /// Registers a configuration definition with a comment generated from its
    /// data sources (for example `Data Sources: CUSTOMERS, WATCHLIST`).
    public func registerConfig(configDefinition: String) throws(SzError) -> Int64 {
        try registerConfig(
            configDefinition: configDefinition,
            configComment: ConfigComment.make(from: configDefinition)
        )
    }

    /// Registers a configuration definition with a generated comment and makes
    /// it the default.
    @discardableResult
    public func setDefaultConfig(configDefinition: String) throws(SzError) -> Int64 {
        try setDefaultConfig(
            configDefinition: configDefinition,
            configComment: ConfigComment.make(from: configDefinition)
        )
    }

    /// Returns the registered configurations decoded into ``SzConfigRegistry``.
    public func getConfigRegistry<T: Decodable>(as type: T.Type) throws(SzError) -> T {
        try SzJSON.decode(type, from: getConfigRegistry())
    }
}
