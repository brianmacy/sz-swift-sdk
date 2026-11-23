import CSenzing

/// The ``SzEngine`` over the native engine, mirroring the C# `SzCoreEngine`.
///
/// Obtain it from ``SzCoreEnvironment/getEngine()``.
public final class SzCoreEngine: SzEngine {
    let state: EnvironmentState

    init(state: EnvironmentState) {
        self.state = state
    }

    /// Runs a native call that returns a helper response buffer.
    private func call(_ body: () -> (UnsafeMutablePointer<CChar>?, Int64)) throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            let (response, returnCode) = body()
            return try Native.take(response, returnCode, .engine)
        }
    }

    /// Runs a native call that returns only a status code.
    private func call(_ body: () -> Int64) throws(SzError) {
        try state.execute { () throws(SzError) in
            try Native.check(body(), .engine)
        }
    }

    public func primeEngine() throws(SzError) {
        try call { Sz_primeEngine() }
    }

    public func getStats() throws(SzError) -> String {
        try call {
            let result = Sz_stats_helper()
            return (result.response, result.returnCode)
        }
    }

    @discardableResult
    public func addRecord(
        dataSourceCode: String, recordID: String, recordDefinition: String, flags: SzFlags
    )
        throws(SzError) -> String?
    {
        guard flags.contains(.withInfo) else {
            try call { Sz_addRecord(dataSourceCode, recordID, recordDefinition) }
            return nil
        }
        return try call {
            let result = Sz_addRecordWithInfo_helper(dataSourceCode, recordID, recordDefinition, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func getRecordPreview(_ recordDefinition: String, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_getRecordPreview_helper(recordDefinition, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    @discardableResult
    public func deleteRecord(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String? {
        guard flags.contains(.withInfo) else {
            try call { Sz_deleteRecord(dataSourceCode, recordID) }
            return nil
        }
        return try call {
            let result = Sz_deleteRecordWithInfo_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    @discardableResult
    public func reevaluateRecord(
        dataSourceCode: String, recordID: String, flags: SzFlags
    ) throws(SzError)
        -> String?
    {
        guard flags.contains(.withInfo) else {
            try call { Sz_reevaluateRecord(dataSourceCode, recordID, flags.nativeValue) }
            return nil
        }
        return try call {
            let result = Sz_reevaluateRecordWithInfo_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    @discardableResult
    public func reevaluateEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String? {
        guard flags.contains(.withInfo) else {
            try call { Sz_reevaluateEntity(entityID, flags.nativeValue) }
            return nil
        }
        return try call {
            let result = Sz_reevaluateEntityWithInfo_helper(entityID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func searchByAttributes(
        _ attributes: String, searchProfile: String?, flags: SzFlags
    ) throws(SzError)
        -> String
    {
        try call {
            if let searchProfile, !searchProfile.isEmpty {
                let result = Sz_searchByAttributes_V3_helper(attributes, searchProfile, flags.nativeValue)
                return (result.response, result.returnCode)
            }
            let result = Sz_searchByAttributes_V2_helper(attributes, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func whySearch(
        _ attributes: String, entityID: Int64, searchProfile: String?, flags: SzFlags
    )
        throws(SzError) -> String
    {
        // A nil (or empty) profile passes NULL: the engine's default profile.
        let profile = searchProfile.flatMap { $0.isEmpty ? nil : $0 }
        return try call {
            let result = Sz_whySearch_V2_helper(attributes, entityID, profile, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func getEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_getEntityByEntityID_V2_helper(entityID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func getEntity(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_getEntityByRecordID_V2_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func getRecord(dataSourceCode: String, recordID: String, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_getRecord_V2_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func findInterestingEntities(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_findInterestingEntitiesByEntityID_helper(entityID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func findInterestingEntities(
        dataSourceCode: String, recordID: String, flags: SzFlags
    )
        throws(SzError) -> String
    {
        try call {
            let result = Sz_findInterestingEntitiesByRecordID_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func findPath(
        startEntityID: Int64,
        endEntityID: Int64,
        maxDegrees: Int,
        avoidEntityIDs: Set<Int64>,
        requiredDataSources: Set<String>,
        flags: SzFlags
    ) throws(SzError) -> String {
        let degrees = Int64(maxDegrees)
        let native = flags.nativeValue
        let avoid = JSONText.entityIDs(avoidEntityIDs)
        let required = JSONText.dataSources(requiredDataSources)
        return try call {
            if avoidEntityIDs.isEmpty && requiredDataSources.isEmpty {
                let result = Sz_findPathByEntityID_V2_helper(startEntityID, endEntityID, degrees, native)
                return (result.response, result.returnCode)
            }
            if requiredDataSources.isEmpty {
                let result = Sz_findPathByEntityIDWithAvoids_V2_helper(
                    startEntityID, endEntityID, degrees, avoid, native)
                return (result.response, result.returnCode)
            }
            let result = Sz_findPathByEntityIDIncludingSource_V2_helper(
                startEntityID, endEntityID, degrees, avoid, required, native)
            return (result.response, result.returnCode)
        }
    }

    public func findPath(
        startDataSourceCode: String,
        startRecordID: String,
        endDataSourceCode: String,
        endRecordID: String,
        maxDegrees: Int,
        avoidRecordKeys: Set<SzRecordKey>,
        requiredDataSources: Set<String>,
        flags: SzFlags
    ) throws(SzError) -> String {
        let degrees = Int64(maxDegrees)
        let native = flags.nativeValue
        let avoid = JSONText.recordKeys(avoidRecordKeys)
        let required = JSONText.dataSources(requiredDataSources)
        return try call {
            if avoidRecordKeys.isEmpty && requiredDataSources.isEmpty {
                let result = Sz_findPathByRecordID_V2_helper(
                    startDataSourceCode, startRecordID, endDataSourceCode, endRecordID, degrees, native)
                return (result.response, result.returnCode)
            }
            if requiredDataSources.isEmpty {
                let result = Sz_findPathByRecordIDWithAvoids_V2_helper(
                    startDataSourceCode, startRecordID, endDataSourceCode, endRecordID, degrees, avoid, native)
                return (result.response, result.returnCode)
            }
            let result = Sz_findPathByRecordIDIncludingSource_V2_helper(
                startDataSourceCode, startRecordID, endDataSourceCode, endRecordID, degrees, avoid, required,
                native)
            return (result.response, result.returnCode)
        }
    }

    public func findNetwork(
        entityIDs: Set<Int64>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags
    ) throws(SzError) -> String {
        let entities = JSONText.entityIDs(entityIDs)
        return try call {
            let result = Sz_findNetworkByEntityID_V2_helper(
                entities, Int64(maxDegrees), Int64(buildOutDegrees), Int64(buildOutMaxEntities), flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func findNetwork(
        recordKeys: Set<SzRecordKey>,
        maxDegrees: Int,
        buildOutDegrees: Int,
        buildOutMaxEntities: Int,
        flags: SzFlags
    ) throws(SzError) -> String {
        let records = JSONText.recordKeys(recordKeys)
        return try call {
            let result = Sz_findNetworkByRecordID_V2_helper(
                records, Int64(maxDegrees), Int64(buildOutDegrees), Int64(buildOutMaxEntities), flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func whyRecordInEntity(
        dataSourceCode: String, recordID: String, flags: SzFlags
    ) throws(SzError)
        -> String
    {
        try call {
            let result = Sz_whyRecordInEntity_V2_helper(dataSourceCode, recordID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func whyRecords(
        dataSourceCode1: String,
        recordID1: String,
        dataSourceCode2: String,
        recordID2: String,
        flags: SzFlags
    ) throws(SzError) -> String {
        try call {
            let result = Sz_whyRecords_V2_helper(
                dataSourceCode1, recordID1, dataSourceCode2, recordID2, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func whyEntities(entityID1: Int64, entityID2: Int64, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_whyEntities_V2_helper(entityID1, entityID2, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func howEntity(_ entityID: Int64, flags: SzFlags) throws(SzError) -> String {
        try call {
            let result = Sz_howEntityByEntityID_V2_helper(entityID, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func getVirtualEntity(_ recordKeys: Set<SzRecordKey>, flags: SzFlags) throws(SzError) -> String {
        let records = JSONText.recordKeys(recordKeys)
        return try call {
            let result = Sz_getVirtualEntityByRecordID_V2_helper(records, flags.nativeValue)
            return (result.response, result.returnCode)
        }
    }

    public func exportJsonEntityReport(flags: SzFlags) throws(SzError) -> SzExportHandle {
        try state.execute { () throws(SzError) -> SzExportHandle in
            let result = Sz_exportJSONEntityReport_helper(flags.nativeValue)
            try Native.check(result.returnCode, .engine)
            return SzExportHandle(rawValue: result.exportHandle)
        }
    }

    public func exportCsvEntityReport(csvColumnList: String, flags: SzFlags) throws(SzError) -> SzExportHandle {
        try state.execute { () throws(SzError) -> SzExportHandle in
            let result = Sz_exportCSVEntityReport_helper(csvColumnList, flags.nativeValue)
            try Native.check(result.returnCode, .engine)
            return SzExportHandle(rawValue: result.exportHandle)
        }
    }

    public func fetchNext(_ exportHandle: SzExportHandle) throws(SzError) -> String? {
        let line = try call {
            let result = Sz_fetchNext_helper(exportHandle.rawValue)
            return (result.response, result.returnCode)
        }
        return line.isEmpty ? nil : line
    }

    public func closeExportReport(_ exportHandle: SzExportHandle) throws(SzError) {
        // Export handles are released by their own close call, not SzHelper_free.
        try call { Sz_closeExportReport_helper(exportHandle.rawValue) }
    }

    @discardableResult
    public func processRedoRecord(_ redoRecord: String, flags: SzFlags) throws(SzError) -> String? {
        guard flags.contains(.withInfo) else {
            try call { Sz_processRedoRecord(redoRecord) }
            return nil
        }
        // The native helper takes no flags: the info is implied.
        return try call {
            let result = Sz_processRedoRecordWithInfo_helper(redoRecord)
            return (result.response, result.returnCode)
        }
    }

    public func getRedoRecord() throws(SzError) -> String? {
        let redo = try call {
            let result = Sz_getRedoRecord_helper()
            return (result.response, result.returnCode)
        }
        return redo.isEmpty ? nil : redo
    }

    public func countRedoRecords() throws(SzError) -> Int64 {
        try state.execute { () throws(SzError) -> Int64 in
            try Native.count(Sz_countRedoRecords(), .engine)
        }
    }
}
