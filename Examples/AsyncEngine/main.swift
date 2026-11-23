// example_async_engine: load records concurrently from Swift concurrency with
// SzAsyncEngine, then read results with async/await.
//
// Run: swift run example_async_engine

import Foundation
import SenzingSDK
import SenzingTestSupport

/// A contact as an app would model it, encoded with Senzing attribute names.
struct Contact: Codable, Sendable {
    var id: String
    var name: String
    var email: String?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case id = "RECORD_ID"
        case name = "NAME_FULL"
        case email = "EMAIL_ADDRESS"
        case phone = "PHONE_NUMBER"
    }
}

let contacts = [
    Contact(id: "1", name: "Robert Smith", email: "bob@example.com", phone: "702-555-0100"),
    Contact(id: "2", name: "Bob Smith", email: "bob@example.com"),
    Contact(id: "3", name: "Rob Smith", phone: "702-555-0100"),
    Contact(id: "4", name: "Jane Doe", email: "jane@example.com"),
]

func run() async throws {
    let repository = try ExampleRepository(dataSources: ["CONTACTS"])
    defer { repository.remove() }
    let environment = try SzCoreEnvironment(instanceName: "example_async_engine", settings: repository.settings)
    defer { environment.destroy() }
    let engine = SzAsyncEngine(try environment.getEngine())

    try await withThrowingTaskGroup(of: Void.self) { group in
        for contact in contacts {
            group.addTask {
                try await engine.addRecord(dataSourceCode: "CONTACTS", recordID: contact.id, record: contact)
            }
        }
        try await group.waitForAll()
    }
    try await engine.processRedoRecords()

    var groups: [Int64: [String]] = [:]
    for contact in contacts {
        let entity = try await engine.getEntity(
            dataSourceCode: "CONTACTS", recordID: contact.id, as: SzEntityResponse.self)
        groups[entity.resolvedEntity.entityID, default: []].append(contact.name)
    }
    for (entityID, names) in groups.sorted(by: { $0.key < $1.key }) {
        print("Entity \(entityID): \(names.joined(separator: ", "))")
    }
    guard groups.count < contacts.count else {
        throw ExampleFailure("expected some contacts to resolve together")
    }
    print("\(contacts.count) contacts are \(groups.count) people.")
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("example_async_engine failed: \(error)\n".utf8))
    exit(1)
}
