import Foundation
import SenzingSDK

/// An example failure: examples exit non-zero when their result is wrong.
public struct ExampleFailure: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// The repository an example program runs against.
///
/// When `SENZING_ENGINE_CONFIGURATION_JSON` is set, examples use that
/// repository (its default configuration must already register the data
/// sources they load). Otherwise they create a throwaway SQLite repository,
/// deleted by ``remove()``.
public struct ExampleRepository: Sendable {
    /// The engine settings JSON.
    public let settings: String
    private let temporary: TestRepository?

    public init(dataSources: [String] = Truthset.dataSources) throws {
        let environment = ProcessInfo.processInfo.environment
        if let settings = environment["SENZING_ENGINE_CONFIGURATION_JSON"], !settings.isEmpty {
            self.settings = settings
            temporary = nil
        } else {
            let repository = try TestRepository(dataSources: dataSources)
            settings = repository.settings
            temporary = repository
        }
    }

    /// Loads the truth set and processes the redo records it produces.
    public func loadTruthset(into engine: any SzEngine) throws {
        for record in try Truthset.allRecords() {
            try engine.addRecord(
                dataSourceCode: record.dataSourceCode,
                recordID: record.recordID,
                recordDefinition: record.definition
            )
        }
        while let redo = try engine.getRedoRecord() {
            try engine.processRedoRecord(redo)
        }
    }

    /// Deletes the throwaway repository, if one was created.
    public func remove() {
        temporary?.remove()
    }
}
