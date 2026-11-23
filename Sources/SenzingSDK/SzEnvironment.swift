/// The entry point and lifecycle owner of the Senzing subsystems, mirroring
/// the C# `SzEnvironment` interface.
///
/// Each `get...` accessor lazily initializes its native subsystem and returns
/// the same instance on later calls. After ``destroy()`` every subsystem
/// method throws ``SzErrorKind/environmentDestroyed``.
///
/// ``SzCoreEnvironment`` is the implementation over the native engine.
public protocol SzEnvironment: AnyObject, Sendable {
    /// Returns the product subsystem (version and license information).
    func getProduct() throws(SzError) -> any SzProduct

    /// Returns the engine subsystem (records, entities, search, why/how).
    func getEngine() throws(SzError) -> any SzEngine

    /// Returns the configuration manager subsystem.
    func getConfigManager() throws(SzError) -> any SzConfigManager

    /// Returns the diagnostic subsystem.
    func getDiagnostic() throws(SzError) -> any SzDiagnostic

    /// Returns the ID of the configuration the engine is using.
    func getActiveConfigID() throws(SzError) -> Int64

    /// Reinitializes the initialized subsystems with another configuration.
    func reinitialize(configID: Int64) throws(SzError)

    /// Destroys the environment and its subsystems. Idempotent.
    ///
    /// Waits for in-flight calls to finish; later calls throw
    /// ``SzErrorKind/environmentDestroyed``.
    func destroy()

    /// Whether ``destroy()`` has been called.
    var isDestroyed: Bool { get }
}
