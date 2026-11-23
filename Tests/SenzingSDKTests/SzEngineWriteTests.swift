import Foundation
import SenzingSDK
import SenzingTestSupport
import Testing

/// A contact as an app would model it, encoded with Senzing attribute names.
struct Contact: Codable, Sendable {
    var fullName: String
    var email: String?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "NAME_FULL"
        case email = "EMAIL_ADDRESS"
        case phone = "PHONE_NUMBER"
    }
}

extension EngineTests {
    @Suite("SzEngine writes")
    struct SzEngineWriteTests {
        @Test("test_addRecord returns info only with withInfo")
        func test_addRecord() throws {
            let fixture = try EngineFixture()
            let engine = fixture.engine
            let none = try engine.addRecord(
                dataSourceCode: "CUSTOMERS", recordID: "1", recordDefinition: person("Ann Lee"))
            #expect(none == nil)
            let info = try engine.addRecord(
                dataSourceCode: "CUSTOMERS",
                recordID: "2",
                recordDefinition: person("Ann Lee", ["EMAIL_ADDRESS": "ann@example.com"]),
                flags: .withInfo
            )
            #expect(try #require(info).contains(#""RECORD_ID":"2""#))

            let typed = try engine.addRecord(
                dataSourceCode: "CUSTOMERS",
                recordID: "3",
                recordDefinition: person("Ann Lee", ["EMAIL_ADDRESS": "ann@example.com"]),
                as: SzWithInfoResponse.self
            )
            #expect(typed.dataSourceCode == "CUSTOMERS")
            #expect(typed.recordID == "3")
            #expect(typed.affectedEntities.count == 1)
            #expect(try fixture.entityID("CUSTOMERS", "2") == fixture.entityID("CUSTOMERS", "3"))
        }

        @Test("test_addRecord encodes an Encodable record")
        func test_addEncodableRecord() throws {
            let fixture = try EngineFixture()
            let contact = Contact(fullName: "Robert Smith", email: "bob@example.com", phone: "702-555-0100")
            try fixture.engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "C1", record: contact)
            let record = try fixture.engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "C1")
            #expect(record.contains("bob@example.com"))
            expectSzError(.json) {
                try fixture.engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "C2", record: ["N": Double.nan])
            }
        }

        @Test("test_addRecord rejects bad input")
        func test_addRecordErrors() throws {
            let fixture = try EngineFixture()
            let unknown = expectSzError(.unknownDataSource) {
                try fixture.engine.addRecord(dataSourceCode: "NOPE", recordID: "1", recordDefinition: person("A B"))
            }
            #expect(unknown?.errorCode == 2207)
            expectSzError(.badInput) {
                try fixture.engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1", recordDefinition: "{bad")
            }
            expectSzError(.badInput) {
                try fixture.engine.addRecord(
                    dataSourceCode: "CUSTOMERS",
                    recordID: "1",
                    recordDefinition: "{bad",
                    flags: .withInfo
                )
            }
        }

        @Test("test_deleteRecord with and without info")
        func test_deleteRecord() throws {
            let fixture = try EngineFixture()
            let engine = fixture.engine
            for id in ["1", "2", "3"] {
                try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: id, recordDefinition: person("Zed \(id)"))
            }
            #expect(try engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: "1") == nil)
            let info = try engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: "2", flags: .withInfo)
            #expect(try #require(info).contains("AFFECTED_ENTITIES"))
            let typed = try engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: "3", as: SzWithInfoResponse.self)
            #expect(typed.recordID == "3")
            expectSzError(.notFound) {
                _ = try engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "1")
            }
            expectSzError(.unknownDataSource) {
                try engine.deleteRecord(dataSourceCode: "NOPE", recordID: "1")
            }
            expectSzError(.unknownDataSource) {
                try engine.deleteRecord(dataSourceCode: "NOPE", recordID: "1", flags: .withInfo)
            }
        }

        @Test("test_reevaluate records and entities")
        func test_reevaluate() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            #expect(try engine.reevaluateRecord(dataSourceCode: "CUSTOMERS", recordID: "1001") == nil)
            let recordInfo = try engine.reevaluateRecord(
                dataSourceCode: "CUSTOMERS", recordID: "1001", flags: .withInfo)
            #expect(try #require(recordInfo).contains(#""RECORD_ID":"1001""#))
            #expect(try engine.reevaluateEntity(entityID) == nil)
            let entityInfo = try #require(try engine.reevaluateEntity(entityID, flags: .withInfo))
            let decoded = try SzJSONTestDecoder.decode(SzWithInfoResponse.self, entityInfo)
            #expect(decoded.recordID == nil)
            #expect(decoded.affectedEntities.map(\.entityID).contains(entityID))
            // Reevaluating a record that does not exist is a no-op in the engine.
            #expect(try engine.reevaluateRecord(dataSourceCode: "CUSTOMERS", recordID: "NOPE") == nil)
            expectSzError(.unknownDataSource) {
                try engine.reevaluateRecord(dataSourceCode: "NOPE", recordID: "1")
            }
            expectSzError(.unknownDataSource) {
                try engine.reevaluateRecord(dataSourceCode: "NOPE", recordID: "1", flags: .withInfo)
            }
        }

        @Test("test_redo records are counted, fetched and processed")
        func test_redo() throws {
            let fixture = try EngineFixture()
            let engine = fixture.engine
            for record in try Truthset.allRecords() {
                try engine.addRecord(
                    dataSourceCode: record.dataSourceCode,
                    recordID: record.recordID,
                    recordDefinition: record.definition
                )
            }
            let pending = try engine.countRedoRecords()
            #expect(pending > 0)
            let first = try #require(try engine.getRedoRecord())
            let info = try engine.processRedoRecord(first, flags: .withInfo)
            #expect(try #require(info).contains("AFFECTED_ENTITIES"))
            while let redo = try engine.getRedoRecord() {
                #expect(try engine.processRedoRecord(redo) == nil)
            }
            #expect(try engine.countRedoRecords() == 0)
            #expect(try engine.getRedoRecord() == nil)
            expectSzError(.badInput) { try engine.processRedoRecord("{bad") }
            expectSzError(.badInput) { try engine.processRedoRecord("{bad", flags: .withInfo) }
        }

        @Test("test_primeEngine and getStats")
        func test_primeAndStats() throws {
            let fixture = try EngineFixture()
            try fixture.engine.primeEngine()
            try fixture.engine.addRecord(
                dataSourceCode: "CUSTOMERS", recordID: "1", recordDefinition: person("Ann Lee"))
            #expect(try fixture.engine.getStats().contains("workload"))
        }
    }
}

/// Decodes engine JSON in tests through the public typed API's decoder rules.
enum SzJSONTestDecoder {
    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
