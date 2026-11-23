import Foundation

/// A record from the Senzing truth set.
public struct TruthsetRecord: Sendable {
    public let dataSourceCode: String
    public let recordID: String
    /// The record definition (one JSON line).
    public let definition: String
}

/// The Senzing demo truth set bundled with the tests (see
/// `Resources/truthset/README.md`).
public enum Truthset {
    /// The truth set's data sources.
    public static let dataSources = ["CUSTOMERS", "REFERENCE", "WATCHLIST"]

    /// The records of one truth-set file (`customers`, `reference` or `watchlist`).
    public static func records(_ file: String) throws -> [TruthsetRecord] {
        guard let url = Bundle.module.url(forResource: file, withExtension: "jsonl", subdirectory: "truthset") else {
            throw TestRepositoryError(description: "Truth-set file \(file).jsonl is not in the bundle")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(whereSeparator: \.isNewline).map { line in
            let definition = String(line)
            let object = try JSONSerialization.jsonObject(with: Data(definition.utf8)) as? [String: Any]
            guard
                let dataSource = object?["DATA_SOURCE"] as? String,
                let recordID = object?["RECORD_ID"] as? String
            else {
                throw TestRepositoryError(description: "Truth-set line lacks DATA_SOURCE/RECORD_ID: \(definition)")
            }
            return TruthsetRecord(dataSourceCode: dataSource, recordID: recordID, definition: definition)
        }
    }

    /// Every truth-set record: customers, then reference, then watchlist.
    public static func allRecords() throws -> [TruthsetRecord] {
        try records("customers") + records("reference") + records("watchlist")
    }
}
