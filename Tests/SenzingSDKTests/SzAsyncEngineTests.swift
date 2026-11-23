import SenzingSDK
import SenzingTestSupport
import Testing

extension EngineTests {
    @Suite("SzAsyncEngine")
    struct SzAsyncEngineTests {
        @Test("test_concurrent async loading resolves the truth set")
        func test_concurrentLoad() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 3)
            #expect(engine.maxConcurrentCalls == 3)
            let records = try Truthset.allRecords()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for record in records {
                    group.addTask {
                        try await engine.addRecord(
                            dataSourceCode: record.dataSourceCode,
                            recordID: record.recordID,
                            recordDefinition: record.definition
                        )
                    }
                }
                try await group.waitForAll()
            }
            #expect(try await engine.processRedoRecords() >= 0)
            let entity = try await engine.getEntity(
                dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
            let keys = Set(try #require(entity.resolvedEntity.records).map(\.recordKey))
            #expect(
                keys.isSuperset(of: [.of("CUSTOMERS", "1002"), .of("CUSTOMERS", "1003"), .of("CUSTOMERS", "1004")]))
            let exported = try await engine.exportJsonEntityReport(as: SzEntityResponse.self)
            let total = exported.reduce(0) { $0 + ($1.resolvedEntity.records?.count ?? 0) }
            #expect(total == records.count)
        }

        @Test("test_every async wrapper reaches the engine")
        func test_wrappers() async throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = SzAsyncEngine(fixture.engine)
            #expect(engine.maxConcurrentCalls >= 1)
            let info = try await engine.addRecord(
                dataSourceCode: "CUSTOMERS",
                recordID: "A1",
                recordDefinition: person("Ann Lee"),
                flags: .withInfo
            )
            #expect(info?.contains("A1") == true)
            let typedInfo = try await engine.addRecord(
                dataSourceCode: "CUSTOMERS",
                recordID: "A2",
                recordDefinition: person("Ann Lee"),
                as: SzWithInfoResponse.self
            )
            #expect(typedInfo.recordID == "A2")
            try await engine.addRecord(
                dataSourceCode: "CUSTOMERS",
                recordID: "A3",
                record: Contact(fullName: "Ann Lee", email: "ann@example.com")
            )
            #expect(try await engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "A3").contains("ann@example.com"))
            #expect(try await engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: "A3") == nil)

            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            #expect(try await engine.getEntity(entityID).contains("RESOLVED_ENTITY"))
            #expect(try await engine.getEntity(entityID, as: SzEntityResponse.self).resolvedEntity.entityID == entityID)
            #expect(try await engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001").contains("1001"))

            let query = person("Robert Smith", ["DATE_OF_BIRTH": "12/11/1978"])
            #expect(try await engine.searchByAttributes(query).contains("RESOLVED_ENTITIES"))
            let results = try await engine.searchByAttributes(query, as: SzSearchResponse.self)
            #expect(results.resolvedEntities.first?.entity.resolvedEntity.entityID == entityID)

            let other = try fixture.entityID("WATCHLIST", "1006")
            let whyEntities = try await engine.whyEntities(
                entityID1: entityID, entityID2: other, as: SzWhyResponse.self)
            #expect(whyEntities.whyResults.first?.entityID2 == other)
            let whyRecords = try await engine.whyRecords(
                dataSourceCode1: "CUSTOMERS",
                recordID1: "1001",
                dataSourceCode2: "CUSTOMERS",
                recordID2: "1002",
                as: SzWhyResponse.self
            )
            #expect(whyRecords.whyResults.first?.matchInfo.matchLevelCode == "RESOLVED")

            let stats = try await engine.perform { (engine) throws(SzError) -> String in try engine.getStats() }
            #expect(stats.contains("workload"))
            do {
                _ = try await engine.getEntity(999_999)
                Issue.record("expected notFound")
            } catch {
                #expect(error.kind == .notFound)
            }
        }
    }
}
