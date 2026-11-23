import Foundation

/// Generates the comment the C# SDK registers with a configuration when the
/// caller gives none: `Data Sources: A, B`, or a bracketed note when only the
/// template's default data sources are present.
enum ConfigComment {
    /// The data sources in the default configuration template.
    static let defaultDataSources: Set<String> = ["TEST", "SEARCH"]

    static func make(from configDefinition: String) -> String {
        guard
            let root = try? JSONSerialization.jsonObject(with: Data(configDefinition.utf8)) as? [String: Any],
            let config = root["G2_CONFIG"] as? [String: Any],
            let dataSources = config["CFG_DSRC"] as? [[String: Any]]
        else {
            return ""
        }
        let codes = dataSources.compactMap { $0["DSRC_CODE"] as? String }
        let custom = codes.filter { !defaultDataSources.contains($0) }
        let defaults = codes.filter { defaultDataSources.contains($0) }.sorted()
        let prefix = "Data Sources: "
        if !custom.isEmpty {
            return prefix + custom.joined(separator: ", ")
        }
        if defaults.isEmpty {
            return prefix + "[ NONE ]"
        }
        if Set(defaults) == defaultDataSources {
            return prefix + "[ ONLY DEFAULT ]"
        }
        return prefix + "[ SOME DEFAULT (" + defaults.joined(separator: ", ") + ") ]"
    }
}
