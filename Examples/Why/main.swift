// example_why: explain why two records resolved together, and why two
// entities are related but not resolved.
//
// Run: swift run example_why

import Foundation
import SenzingSDK
import SenzingTestSupport

func describe(_ result: SzWhyResult) -> String {
    let info = result.matchInfo
    let scores = (info.featureScores ?? [:]).keys.sorted().compactMap { feature -> String? in
        guard let best = info.featureScores?[feature]?.first, let score = best.score else {
            return nil
        }
        return "\(feature)=\(score)"
    }
    return "\(info.matchLevelCode ?? "?") via \(info.whyKey ?? "?") [\(scores.joined(separator: ", "))]"
}

func run() throws {
    let repository = try ExampleRepository()
    defer { repository.remove() }
    let environment = try SzCoreEnvironment(instanceName: "example_why", settings: repository.settings)
    defer { environment.destroy() }
    let engine = try environment.getEngine()
    try repository.loadTruthset(into: engine)

    let records = try engine.whyRecords(
        dataSourceCode1: "CUSTOMERS",
        recordID1: "1001",
        dataSourceCode2: "CUSTOMERS",
        recordID2: "1002",
        as: SzWhyResponse.self
    )
    guard let recordsWhy = records.whyResults.first else {
        throw ExampleFailure("no why result for CUSTOMERS 1001 / 1002")
    }
    print("Why CUSTOMERS 1001 and 1002: \(describe(recordsWhy))")

    let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
    guard let related = entity.relatedEntities?.first else {
        throw ExampleFailure("entity \(entity.resolvedEntity.entityID) has no related entities")
    }
    let entities = try engine.whyEntities(
        entityID1: entity.resolvedEntity.entityID,
        entityID2: related.entityID,
        as: SzWhyResponse.self
    )
    guard let entitiesWhy = entities.whyResults.first else {
        throw ExampleFailure("no why result for the related entities")
    }
    print("Why entity \(entity.resolvedEntity.entityID) and \(related.entityID): \(describe(entitiesWhy))")

    // The full explanation is the engine's JSON; the typed models cover the common parts.
    let how = try engine.howEntity(entity.resolvedEntity.entityID)
    print("How entity \(entity.resolvedEntity.entityID) was built: \(how.utf8.count) bytes of JSON")
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("example_why failed: \(error)\n".utf8))
    exit(1)
}
