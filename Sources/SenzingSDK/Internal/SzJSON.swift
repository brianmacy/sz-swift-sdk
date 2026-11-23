import Foundation

/// JSON conversion for the typed (`Codable`) APIs.
enum SzJSON {
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws(SzError) -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(json.utf8))
        } catch {
            throw SzError(.json, message: "Could not decode \(T.self) from the engine response: \(error)")
        }
    }

    /// Decodes an optional response; `nil` (no info returned) decodes as `{}`.
    static func decode<T: Decodable>(_ type: T.Type, from json: String?) throws(SzError) -> T {
        try decode(type, from: json ?? "{}")
    }

    static func encode<T: Encodable>(_ value: T) throws(SzError) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            throw SzError(.json, message: "Could not encode \(T.self) as JSON: \(error)")
        }
    }
}
