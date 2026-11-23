/// Builds the small JSON documents the native API takes as parameters.
enum JSONText {
    /// Quotes and escapes `value` as a JSON string literal.
    static func quote(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let control where control.value < 0x20:
                let digits = String(control.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - digits.count) + digits
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }

    /// `{"ENTITIES":[{"ENTITY_ID":1},...]}`
    static func entityIDs(_ entityIDs: Set<Int64>) -> String {
        let items = entityIDs.sorted().map { "{\"ENTITY_ID\":\($0)}" }
        return "{\"ENTITIES\":[" + items.joined(separator: ",") + "]}"
    }

    /// `{"RECORDS":[{"DATA_SOURCE":"...","RECORD_ID":"..."},...]}`
    static func recordKeys(_ recordKeys: Set<SzRecordKey>) -> String {
        let items = recordKeys.sorted().map {
            "{\"DATA_SOURCE\":\(quote($0.dataSourceCode)),\"RECORD_ID\":\(quote($0.recordID))}"
        }
        return "{\"RECORDS\":[" + items.joined(separator: ",") + "]}"
    }

    /// `{"DATA_SOURCES":["...",...]}`
    static func dataSources(_ dataSources: Set<String>) -> String {
        let items = dataSources.sorted().map(quote)
        return "{\"DATA_SOURCES\":[" + items.joined(separator: ",") + "]}"
    }

    /// `{"DSRC_CODE":"..."}`
    static func dataSourceCode(_ dataSourceCode: String) -> String {
        "{\"DSRC_CODE\":\(quote(dataSourceCode))}"
    }
}
