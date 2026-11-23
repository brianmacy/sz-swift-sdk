import Foundation
import Testing

@testable import SenzingSDK

@Suite("Internal helpers")
struct InternalTests {
    @Test("test_JSON text quoting escapes control and special characters")
    func test_quote() throws {
        let raw = "a\"b\\c\u{08}\u{0C}\n\r\t\u{01}é"
        let quoted = JSONText.quote(raw)
        #expect(quoted == "\"a\\\"b\\\\c\\b\\f\\n\\r\\t\\u0001é\"")
        let decoded = try JSONSerialization.jsonObject(with: Data(quoted.utf8), options: .fragmentsAllowed)
        #expect(decoded as? String == raw)
    }

    @Test("test_JSON documents for the native parameters")
    func test_documents() {
        #expect(JSONText.entityIDs([3, 1]) == #"{"ENTITIES":[{"ENTITY_ID":1},{"ENTITY_ID":3}]}"#)
        #expect(JSONText.entityIDs([]) == #"{"ENTITIES":[]}"#)
        #expect(
            JSONText.recordKeys([.of("B", "2"), .of("A", "1")])
                == #"{"RECORDS":[{"DATA_SOURCE":"A","RECORD_ID":"1"},{"DATA_SOURCE":"B","RECORD_ID":"2"}]}"#
        )
        #expect(JSONText.dataSources(["W", "C"]) == #"{"DATA_SOURCES":["C","W"]}"#)
        #expect(JSONText.dataSourceCode("X\"Y") == #"{"DSRC_CODE":"X\"Y"}"#)
    }

    @Test("test_config comments follow the C# rules")
    func test_configComment() {
        func definition(_ codes: [String]) -> String {
            let items = codes.map { #"{"DSRC_ID":1,"DSRC_CODE":"\#($0)"}"# }.joined(separator: ",")
            return #"{"G2_CONFIG":{"CFG_DSRC":[\#(items)]}}"#
        }
        #expect(
            ConfigComment.make(from: definition(["TEST", "SEARCH", "CUSTOMERS", "WATCHLIST"]))
                == "Data Sources: CUSTOMERS, WATCHLIST")
        #expect(ConfigComment.make(from: definition([])) == "Data Sources: [ NONE ]")
        #expect(ConfigComment.make(from: definition(["SEARCH", "TEST"])) == "Data Sources: [ ONLY DEFAULT ]")
        #expect(ConfigComment.make(from: definition(["TEST"])) == "Data Sources: [ SOME DEFAULT (TEST) ]")
        #expect(ConfigComment.make(from: "not json").isEmpty)
    }

    @Test("test_SDK-only flags are never passed to the engine")
    func test_nativeValue() {
        let flags: SzFlags = [.withInfo, .entityIncludeEntityName]
        #expect(flags.nativeValue == SzFlags.entityIncludeEntityName.rawValue)
    }

    @Test("test_JSON conversion errors are json kind")
    func test_jsonErrors() {
        do {
            _ = try SzJSON.decode(SzEntityResponse.self, from: "{}")
            Issue.record("expected a decoding error")
        } catch {
            #expect(error.kind == .json)
        }
        do {
            _ = try SzJSON.encode(Double.nan)
            Issue.record("expected an encoding error")
        } catch {
            #expect(error.kind == .json)
        }
    }

    @Test("test_native result validation")
    func test_nativeResults() throws {
        #expect(try Native.count(5, .engine) == 5)
        for component in [NativeComponent.engine, .config, .configManager, .diagnostic, .product] {
            // With no pending native error, the last error is empty and general.
            let error = Native.lastError(component)
            #expect(error.kind == .general)
            #expect(error.message.isEmpty)
            do {
                _ = try Native.count(-2, component)
                Issue.record("expected a negative count to throw")
            } catch {
                #expect(error.kind == .general)
            }
            do {
                _ = try Native.borrowedString(nil, component)
                Issue.record("expected NULL to throw")
            } catch {
                #expect(error.kind == .general)
            }
        }
        let text = "hello"
        #expect(try text.withCString { try Native.borrowedString($0, .product) } == "hello")
        let missing = try SzJSON.decode(SzWithInfoResponse.self, from: nil as String?)
        #expect(missing.affectedEntities.isEmpty)
    }

    @Test("test_models tolerate absent optional sections")
    func test_modelDefaults() throws {
        #expect(try SzJSON.decode(SzSearchResponse.self, from: "{}").resolvedEntities.isEmpty)
        let why = try SzJSON.decode(SzWhyResponse.self, from: "{}")
        #expect(why.whyResults.isEmpty && why.entities.isEmpty)
        let info = try SzJSON.decode(SzWithInfoResponse.self, from: "{}")
        #expect(info.dataSourceCode == nil && info.affectedEntities.isEmpty)
        #expect(SzRecordKey.of("CUSTOMERS", "1001").description == "CUSTOMERS:1001")
        let key = try SzJSON.decode(SzRecordKey.self, from: #"{"DATA_SOURCE":"A","RECORD_ID":"1"}"#)
        #expect(key == SzRecordKey(dataSourceCode: "A", recordID: "1"))
        #expect(try SzJSON.encode(key) == #"{"DATA_SOURCE":"A","RECORD_ID":"1"}"#)
    }

    @Test("test_reading a native message buffer")
    func test_bufferString() {
        #expect(Native.string(from: [72, 105, 0, 88]) == "Hi")
        #expect(Native.string(from: []) == "")
        #expect(Native.string(from: [79, 75]) == "OK")
    }
}
