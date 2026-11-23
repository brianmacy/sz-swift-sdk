/// An in-memory configuration, mirroring the C# `SzConfig` interface.
///
/// Obtain one from ``SzConfigManager/createConfig()`` (the default template),
/// ``SzConfigManager/createConfig(configDefinition:)`` or
/// ``SzConfigManager/createConfig(configID:)``. Changes stay in memory until
/// the exported definition is registered with ``SzConfigManager``.
public protocol SzConfig: AnyObject, Sendable {
    /// Returns the configuration definition as JSON.
    func export() throws(SzError) -> String

    /// Returns the registered data sources as JSON.
    func getDataSourceRegistry() throws(SzError) -> String

    /// Registers a data source and returns the registration result as JSON.
    @discardableResult
    func registerDataSource(_ dataSourceCode: String) throws(SzError) -> String

    /// Unregisters a data source.
    func unregisterDataSource(_ dataSourceCode: String) throws(SzError)
}

extension SzConfig {
    /// Returns the registered data sources decoded into ``SzDataSourceRegistry``.
    public func getDataSourceRegistry<T: Decodable>(
        as type: T.Type
    ) throws(SzError) -> T {
        try SzJSON.decode(type, from: getDataSourceRegistry())
    }
}
