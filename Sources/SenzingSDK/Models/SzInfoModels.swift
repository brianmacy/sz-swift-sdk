/// The response of ``SzProduct/getVersion()``.
public struct SzVersionInfo: Codable, Hashable, Sendable {
    public var productName: String
    /// The version, for example `4.5.0`.
    public var version: String
    public var buildVersion: String
    public var buildDate: String
    public var buildNumber: String
    public var compatibilityVersion: CompatibilityVersion?
    public var schemaVersion: SchemaVersion?

    public struct CompatibilityVersion: Codable, Hashable, Sendable {
        public var configVersion: String

        enum CodingKeys: String, CodingKey {
            case configVersion = "CONFIG_VERSION"
        }
    }

    public struct SchemaVersion: Codable, Hashable, Sendable {
        public var engineSchemaVersion: String
        public var minimumRequiredSchemaVersion: String
        public var maximumRequiredSchemaVersion: String

        enum CodingKeys: String, CodingKey {
            case engineSchemaVersion = "ENGINE_SCHEMA_VERSION"
            case minimumRequiredSchemaVersion = "MINIMUM_REQUIRED_SCHEMA_VERSION"
            case maximumRequiredSchemaVersion = "MAXIMUM_REQUIRED_SCHEMA_VERSION"
        }
    }

    enum CodingKeys: String, CodingKey {
        case productName = "PRODUCT_NAME"
        case version = "VERSION"
        case buildVersion = "BUILD_VERSION"
        case buildDate = "BUILD_DATE"
        case buildNumber = "BUILD_NUMBER"
        case compatibilityVersion = "COMPATIBILITY_VERSION"
        case schemaVersion = "SCHEMA_VERSION"
    }
}

/// The response of ``SzProduct/getLicense()``.
public struct SzLicenseInfo: Codable, Hashable, Sendable {
    public var customer: String?
    public var contract: String?
    public var issueDate: String?
    public var licenseType: String?
    public var licenseLevel: String?
    public var billing: String?
    public var expireDate: String?
    /// The maximum number of records the license allows.
    public var recordLimit: Int64?
}

/// The response of ``SzConfigManager/getConfigRegistry()``.
public struct SzConfigRegistry: Codable, Hashable, Sendable {
    public var configs: [Entry]

    /// A registered configuration.
    public struct Entry: Codable, Hashable, Sendable {
        public var configID: Int64
        public var configComments: String?
        /// When the configuration was registered.
        public var createdDate: String?

        enum CodingKeys: String, CodingKey {
            case configID = "CONFIG_ID"
            case configComments = "CONFIG_COMMENTS"
            case createdDate = "SYS_CREATE_DT"
        }
    }

    enum CodingKeys: String, CodingKey {
        case configs = "CONFIGS"
    }
}

/// The response of ``SzConfig/getDataSourceRegistry()``.
public struct SzDataSourceRegistry: Codable, Hashable, Sendable {
    public var dataSources: [Entry]

    /// A registered data source.
    public struct Entry: Codable, Hashable, Sendable {
        public var dataSourceID: Int64
        public var dataSourceCode: String

        enum CodingKeys: String, CodingKey {
            case dataSourceID = "DSRC_ID"
            case dataSourceCode = "DSRC_CODE"
        }
    }

    /// The registered data source codes.
    public var dataSourceCodes: [String] {
        dataSources.map(\.dataSourceCode)
    }

    enum CodingKeys: String, CodingKey {
        case dataSources = "DATA_SOURCES"
    }
}
