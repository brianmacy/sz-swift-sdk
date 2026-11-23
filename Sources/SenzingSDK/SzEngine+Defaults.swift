// Default arguments for the SzEngine requirements.
//
// Swift protocol requirements cannot declare default arguments, so each
// method is redeclared here with the C# defaults: the per-method
// `...DefaultFlags` constant, a `nil` search profile, and empty avoid /
// required sets. A call that omits arguments resolves to the declaration
// here, which forwards to the conforming type's implementation.

extension SzEngine {
    @discardableResult
    public func addRecord(
        dataSourceCode: String,
        recordID: String,
        recordDefinition: String,
        flags: SzFlags = .addRecordDefaultFlags
    ) throws(SzError) -> String? {
        try addRecord(
            dataSourceCode: dataSourceCode, recordID: recordID, recordDefinition: recordDefinition, flags: flags)
    }

    public func getRecordPreview(
        _ recordDefinition: String, flags: SzFlags = .recordPreviewDefaultFlags
    )
        throws(SzError) -> String
    {
        try getRecordPreview(recordDefinition, flags: flags)
    }

    @discardableResult
    public func deleteRecord(
        dataSourceCode: String, recordID: String, flags: SzFlags = .deleteRecordDefaultFlags
    )
        throws(SzError) -> String?
    {
        try deleteRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    @discardableResult
    public func reevaluateRecord(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .reevaluateRecordDefaultFlags
    ) throws(SzError) -> String? {
        try reevaluateRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    @discardableResult
    public func reevaluateEntity(
        _ entityID: Int64, flags: SzFlags = .reevaluateEntityDefaultFlags
    )
        throws(SzError) -> String?
    {
        try reevaluateEntity(entityID, flags: flags)
    }

    public func searchByAttributes(
        _ attributes: String,
        searchProfile: String? = nil,
        flags: SzFlags = .searchByAttributesDefaultFlags
    ) throws(SzError) -> String {
        try searchByAttributes(attributes, searchProfile: searchProfile, flags: flags)
    }

    public func whySearch(
        _ attributes: String,
        entityID: Int64,
        searchProfile: String? = nil,
        flags: SzFlags = .whySearchDefaultFlags
    ) throws(SzError) -> String {
        try whySearch(attributes, entityID: entityID, searchProfile: searchProfile, flags: flags)
    }

    public func getEntity(_ entityID: Int64, flags: SzFlags = .entityDefaultFlags) throws(SzError) -> String {
        try getEntity(entityID, flags: flags)
    }

    public func getEntity(
        dataSourceCode: String, recordID: String, flags: SzFlags = .entityDefaultFlags
    )
        throws(SzError) -> String
    {
        try getEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    public func getRecord(
        dataSourceCode: String, recordID: String, flags: SzFlags = .recordDefaultFlags
    )
        throws(SzError) -> String
    {
        try getRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    public func findInterestingEntities(
        _ entityID: Int64, flags: SzFlags = .findInterestingEntitiesDefaultFlags
    )
        throws(SzError) -> String
    {
        try findInterestingEntities(entityID, flags: flags)
    }

    public func findInterestingEntities(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .findInterestingEntitiesDefaultFlags
    ) throws(SzError) -> String {
        try findInterestingEntities(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    public func findPath(
        startEntityID: Int64,
        endEntityID: Int64,
        maxDegrees: Int,
        avoidEntityIDs: Set<Int64> = [],
        requiredDataSources: Set<String> = [],
        flags: SzFlags = .findPathDefaultFlags
    ) throws(SzError) -> String {
        try findPath(
            startEntityID: startEntityID,
            endEntityID: endEntityID,
            maxDegrees: maxDegrees,
            avoidEntityIDs: avoidEntityIDs,
            requiredDataSources: requiredDataSources,
            flags: flags
        )
    }

    public func findPath(
        startDataSourceCode: String,
        startRecordID: String,
        endDataSourceCode: String,
        endRecordID: String,
        maxDegrees: Int,
        avoidRecordKeys: Set<SzRecordKey> = [],
        requiredDataSources: Set<String> = [],
        flags: SzFlags = .findPathDefaultFlags
    ) throws(SzError) -> String {
        try findPath(
            startDataSourceCode: startDataSourceCode,
            startRecordID: startRecordID,
            endDataSourceCode: endDataSourceCode,
            endRecordID: endRecordID,
            maxDegrees: maxDegrees,
            avoidRecordKeys: avoidRecordKeys,
            requiredDataSources: requiredDataSources,
            flags: flags
        )
    }

    public func findNetwork(
        entityIDs: Set<Int64>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags = .findNetworkDefaultFlags
    ) throws(SzError) -> String {
        try findNetwork(
            entityIDs: entityIDs,
            maxDegrees: maxDegrees,
            buildOutDegrees: buildOutDegrees,
            buildOutMaxEntities: buildOutMaxEntities,
            flags: flags
        )
    }

    public func findNetwork(
        recordKeys: Set<SzRecordKey>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags = .findNetworkDefaultFlags
    ) throws(SzError) -> String {
        try findNetwork(
            recordKeys: recordKeys,
            maxDegrees: maxDegrees,
            buildOutDegrees: buildOutDegrees,
            buildOutMaxEntities: buildOutMaxEntities,
            flags: flags
        )
    }

    public func whyRecordInEntity(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .whyRecordInEntityDefaultFlags
    ) throws(SzError) -> String {
        try whyRecordInEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
    }

    public func whyRecords(
        dataSourceCode1: String,
        recordID1: String,
        dataSourceCode2: String,
        recordID2: String,
        flags: SzFlags = .whyRecordsDefaultFlags
    ) throws(SzError) -> String {
        try whyRecords(
            dataSourceCode1: dataSourceCode1,
            recordID1: recordID1,
            dataSourceCode2: dataSourceCode2,
            recordID2: recordID2,
            flags: flags
        )
    }

    public func whyEntities(
        entityID1: Int64, entityID2: Int64, flags: SzFlags = .whyEntitiesDefaultFlags
    )
        throws(SzError) -> String
    {
        try whyEntities(entityID1: entityID1, entityID2: entityID2, flags: flags)
    }

    public func howEntity(_ entityID: Int64, flags: SzFlags = .howEntityDefaultFlags) throws(SzError) -> String {
        try howEntity(entityID, flags: flags)
    }

    public func getVirtualEntity(
        _ recordKeys: Set<SzRecordKey>, flags: SzFlags = .virtualEntityDefaultFlags
    )
        throws(SzError) -> String
    {
        try getVirtualEntity(recordKeys, flags: flags)
    }

    public func exportJsonEntityReport(flags: SzFlags = .exportDefaultFlags) throws(SzError) -> SzExportHandle {
        try exportJsonEntityReport(flags: flags)
    }

    public func exportCsvEntityReport(
        csvColumnList: String, flags: SzFlags = .exportDefaultFlags
    )
        throws(SzError) -> SzExportHandle
    {
        try exportCsvEntityReport(csvColumnList: csvColumnList, flags: flags)
    }

    @discardableResult
    public func processRedoRecord(_ redoRecord: String, flags: SzFlags = .redoDefaultFlags) throws(SzError) -> String? {
        try processRedoRecord(redoRecord, flags: flags)
    }
}
