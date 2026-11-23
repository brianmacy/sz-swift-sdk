// example_search: load the truth set and search it by attributes.
//
// Run: swift run example_search

import Foundation
import SenzingSDK
import SenzingTestSupport

/// Search attributes, encoded with Senzing attribute names.
struct SearchAttributes: Encodable {
    var name: String
    var dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
        case name = "NAME_FULL"
        case dateOfBirth = "DATE_OF_BIRTH"
    }
}

func run() throws {
    let repository = try ExampleRepository()
    defer { repository.remove() }
    let environment = try SzCoreEnvironment(instanceName: "example_search", settings: repository.settings)
    defer { environment.destroy() }
    let engine = try environment.getEngine()
    try repository.loadTruthset(into: engine)

    let query = SearchAttributes(name: "Robert Smith", dateOfBirth: "12/11/1978")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let json = String(decoding: try encoder.encode(query), as: UTF8.self)
    let response = try engine.searchByAttributes(json, as: SzSearchResponse.self)
    print("Search \(json) found \(response.resolvedEntities.count) entities:")
    for result in response.resolvedEntities {
        let entity = result.entity.resolvedEntity
        let level = result.matchInfo.matchLevelCode ?? "?"
        let key = result.matchInfo.matchKey ?? ""
        print("  entity \(entity.entityID) \(entity.entityName ?? "?"): \(level) \(key)")
    }
    guard response.resolvedEntities.first?.matchInfo.matchLevelCode == "RESOLVED" else {
        throw ExampleFailure("expected a RESOLVED best match")
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("example_search failed: \(error)\n".utf8))
    exit(1)
}
