/// An opaque handle to an export report from
/// ``SzEngine/exportJsonEntityReport(flags:)`` or
/// ``SzEngine/exportCsvEntityReport(csvColumnList:flags:)``.
///
/// Read it with ``SzEngine/fetchNext(_:)`` and always release it with
/// ``SzEngine/closeExportReport(_:)``.
public struct SzExportHandle: Hashable, Sendable {
    /// The native handle value.
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

/// Entity resolution: add and delete records, get entities, search, find
/// paths and networks, and explain results. Mirrors the C# `SzEngine`
/// interface.
///
/// Every method takes a `flags` argument; the extension overloads without it
/// use the per-method `...DefaultFlags` constant, as the C# SDK does. Results
/// are the engine's JSON documents; the `as:` overloads decode them into
/// `Decodable` types such as ``SzEntityResponse``.
///
/// Calls block the calling thread while the native engine works. The engine
/// is thread-safe, so calls may run concurrently from many threads; from
/// Swift concurrency or the main actor, use ``SzAsyncEngine``.
public protocol SzEngine: Sendable {
    /// Loads the engine's internal caches ahead of the first request.
    func primeEngine() throws(SzError)

    /// Returns workload statistics since the last call, as JSON.
    func getStats() throws(SzError) -> String

    /// Adds or replaces a record. Returns the info JSON when `flags`
    /// contains ``SzFlags/withInfo``, otherwise `nil`.
    @discardableResult
    func addRecord(
        dataSourceCode: String, recordID: String, recordDefinition: String, flags: SzFlags
    )
        throws(SzError) -> String?

    /// Returns the features the engine would extract from a record definition, as JSON.
    func getRecordPreview(_ recordDefinition: String, flags: SzFlags) throws(SzError) -> String

    /// Deletes a record. Returns the info JSON when `flags` contains
    /// ``SzFlags/withInfo``, otherwise `nil`.
    @discardableResult
    func deleteRecord(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String?

    /// Re-resolves a record. Returns the info JSON when `flags` contains
    /// ``SzFlags/withInfo``, otherwise `nil`.
    @discardableResult
    func reevaluateRecord(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String?

    /// Re-resolves an entity. Returns the info JSON when `flags` contains
    /// ``SzFlags/withInfo``, otherwise `nil`.
    @discardableResult
    func reevaluateEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String?

    /// Searches for entities that match the attributes of a record
    /// definition. A `nil` search profile uses the default profile.
    func searchByAttributes(_ attributes: String, searchProfile: String?, flags: SzFlags) throws(SzError) -> String

    /// Explains why an entity is, or is not, a search result.
    func whySearch(
        _ attributes: String, entityID: Int64, searchProfile: String?, flags: SzFlags
    )
        throws(SzError) -> String

    /// Returns an entity by its entity ID, as JSON.
    func getEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String

    /// Returns the entity that contains a record, as JSON.
    func getEntity(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String

    /// Returns a record, as JSON.
    func getRecord(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String

    /// Returns interesting entities related to an entity, as JSON.
    func findInterestingEntities(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String

    /// Returns interesting entities related to the entity of a record, as JSON.
    func findInterestingEntities(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String

    /// Finds a relationship path between two entities.
    func findPath(
        startEntityID: Int64,
        endEntityID: Int64,
        maxDegrees: Int,
        avoidEntityIDs: Set<Int64>,
        requiredDataSources: Set<String>,
        flags: SzFlags
    ) throws(SzError) -> String

    /// Finds a relationship path between the entities of two records.
    func findPath(
        startDataSourceCode: String,
        startRecordID: String,
        endDataSourceCode: String,
        endRecordID: String,
        maxDegrees: Int,
        avoidRecordKeys: Set<SzRecordKey>,
        requiredDataSources: Set<String>,
        flags: SzFlags
    ) throws(SzError) -> String

    /// Finds the network of relationships among entities.
    func findNetwork(
        entityIDs: Set<Int64>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags
    ) throws(SzError) -> String

    /// Finds the network of relationships among the entities of records.
    func findNetwork(
        recordKeys: Set<SzRecordKey>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags
    ) throws(SzError) -> String

    /// Explains why a record belongs to its entity.
    func whyRecordInEntity(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String

    /// Explains why two records resolved, or did not resolve, together.
    func whyRecords(
        dataSourceCode1: String,
        recordID1: String,
        dataSourceCode2: String,
        recordID2: String,
        flags: SzFlags
    ) throws(SzError) -> String

    /// Explains why two entities did not resolve into one.
    func whyEntities(entityID1: Int64, entityID2: Int64, flags: SzFlags) throws(SzError) -> String

    /// Explains how an entity was built, step by step.
    func howEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String

    /// Returns the entity the given records would form, without changing the repository.
    func getVirtualEntity(_ recordKeys: Set<SzRecordKey>, flags: SzFlags) throws(SzError) -> String

    /// Starts a JSON export of the entities in the repository.
    func exportJsonEntityReport(flags: SzFlags) throws(SzError) -> SzExportHandle

    /// Starts a CSV export of the entities in the repository.
    func exportCsvEntityReport(csvColumnList: String, flags: SzFlags) throws(SzError) -> SzExportHandle

    /// Returns the next line of an export report, or `nil` at the end.
    func fetchNext(_ exportHandle: SzExportHandle) throws(SzError) -> String?

    /// Releases an export report.
    func closeExportReport(_ exportHandle: SzExportHandle) throws(SzError)

    /// Processes a redo record. Returns the info JSON when `flags` contains
    /// ``SzFlags/withInfo``, otherwise `nil`.
    @discardableResult
    func processRedoRecord(_ redoRecord: String, flags: SzFlags) throws(SzError) -> String?

    /// Returns the next pending redo record, or `nil` when there is none.
    func getRedoRecord() throws(SzError) -> String?

    /// Returns the number of pending redo records.
    func countRedoRecords() throws(SzError) -> Int64
}
