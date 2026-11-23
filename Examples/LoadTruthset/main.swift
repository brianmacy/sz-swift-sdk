// example_load_truthset: create a repository, register data sources, load the
// Senzing truth set, and report how the records resolved.
//
// Run: swift run example_load_truthset
//
// Uses the repository in SENZING_ENGINE_CONFIGURATION_JSON when it is set
// (its default configuration must already register CUSTOMERS, REFERENCE and
// WATCHLIST); otherwise creates a throwaway SQLite repository.

import Foundation
import SenzingSDK
import SenzingTestSupport

func run() throws {
    let repository = try ExampleRepository()
    defer { repository.remove() }

    let environment = try SzCoreEnvironment(instanceName: "example_load_truthset", settings: repository.settings)
    defer { environment.destroy() }
    let engine = try environment.getEngine()

    let records = try Truthset.allRecords()
    var affected = Set<Int64>()
    for record in records {
        let info = try engine.addRecord(
            dataSourceCode: record.dataSourceCode,
            recordID: record.recordID,
            recordDefinition: record.definition,
            as: SzWithInfoResponse.self
        )
        affected.formUnion(info.affectedEntities.map(\.entityID))
    }
    // Loading defers some re-resolution work as redo records; finish it.
    var redone = 0
    while let redo = try engine.getRedoRecord() {
        try engine.processRedoRecord(redo)
        redone += 1
    }

    let entities = try engine.exportJsonEntityReport(as: SzEntityResponse.self)
    let multiRecord = entities.filter { ($0.resolvedEntity.records?.count ?? 0) > 1 }
    print("Loaded \(records.count) records (\(redone) redo records processed).")
    print("They resolved into \(entities.count) entities; \(multiRecord.count) have more than one record.")

    let robert = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
    let members = (robert.resolvedEntity.records ?? []).map(\.recordKey.description).sorted()
    print("Entity \(robert.resolvedEntity.entityID) (\(robert.resolvedEntity.entityName ?? "?")): \(members)")
    guard members.count >= 4 else {
        throw ExampleFailure("expected CUSTOMERS 1001-1004 to resolve together, got \(members)")
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("example_load_truthset failed: \(error)\n".utf8))
    exit(1)
}
