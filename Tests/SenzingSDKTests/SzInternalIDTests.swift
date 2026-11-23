import Foundation
import SenzingSDK
import Testing

@Suite("SzInternalID")
struct SzInternalIDTests {
    @Test("test_decode accepts integer and string INTERNAL_ID values and round-trips them")
    func test_decode() throws {
        let line = """
            {"RESOLVED_ENTITY":{"ENTITY_ID":7,"RECORDS":[\
            {"DATA_SOURCE":"CUSTOMERS","RECORD_ID":"1","INTERNAL_ID":1001},\
            {"DATA_SOURCE":"CUSTOMERS","RECORD_ID":"2","INTERNAL_ID":"1002:4B73984B1A8BBCDA"}]}}
            """
        let entity = try JSONDecoder().decode(SzEntityResponse.self, from: Data(line.utf8))
        let ids = try #require(entity.resolvedEntity.records).map(\.internalID)
        #expect(ids == [SzInternalID(1001), SzInternalID("1002:4B73984B1A8BBCDA")])
        #expect(ids[0]?.intValue == 1001 && ids[0]?.rawValue == "1001" && ids[0]?.description == "1001")
        #expect(ids[1]?.intValue == nil && ids[1]?.description == "1002:4B73984B1A8BBCDA")

        let encoded = String(decoding: try JSONEncoder().encode(ids), as: UTF8.self)
        #expect(encoded == #"[1001,"1002:4B73984B1A8BBCDA"]"#)

        let why = """
            {"WHY_RESULTS":[{"INTERNAL_ID":"5:AA","ENTITY_ID":1,"INTERNAL_ID_2":6,"ENTITY_ID_2":2,"MATCH_INFO":{}}]}
            """
        let result = try #require(try JSONDecoder().decode(SzWhyResponse.self, from: Data(why.utf8)).whyResults.first)
        #expect(result.internalID == SzInternalID("5:AA") && result.internalID2 == SzInternalID(6))
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SzInternalID.self, from: Data("[true]".utf8).dropFirst().dropLast())
        }
    }
}
