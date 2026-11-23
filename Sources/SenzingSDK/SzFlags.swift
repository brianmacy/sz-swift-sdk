/// Bit flags that control what the engine returns, mirroring the C# `SzFlag`.
///
/// The named constants (for example ``entityDefaultFlags`` and ``withInfo``)
/// are generated from the `szflags.json` file that ships with the Senzing
/// runtime. Every engine method defaults its `flags` argument to the matching
/// `...DefaultFlags` constant; combine flags with set syntax:
///
/// ```swift
/// try engine.getEntity(entityID, flags: [.entityIncludeEntityName, .entityIncludeRecordData])
/// try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1", recordDefinition: json, flags: .withInfo)
/// ```
///
/// Use `[]` (or ``noFlags``) for no flags. ``SzFlagUsageGroup`` lists which
/// flags each method accepts.
public struct SzFlags: OptionSet, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    /// The default flags for ``SzEngine/processRedoRecord(_:flags:)``: none.
    ///
    /// Defined by the C# SDK (`SzRedoDefaultFlags`) rather than `szflags.json`.
    public static let redoDefaultFlags: SzFlags = []

    /// Bits that only this SDK interprets; they are never passed to the engine.
    static let sdkOnlyFlags: SzFlags = .withInfo

    /// The flags passed to the native engine: everything but the SDK-only bits.
    var nativeValue: Int64 { subtracting(Self.sdkOnlyFlags).rawValue }

    public var description: String {
        let digits = String(UInt64(bitPattern: rawValue), radix: 16, uppercase: true)
        return "SzFlags(0x\(digits))"
    }
}
