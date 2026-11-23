/// Identifies a record by its data source code and record ID.
///
/// The C# SDK uses `(string dataSourceCode, string recordID)` tuples; Swift
/// tuples cannot live in a `Set`, so this SDK uses this value type instead.
public struct SzRecordKey: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    /// The data source code, for example `"CUSTOMERS"`.
    public let dataSourceCode: String
    /// The record ID within the data source.
    public let recordID: String

    public init(dataSourceCode: String, recordID: String) {
        self.dataSourceCode = dataSourceCode
        self.recordID = recordID
    }

    /// Creates a record key, mirroring C# `SzRecordKey.Of`.
    public static func of(_ dataSourceCode: String, _ recordID: String) -> SzRecordKey {
        SzRecordKey(dataSourceCode: dataSourceCode, recordID: recordID)
    }

    public static func < (lhs: SzRecordKey, rhs: SzRecordKey) -> Bool {
        (lhs.dataSourceCode, lhs.recordID) < (rhs.dataSourceCode, rhs.recordID)
    }

    public var description: String { "\(dataSourceCode):\(recordID)" }

    enum CodingKeys: String, CodingKey {
        case dataSourceCode = "DATA_SOURCE"
        case recordID = "RECORD_ID"
    }
}
