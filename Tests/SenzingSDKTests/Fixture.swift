import SenzingSDK
import SenzingTestSupport
import Testing

/// The root of every suite that uses the native engine.
///
/// The native engine is a process-wide singleton, so every engine suite is
/// nested here and inherits `.serialized`: no two tests share the engine.
@Suite(.serialized)
struct EngineTests {}

/// A fresh repository and environment for one test. No mocks: the real
/// engine over a new SQLite repository, deleted again on `deinit`.
final class EngineFixture {
    let repository: TestRepository
    let environment: SzCoreEnvironment
    let engine: any SzEngine

    /// - Parameter loadTruthset: Whether to load the whole truth set (and
    ///   process its redo records) before the test.
    init(loadTruthset: Bool = false, dataSources: [String] = Truthset.dataSources) throws {
        repository = try TestRepository(dataSources: dataSources)
        environment = try repository.makeEnvironment()
        engine = try environment.getEngine()
        if loadTruthset {
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
    }

    deinit {
        environment.destroy()
        repository.remove()
    }

    /// The entity ID of the entity that contains a record.
    func entityID(_ dataSourceCode: String, _ recordID: String) throws -> Int64 {
        try engine.getEntity(dataSourceCode: dataSourceCode, recordID: recordID, as: SzEntityResponse.self)
            .resolvedEntity.entityID
    }
}

/// Runs `body` and requires it to throw an ``SzError`` of `kind` (or a descendant).
@discardableResult
func expectSzError(
    _ kind: SzErrorKind,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> Void
) -> SzError? {
    do {
        try body()
        Issue.record("Expected \(kind.rawValue), but nothing was thrown", sourceLocation: sourceLocation)
        return nil
    } catch let error as SzError {
        #expect(error.isKind(of: kind), "Expected \(kind.rawValue), got \(error)", sourceLocation: sourceLocation)
        return error
    } catch {
        Issue.record("Expected \(kind.rawValue), got non-SzError \(error)", sourceLocation: sourceLocation)
        return nil
    }
}

/// A record definition with a full name and optional extra attributes.
func person(_ name: String, _ extra: [String: String] = [:]) -> String {
    var fields = ["NAME_FULL": name]
    fields.merge(extra) { _, new in new }
    let body = fields.sorted { $0.key < $1.key }.map { "\"\($0.key)\":\"\($0.value)\"" }
    return "{" + body.joined(separator: ",") + "}"
}
