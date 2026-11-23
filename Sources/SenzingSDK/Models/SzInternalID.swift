/// The engine's internal ID for a record's observation (`INTERNAL_ID`).
///
/// The engine reports it as a JSON integer or as an opaque string; both
/// decode, and encoding writes the value back in the form it was read.
public struct SzInternalID: Codable, Hashable, Sendable, CustomStringConvertible {
    /// The ID as text: the integer's decimal digits, or the string as given.
    public let rawValue: String
    /// The ID as an integer, when the engine reported an integer.
    public let intValue: Int64?

    /// An integer ID.
    public init(_ value: Int64) {
        rawValue = String(value)
        intValue = value
    }

    /// A string ID.
    public init(_ value: String) {
        rawValue = value
        intValue = nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int64.self) {
            self.init(value)
        } else {
            self.init(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue {
            try container.encode(intValue)
        } else {
            try container.encode(rawValue)
        }
    }

    public var description: String {
        rawValue
    }
}
