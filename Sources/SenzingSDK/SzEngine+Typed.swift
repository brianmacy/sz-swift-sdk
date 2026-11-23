// Typed (Codable) variants of the common SzEngine calls.
//
// Each `as:` method makes the same native call as its raw counterpart and
// decodes the JSON into any `Decodable` type: the models in this module (for
// example ``SzEntityResponse``) or your own. Decoding failures throw
// ``SzErrorKind/json``.

extension SzEngine {
    /// Adds or replaces a record given as any `Encodable` value.
    ///
    /// The value is encoded with `JSONEncoder`, so its coding keys must be
    /// Senzing attribute names (for example `NAME_FULL`, `EMAIL_ADDRESS`).
    @discardableResult
    public func addRecord<Record: Encodable>(
        dataSourceCode: String,
        recordID: String,
        record: Record,
        flags: SzFlags = .addRecordDefaultFlags
    ) throws(SzError) -> String? {
        try addRecord(
            dataSourceCode: dataSourceCode,
            recordID: recordID,
            recordDefinition: SzJSON.encode(record),
            flags: flags
        )
    }

    /// Adds or replaces a record and returns the decoded info
    /// (``SzFlags/withInfo`` is added to `flags`).
    public func addRecord<T: Decodable>(
        dataSourceCode: String,
        recordID: String,
        recordDefinition: String,
        flags: SzFlags = .addRecordDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        let info = try addRecord(
            dataSourceCode: dataSourceCode,
            recordID: recordID,
            recordDefinition: recordDefinition,
            flags: flags.union(.withInfo)
        )
        return try SzJSON.decode(type, from: info)
    }

    /// Deletes a record and returns the decoded info (``SzFlags/withInfo`` is
    /// added to `flags`).
    public func deleteRecord<T: Decodable>(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .deleteRecordDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        let info = try deleteRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags.union(.withInfo))
        return try SzJSON.decode(type, from: info)
    }

    /// Returns an entity by its entity ID, decoded.
    public func getEntity<T: Decodable>(
        _ entityID: Int64, flags: SzFlags = .entityDefaultFlags, as type: T.Type
    )
        throws(SzError) -> T
    {
        try SzJSON.decode(type, from: getEntity(entityID, flags: flags))
    }

    /// Returns the entity that contains a record, decoded.
    public func getEntity<T: Decodable>(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .entityDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        try SzJSON.decode(type, from: getEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags))
    }

    /// Searches by attributes and returns the decoded results.
    public func searchByAttributes<T: Decodable>(
        _ attributes: String,
        searchProfile: String? = nil,
        flags: SzFlags = .searchByAttributesDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        try SzJSON.decode(type, from: searchByAttributes(attributes, searchProfile: searchProfile, flags: flags))
    }

    /// Explains why two entities did not resolve, decoded.
    public func whyEntities<T: Decodable>(
        entityID1: Int64,
        entityID2: Int64,
        flags: SzFlags = .whyEntitiesDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        try SzJSON.decode(type, from: whyEntities(entityID1: entityID1, entityID2: entityID2, flags: flags))
    }

    /// Explains why two records did, or did not, resolve, decoded.
    public func whyRecords<T: Decodable>(
        dataSourceCode1: String,
        recordID1: String,
        dataSourceCode2: String,
        recordID2: String,
        flags: SzFlags = .whyRecordsDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        let json = try whyRecords(
            dataSourceCode1: dataSourceCode1,
            recordID1: recordID1,
            dataSourceCode2: dataSourceCode2,
            recordID2: recordID2,
            flags: flags
        )
        return try SzJSON.decode(type, from: json)
    }

    /// Explains why a record belongs to its entity, decoded.
    public func whyRecordInEntity<T: Decodable>(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .whyRecordInEntityDefaultFlags,
        as type: T.Type
    ) throws(SzError) -> T {
        try SzJSON.decode(
            type, from: whyRecordInEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags))
    }

    /// Exports every entity and returns the raw JSON lines.
    ///
    /// Reads the whole report into memory and always closes the export
    /// handle. For very large repositories, iterate with
    /// ``exportJsonEntityReport(flags:)`` and ``fetchNext(_:)`` instead.
    public func exportJsonEntityLines(flags: SzFlags = .exportDefaultFlags) throws(SzError) -> [String] {
        let handle = try exportJsonEntityReport(flags: flags)
        let read = Result { () throws(SzError) -> [String] in
            var lines: [String] = []
            while let line = try fetchNext(handle) {
                lines.append(line)
            }
            return lines
        }
        // Always close the handle; a read error takes precedence over a close error.
        let closed = Result { () throws(SzError) in try closeExportReport(handle) }
        let lines = try read.get()
        try closed.get()
        return lines
    }

    /// Exports every entity, decoding each line (typically into
    /// ``SzEntityResponse``).
    public func exportJsonEntityReport<T: Decodable>(
        flags: SzFlags = .exportDefaultFlags, as type: T.Type
    )
        throws(SzError) -> [T]
    {
        var entities: [T] = []
        for line in try exportJsonEntityLines(flags: flags) {
            entities.append(try SzJSON.decode(type, from: line))
        }
        return entities
    }
}
