/// The response of ``SzEngine/searchByAttributes(_:searchProfile:flags:)``.
public struct SzSearchResponse: Codable, Hashable, Sendable {
    /// The matching entities, best first.
    public var resolvedEntities: [SzSearchResult]

    enum CodingKeys: String, CodingKey {
        case resolvedEntities = "RESOLVED_ENTITIES"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolvedEntities = try container.decodeIfPresent([SzSearchResult].self, forKey: .resolvedEntities) ?? []
    }
}

/// One search result: an entity and how it matched the search attributes.
public struct SzSearchResult: Codable, Hashable, Sendable {
    /// How the entity matched.
    public var matchInfo: SzMatchInfo
    /// The entity.
    public var entity: SzEntityResponse

    enum CodingKeys: String, CodingKey {
        case matchInfo = "MATCH_INFO"
        case entity = "ENTITY"
    }
}

/// How two things matched: match level, key, rule, and feature scores.
public struct SzMatchInfo: Codable, Hashable, Sendable {
    /// The match level, for example `RESOLVED` or `POSSIBLY_SAME`.
    public var matchLevelCode: String?
    /// The match key, for example `+NAME+DOB`.
    public var matchKey: String?
    /// The rule that matched.
    public var resolutionRuleCode: String?
    /// The key that explains a why result.
    public var whyKey: String?
    /// The rule that explains a why result.
    public var whyResolutionRuleCode: String?
    /// The feature comparisons by feature type (present with
    /// ``SzFlags/includeFeatureScores``).
    public var featureScores: [String: [SzFeatureScore]]?
    /// The candidate keys the match shares, by key type.
    public var candidateKeys: [String: [SzCandidateKey]]?

    enum CodingKeys: String, CodingKey {
        case matchLevelCode = "MATCH_LEVEL_CODE"
        case matchKey = "MATCH_KEY"
        case resolutionRuleCode = "ERRULE_CODE"
        case whyKey = "WHY_KEY"
        case whyResolutionRuleCode = "WHY_ERRULE_CODE"
        case featureScores = "FEATURE_SCORES"
        case candidateKeys = "CANDIDATE_KEYS"
    }
}

/// The comparison of one inbound feature with one candidate feature.
public struct SzFeatureScore: Codable, Hashable, Sendable {
    public var inboundFeatureID: Int64?
    public var inboundFeatureDescription: String?
    public var inboundFeatureUsageType: String?
    public var candidateFeatureID: Int64?
    public var candidateFeatureDescription: String?
    public var candidateFeatureUsageType: String?
    /// The score, 0 to 100.
    public var score: Int?
    /// The score bucket, for example `SAME`, `CLOSE` or `NO_CHANCE`.
    public var scoreBucket: String?
    /// The comparison behavior code.
    public var scoreBehavior: String?
    /// Component scores, for example `GNR_FN` for names.
    public var additionalScores: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case inboundFeatureID = "INBOUND_FEAT_ID"
        case inboundFeatureDescription = "INBOUND_FEAT_DESC"
        case inboundFeatureUsageType = "INBOUND_FEAT_USAGE_TYPE"
        case candidateFeatureID = "CANDIDATE_FEAT_ID"
        case candidateFeatureDescription = "CANDIDATE_FEAT_DESC"
        case candidateFeatureUsageType = "CANDIDATE_FEAT_USAGE_TYPE"
        case score = "SCORE"
        case scoreBucket = "SCORE_BUCKET"
        case scoreBehavior = "SCORE_BEHAVIOR"
        case additionalScores = "ADDITIONAL_SCORES"
    }
}

/// A candidate key shared by a match.
public struct SzCandidateKey: Codable, Hashable, Sendable {
    public var featureID: Int64?
    public var featureDescription: String?

    enum CodingKeys: String, CodingKey {
        case featureID = "FEAT_ID"
        case featureDescription = "FEAT_DESC"
    }
}

/// The response of the why methods: ``SzEngine/whyEntities(entityID1:entityID2:flags:)``,
/// ``SzEngine/whyRecords(dataSourceCode1:recordID1:dataSourceCode2:recordID2:flags:)``
/// and ``SzEngine/whyRecordInEntity(dataSourceCode:recordID:flags:)``.
public struct SzWhyResponse: Codable, Hashable, Sendable {
    /// The explanations.
    public var whyResults: [SzWhyResult]
    /// The entities involved.
    public var entities: [SzEntityResponse]

    enum CodingKeys: String, CodingKey {
        case whyResults = "WHY_RESULTS"
        case entities = "ENTITIES"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        whyResults = try container.decodeIfPresent([SzWhyResult].self, forKey: .whyResults) ?? []
        entities = try container.decodeIfPresent([SzEntityResponse].self, forKey: .entities) ?? []
    }
}

/// One why explanation, between one side and (for two-sided whys) another.
public struct SzWhyResult: Codable, Hashable, Sendable {
    public var internalID: Int64?
    /// The entity of the first side.
    public var entityID: Int64
    /// The records of the first side.
    public var focusRecords: [SzRecordKey]?
    public var internalID2: Int64?
    /// The entity of the second side (two-sided whys).
    public var entityID2: Int64?
    /// The records of the second side (two-sided whys).
    public var focusRecords2: [SzRecordKey]?
    /// How the two sides matched, or why they did not.
    public var matchInfo: SzMatchInfo

    enum CodingKeys: String, CodingKey {
        case internalID = "INTERNAL_ID"
        case entityID = "ENTITY_ID"
        case focusRecords = "FOCUS_RECORDS"
        case internalID2 = "INTERNAL_ID_2"
        case entityID2 = "ENTITY_ID_2"
        case focusRecords2 = "FOCUS_RECORDS_2"
        case matchInfo = "MATCH_INFO"
    }
}
