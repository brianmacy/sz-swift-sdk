import Foundation
import SenzingSDK
import SenzingTestSupport
import Testing

@Suite("SzFlags")
struct SzFlagsTests {
    /// The installed szflags.json: the source of truth for the constants.
    static func installedFlags() throws -> [[String: Any]] {
        let url = SenzingRuntime.current.erDirectory.appendingPathComponent("sdk/szflags.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]]
        return try #require(object)
    }

    @Test("test_constants match the installed szflags.json")
    func test_constantsMatchInstalledJSON() throws {
        let expected: [String: SzFlags] = [
            "SzNoFlags": .noFlags,
            "SzWithInfo": .withInfo,
            "SzEntityDefaultFlags": .entityDefaultFlags,
            "SzEntityIncludeEntityName": .entityIncludeEntityName,
            "SzExportDefaultFlags": .exportDefaultFlags,
            "SzSearchByAttributesDefaultFlags": .searchByAttributesDefaultFlags,
            "SzWhyEntitiesDefaultFlags": .whyEntitiesDefaultFlags,
            "SzFindPathDefaultFlags": .findPathDefaultFlags,
            "SzIncludeFeatureScores": .includeFeatureScores,
            "SzRecordDefaultFlags": .recordDefaultFlags,
        ]
        var seen = 0
        for entry in try Self.installedFlags() {
            guard let name = entry["altSymbol"] as? String, let flags = expected[name] else {
                continue
            }
            let value = try #require(entry["value"] as? NSNumber).int64Value
            #expect(flags.rawValue == value, "\(name)")
            seen += 1
        }
        #expect(seen == expected.count)
    }

    @Test("test_usage groups cover every single-bit flag that names them")
    func test_usageGroups() throws {
        for entry in try Self.installedFlags() {
            guard let bits = entry["bits"] as? [Int], bits.count == 1,
                let groups = entry["altGroups"] as? [String]
            else {
                continue
            }
            let value = try #require(entry["value"] as? NSNumber).int64Value
            for group in groups {
                let usage = try #require(SzFlagUsageGroup(rawValue: group), "unknown group \(group)")
                #expect(usage.allFlags.contains(SzFlags(rawValue: value)), "\(group)")
            }
        }
        #expect(SzFlagUsageGroup.entity.allFlags.contains(.entityIncludeEntityName))
        #expect(!SzFlagUsageGroup.entity.allFlags.contains(.withInfo))
        #expect(SzFlagUsageGroup.addRecord.allFlags == .withInfo)
    }

    @Test("test_option set behavior and description")
    func test_optionSet() {
        let flags: SzFlags = [.entityIncludeEntityName, .entityIncludeRecordData]
        #expect(flags.contains(.entityIncludeEntityName))
        #expect(!flags.contains(.withInfo))
        #expect(SzFlags.noFlags.isEmpty)
        #expect(SzFlags.redoDefaultFlags.isEmpty)
        #expect(SzFlags(rawValue: 0x1000).description == "SzFlags(0x1000)")
        #expect(SzFlags.entityDefaultFlags.isSuperset(of: .entityCoreFlags))
    }
}
