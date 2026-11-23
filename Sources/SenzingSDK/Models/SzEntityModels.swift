// Codable models of the engine's entity JSON.
//
// Which members are present depends on the flags of the call, so everything
// beyond the identifiers is optional. Members not modeled here remain
// available in the raw JSON returned by the non-`as:` methods.

/// The response of ``SzEngine/getEntity(_:flags:)`` and
/// ``SzEngine/getEntity(dataSourceCode:recordID:flags:)``, and one line of a
/// JSON export.
public struct SzEntityResponse: Codable, Hashable, Sendable {
    /// The entity.
    public var resolvedEntity: SzResolvedEntity
    /// Related entities (present with the relation flags).
    public var relatedEntities: [SzRelatedEntity]?

    enum CodingKeys: String, CodingKey {
        case resolvedEntity = "RESOLVED_ENTITY"
        case relatedEntities = "RELATED_ENTITIES"
    }
}

/// A resolved entity.
public struct SzResolvedEntity: Codable, Hashable, Sendable {
    /// The entity ID.
    public var entityID: Int64
    /// The best name of the entity.
    public var entityName: String?
    /// The entity's features by feature type (for example `NAME`, `ADDRESS`).
    public var features: [String: [SzEntityFeature]]?
    /// Record counts per data source.
    public var recordSummary: [SzRecordSummary]?
    /// The records that make up the entity.
    public var records: [SzEntityRecord]?

    enum CodingKeys: String, CodingKey {
        case entityID = "ENTITY_ID"
        case entityName = "ENTITY_NAME"
        case features = "FEATURES"
        case recordSummary = "RECORD_SUMMARY"
        case records = "RECORDS"
    }
}

/// A feature of an entity, with the values it was built from.
public struct SzEntityFeature: Codable, Hashable, Sendable {
    /// The representative description of the feature.
    public var featureDescription: String
    /// The library feature ID.
    public var libraryFeatureID: Int64?
    /// The usage type, for example `HOME` or `MAILING`.
    public var usageType: String?
    /// The values grouped under this feature.
    public var values: [SzFeatureValue]?

    enum CodingKeys: String, CodingKey {
        case featureDescription = "FEAT_DESC"
        case libraryFeatureID = "LIB_FEAT_ID"
        case usageType = "USAGE_TYPE"
        case values = "FEAT_DESC_VALUES"
    }
}

/// One value of an ``SzEntityFeature``.
public struct SzFeatureValue: Codable, Hashable, Sendable {
    /// The value's description.
    public var featureDescription: String
    /// The library feature ID.
    public var libraryFeatureID: Int64?

    enum CodingKeys: String, CodingKey {
        case featureDescription = "FEAT_DESC"
        case libraryFeatureID = "LIB_FEAT_ID"
    }
}

/// The number of records an entity has from one data source.
public struct SzRecordSummary: Codable, Hashable, Sendable {
    /// The data source code.
    public var dataSourceCode: String
    /// The number of records.
    public var recordCount: Int

    enum CodingKeys: String, CodingKey {
        case dataSourceCode = "DATA_SOURCE"
        case recordCount = "RECORD_COUNT"
    }
}

/// A record within an entity, with how it matched.
public struct SzEntityRecord: Codable, Hashable, Sendable {
    /// The data source code.
    public var dataSourceCode: String
    /// The record ID.
    public var recordID: String
    /// The engine's internal ID for the record's observation.
    public var internalID: SzInternalID?
    /// The match key, for example `+NAME+DOB+PHONE` (empty for the first record).
    public var matchKey: String?
    /// The match level, for example `RESOLVED` (empty for the first record).
    public var matchLevelCode: String?
    /// The resolution rule that matched (empty for the first record).
    public var resolutionRuleCode: String?

    /// The record's key.
    public var recordKey: SzRecordKey {
        SzRecordKey(dataSourceCode: dataSourceCode, recordID: recordID)
    }

    enum CodingKeys: String, CodingKey {
        case dataSourceCode = "DATA_SOURCE"
        case recordID = "RECORD_ID"
        case internalID = "INTERNAL_ID"
        case matchKey = "MATCH_KEY"
        case matchLevelCode = "MATCH_LEVEL_CODE"
        case resolutionRuleCode = "ERRULE_CODE"
    }
}

/// An entity related to another, with how they relate.
public struct SzRelatedEntity: Codable, Hashable, Sendable {
    /// The related entity's ID.
    public var entityID: Int64
    /// The best name of the related entity.
    public var entityName: String?
    /// The match level, for example `POSSIBLY_SAME`.
    public var matchLevelCode: String?
    /// The match key, for example `+NAME+ADDRESS-DOB`.
    public var matchKey: String?
    /// The rule that related the entities.
    public var resolutionRuleCode: String?
    /// `1` when the relationship was disclosed by the data.
    public var isDisclosed: Int?
    /// `1` when the relationship is ambiguous.
    public var isAmbiguous: Int?
    /// Record counts per data source of the related entity.
    public var recordSummary: [SzRecordSummary]?

    enum CodingKeys: String, CodingKey {
        case entityID = "ENTITY_ID"
        case entityName = "ENTITY_NAME"
        case matchLevelCode = "MATCH_LEVEL_CODE"
        case matchKey = "MATCH_KEY"
        case resolutionRuleCode = "ERRULE_CODE"
        case isDisclosed = "IS_DISCLOSED"
        case isAmbiguous = "IS_AMBIGUOUS"
        case recordSummary = "RECORD_SUMMARY"
    }
}

/// The info returned by record mutations when ``SzFlags/withInfo`` is set.
public struct SzWithInfoResponse: Codable, Hashable, Sendable {
    /// The data source of the record (absent for entity reevaluation).
    public var dataSourceCode: String?
    /// The record ID (absent for entity reevaluation).
    public var recordID: String?
    /// The entities the change affected.
    public var affectedEntities: [SzEntityReference]

    enum CodingKeys: String, CodingKey {
        case dataSourceCode = "DATA_SOURCE"
        case recordID = "RECORD_ID"
        case affectedEntities = "AFFECTED_ENTITIES"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataSourceCode = try container.decodeIfPresent(String.self, forKey: .dataSourceCode)
        recordID = try container.decodeIfPresent(String.self, forKey: .recordID)
        affectedEntities = try container.decodeIfPresent([SzEntityReference].self, forKey: .affectedEntities) ?? []
    }
}

/// A reference to an entity by ID.
public struct SzEntityReference: Codable, Hashable, Sendable {
    /// The entity ID.
    public var entityID: Int64

    enum CodingKeys: String, CodingKey {
        case entityID = "ENTITY_ID"
    }
}
