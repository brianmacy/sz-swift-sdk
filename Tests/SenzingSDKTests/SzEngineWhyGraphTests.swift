import SenzingSDK
import SenzingTestSupport
import Testing

extension EngineTests {
    @Suite("SzEngine why, how and graph")
    struct SzEngineWhyGraphTests {
        @Test("test_whyRecords explains a resolution")
        func test_whyRecords() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let why = try fixture.engine.whyRecords(
                dataSourceCode1: "CUSTOMERS",
                recordID1: "1001",
                dataSourceCode2: "CUSTOMERS",
                recordID2: "1002",
                as: SzWhyResponse.self
            )
            let result = try #require(why.whyResults.first)
            #expect(result.matchInfo.matchLevelCode == "RESOLVED")
            #expect(result.matchInfo.whyKey?.contains("NAME") == true)
            #expect(result.focusRecords?.contains(.of("CUSTOMERS", "1001")) == true)
            #expect(result.focusRecords2?.contains(.of("CUSTOMERS", "1002")) == true)
            #expect(result.matchInfo.featureScores?["DOB"]?.first?.scoreBucket != nil)
            #expect(!why.entities.isEmpty)
            let raw = try fixture.engine.whyRecords(
                dataSourceCode1: "CUSTOMERS",
                recordID1: "1001",
                dataSourceCode2: "CUSTOMERS",
                recordID2: "1002"
            )
            #expect(raw.contains("WHY_RESULTS"))
            expectSzError(.notFound) {
                _ = try fixture.engine.whyRecords(
                    dataSourceCode1: "CUSTOMERS",
                    recordID1: "1001",
                    dataSourceCode2: "CUSTOMERS",
                    recordID2: "NOPE"
                )
            }
        }

        @Test("test_whyEntities and whyRecordInEntity")
        func test_whyEntities() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
            let related = try #require(entity.relatedEntities?.first)
            let why = try engine.whyEntities(
                entityID1: entity.resolvedEntity.entityID,
                entityID2: related.entityID,
                as: SzWhyResponse.self
            )
            let result = try #require(why.whyResults.first)
            #expect(result.entityID == entity.resolvedEntity.entityID)
            #expect(result.entityID2 == related.entityID)
            #expect(result.matchInfo.matchLevelCode == related.matchLevelCode)
            #expect(
                try engine.whyEntities(entityID1: result.entityID, entityID2: related.entityID).contains("WHY_RESULTS"))

            let inEntity = try engine.whyRecordInEntity(
                dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzWhyResponse.self)
            #expect(inEntity.whyResults.first?.entityID == entity.resolvedEntity.entityID)
            #expect(try engine.whyRecordInEntity(dataSourceCode: "CUSTOMERS", recordID: "1001").contains("WHY_RESULTS"))
            expectSzError(.notFound) { _ = try engine.whyEntities(entityID1: 999_998, entityID2: 999_999) }
        }

        @Test("test_whySearch and howEntity")
        func test_whySearchAndHow() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            let query = person("Robert Smith", ["DATE_OF_BIRTH": "12/11/1978"])
            #expect(try engine.whySearch(query, entityID: entityID).contains("WHY_RESULTS"))
            #expect(try engine.whySearch(query, entityID: entityID, searchProfile: "SEARCH").contains("WHY_RESULTS"))
            #expect(try engine.whySearch(query, entityID: entityID, searchProfile: "").contains("WHY_RESULTS"))
            #expect(try engine.howEntity(entityID).contains("RESOLUTION_STEPS"))
            expectSzError(.notFound) { _ = try engine.howEntity(999_999) }
        }

        @Test("test_getVirtualEntity combines records without writing")
        func test_virtualEntity() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let virtual = try fixture.engine.getVirtualEntity([.of("CUSTOMERS", "1001"), .of("CUSTOMERS", "1002")])
            let entity = try SzJSONTestDecoder.decode(SzEntityResponse.self, virtual)
            #expect(entity.resolvedEntity.records?.count == 2)
            expectSzError(.notFound) { _ = try fixture.engine.getVirtualEntity([.of("CUSTOMERS", "NOPE")]) }
        }

        @Test("test_findPath by entity and by record, with avoids and required sources")
        func test_findPath() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let start = try fixture.entityID("CUSTOMERS", "1001")
            let end = try fixture.entityID("WATCHLIST", "1006")
            #expect(try engine.findPath(startEntityID: start, endEntityID: end, maxDegrees: 3).contains("ENTITY_PATHS"))
            let avoided = try engine.findPath(
                startEntityID: start, endEntityID: end, maxDegrees: 3, avoidEntityIDs: [999_999])
            #expect(avoided.contains("ENTITY_PATHS"))
            let required = try engine.findPath(
                startEntityID: start,
                endEntityID: end,
                maxDegrees: 3,
                requiredDataSources: ["WATCHLIST"]
            )
            #expect(required.contains("ENTITY_PATHS"))
            let byRecord = try engine.findPath(
                startDataSourceCode: "CUSTOMERS",
                startRecordID: "1001",
                endDataSourceCode: "WATCHLIST",
                endRecordID: "1006",
                maxDegrees: 3
            )
            #expect(byRecord.contains(#""START_ENTITY_ID":\#(start)"#))
            let byRecordAvoid = try engine.findPath(
                startDataSourceCode: "CUSTOMERS",
                startRecordID: "1001",
                endDataSourceCode: "WATCHLIST",
                endRecordID: "1006",
                maxDegrees: 3,
                avoidRecordKeys: [.of("CUSTOMERS", "1005")]
            )
            #expect(byRecordAvoid.contains("ENTITY_PATHS"))
            let byRecordRequired = try engine.findPath(
                startDataSourceCode: "CUSTOMERS",
                startRecordID: "1001",
                endDataSourceCode: "WATCHLIST",
                endRecordID: "1006",
                maxDegrees: 3,
                requiredDataSources: ["WATCHLIST"]
            )
            #expect(byRecordRequired.contains("ENTITY_PATHS"))
            expectSzError(.notFound) {
                _ = try engine.findPath(startEntityID: start, endEntityID: 999_999, maxDegrees: 2)
            }
        }

        @Test("test_findNetwork and findInterestingEntities")
        func test_findNetwork() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let first = try fixture.entityID("CUSTOMERS", "1001")
            let second = try fixture.entityID("WATCHLIST", "1006")
            let byEntity = try engine.findNetwork(
                entityIDs: [first, second],
                maxDegrees: 2,
                buildOutDegrees: 1,
                buildOutMaxEntities: 10
            )
            #expect(byEntity.contains("ENTITY_NETWORK_LINKS"))
            let byRecord = try engine.findNetwork(
                recordKeys: [.of("CUSTOMERS", "1001")],
                maxDegrees: 1,
                buildOutDegrees: 1,
                buildOutMaxEntities: 10
            )
            #expect(byRecord.contains("ENTITY_NETWORK_LINKS"))
            #expect(try engine.findInterestingEntities(first).contains("INTERESTING_ENTITIES"))
            let byRecordInteresting = try engine.findInterestingEntities(dataSourceCode: "CUSTOMERS", recordID: "1001")
            #expect(byRecordInteresting.contains("INTERESTING_ENTITIES"))
            expectSzError(.notFound) {
                _ = try engine.findNetwork(
                    entityIDs: [999_999], maxDegrees: 1, buildOutDegrees: 1, buildOutMaxEntities: 1)
            }
            expectSzError(.notFound) { _ = try engine.findInterestingEntities(999_999) }
        }
    }
}
