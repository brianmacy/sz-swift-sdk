import SenzingSDK
import SenzingTestSupport
import Testing

extension EngineTests {
    @Suite("SzEngine reads, search and export")
    struct SzEngineReadTests {
        @Test("test_truth set resolves as its answer key says")
        func test_truthsetResolution() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            // The truth set's answer key puts CUSTOMERS 1001-1004 in one entity.
            let entity = try fixture.engine.getEntity(
                dataSourceCode: "CUSTOMERS",
                recordID: "1001",
                as: SzEntityResponse.self
            )
            let keys = Set(try #require(entity.resolvedEntity.records).map(\.recordKey))
            for id in ["1001", "1002", "1003", "1004"] {
                #expect(keys.contains(.of("CUSTOMERS", id)))
            }
            #expect(entity.resolvedEntity.entityName == "Robert Smith")
            let summary = try #require(entity.resolvedEntity.recordSummary)
            #expect(summary.contains { $0.dataSourceCode == "CUSTOMERS" && $0.recordCount == 4 })
            let features = try #require(entity.resolvedEntity.features)
            #expect(features["NAME"]?.isEmpty == false)
            #expect(features["NAME"]?.first?.values?.isEmpty == false)
            let related = try #require(entity.relatedEntities)
            #expect(related.contains { $0.matchLevelCode == "POSSIBLY_SAME" })
        }

        @Test("test_getEntity by ID, by record, and with flags")
        func test_getEntity() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            let byID = try engine.getEntity(entityID, as: SzEntityResponse.self)
            #expect(byID.resolvedEntity.entityID == entityID)
            let internalIDs = try #require(byID.resolvedEntity.records).compactMap(\.internalID)
            #expect(!internalIDs.isEmpty && internalIDs.allSatisfy { $0.intValue != nil }, "integer IDs")
            let raw = try engine.getEntity(entityID)
            #expect(raw.contains("RESOLVED_ENTITY"))
            let brief = try engine.getEntity(entityID, flags: [], as: SzEntityResponse.self)
            #expect(brief.resolvedEntity.records == nil)
            #expect(brief.resolvedEntity.entityName == nil)
            #expect(try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001").contains("1001"))
            let named = try engine.getEntity(
                dataSourceCode: "CUSTOMERS",
                recordID: "1001",
                flags: .entityIncludeEntityName
            )
            #expect(named.contains("Robert Smith"))

            let missing = expectSzError(.notFound) { _ = try engine.getEntity(999_999) }
            #expect(missing?.errorCode == 37)
            expectSzError(.notFound) { _ = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "NOPE") }
            expectSzError(.unknownDataSource) { _ = try engine.getEntity(dataSourceCode: "NOPE", recordID: "1") }
            expectSzError(.json) { _ = try engine.getEntity(entityID, as: SzVersionInfo.self) }
        }

        @Test("test_getRecord and getRecordPreview")
        func test_records() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let record = try fixture.engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "1001")
            #expect(record.contains("JSON_DATA"))
            let bare = try fixture.engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "1001", flags: [])
            #expect(!bare.contains("JSON_DATA"))
            let preview = try fixture.engine.getRecordPreview(person("Robert Smith"))
            #expect(preview.contains("FEATURES"))
            expectSzError(.badInput) { _ = try fixture.engine.getRecordPreview("{bad") }
        }

        @Test("test_searchByAttributes with default and named profiles")
        func test_search() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let query = person("Robert Smith", ["DATE_OF_BIRTH": "12/11/1978"])
            let results = try engine.searchByAttributes(query, as: SzSearchResponse.self)
            let best = try #require(results.resolvedEntities.first)
            #expect(best.entity.resolvedEntity.entityID == (try fixture.entityID("CUSTOMERS", "1001")))
            #expect(best.matchInfo.matchLevelCode == "RESOLVED")
            #expect(best.matchInfo.featureScores?["NAME"]?.first?.score == 100)
            #expect(best.matchInfo.candidateKeys?.isEmpty == false)

            let profiled = try engine.searchByAttributes(query, searchProfile: "SEARCH")
            #expect(profiled.contains("RESOLVED_ENTITIES"))
            let empty = try engine.searchByAttributes(query, searchProfile: "")
            #expect(empty.contains("RESOLVED_ENTITIES"))
            let minimal = try engine.searchByAttributes(query, flags: .searchByAttributesMinimalStrong)
            #expect(minimal.contains("RESOLVED_ENTITIES"))
            let none = try engine.searchByAttributes(person("Xq Zzyzx Vv"), as: SzSearchResponse.self)
            #expect(none.resolvedEntities.isEmpty)

            let bogus = expectSzError(.badInput) {
                _ = try engine.searchByAttributes(query, searchProfile: "BOGUS")
            }
            #expect(bogus?.errorCode == 88)
        }

        @Test("test_JSON export returns every entity and closes its handle")
        func test_jsonExport() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = fixture.engine
            let lines = try engine.exportJsonEntityLines()
            let entities = try engine.exportJsonEntityReport(as: SzEntityResponse.self)
            #expect(entities.count == lines.count)
            #expect(!entities.isEmpty)
            let recordCount = entities.reduce(0) { $0 + ($1.resolvedEntity.records?.count ?? 0) }
            #expect(recordCount == (try Truthset.allRecords()).count)

            let handle = try engine.exportJsonEntityReport()
            #expect(try engine.fetchNext(handle) != nil)
            try engine.closeExportReport(handle)
            expectSzError(.json) { _ = try engine.exportJsonEntityReport(as: SzVersionInfo.self) }
        }

        @Test("test_CSV export starts with a header row")
        func test_csvExport() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let handle = try fixture.engine.exportCsvEntityReport(csvColumnList: "*")
            let header = try #require(try fixture.engine.fetchNext(handle))
            #expect(header.hasPrefix("RESOLVED_ENTITY_ID"))
            var rows = 0
            while try fixture.engine.fetchNext(handle) != nil {
                rows += 1
            }
            #expect(rows > 0)
            try fixture.engine.closeExportReport(handle)
        }
    }
}
