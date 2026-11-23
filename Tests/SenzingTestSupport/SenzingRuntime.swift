import Foundation

/// Locates the files of the installed Senzing runtime that a repository's
/// settings refer to, using the same search order as `Package.swift`.
public struct SenzingRuntime: Sendable {
    /// The runtime's `er` directory.
    public let erDirectory: URL
    /// `PIPELINE.RESOURCEPATH`.
    public let resourcePath: URL
    /// `PIPELINE.SUPPORTPATH`.
    public let supportPath: URL
    /// `PIPELINE.CONFIGPATH`.
    public let configPath: URL
    /// The SQLite schema script that creates a repository.
    public let sqliteSchema: URL

    /// The installed runtime.
    public static let current = SenzingRuntime(erDirectory: locateErDirectory())

    public init(erDirectory: URL) {
        let fileManager = FileManager.default
        self.erDirectory = erDirectory
        resourcePath = erDirectory.appendingPathComponent("resources")
        supportPath = erDirectory.deletingLastPathComponent().appendingPathComponent("data")
        let configCandidates = [
            URL(fileURLWithPath: "/etc/opt/senzing"),
            erDirectory.appendingPathComponent("etc"),
            erDirectory.appendingPathComponent("resources/templates"),
        ]
        let isLinuxLayout = erDirectory.path == "/opt/senzing/er"
        configPath =
            configCandidates.first { candidate in
                if candidate.path == "/etc/opt/senzing" && !isLinuxLayout {
                    return false
                }
                return fileManager.fileExists(atPath: candidate.path)
            } ?? erDirectory.appendingPathComponent("etc")
        sqliteSchema = resourcePath.appendingPathComponent("schema/szcore-schema-sqlite-create.sql")
    }

    /// The engine settings JSON for a SQLite repository at `databasePath`.
    public func settings(databasePath: String) -> String {
        let settings: [String: [String: String]] = [
            "PIPELINE": [
                "CONFIGPATH": configPath.path,
                "RESOURCEPATH": resourcePath.path,
                "SUPPORTPATH": supportPath.path,
            ],
            "SQL": ["CONNECTION": "sqlite3://na:na@\(databasePath)"],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private static func locateErDirectory() -> URL {
        if let explicit = ProcessInfo.processInfo.environment["SENZING_DIR"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }
        let candidates = [
            "/opt/homebrew/opt/senzing/er",
            "/usr/local/opt/senzing/er",
            "/opt/homebrew/opt/senzing/runtime/er",
            "/usr/local/opt/senzing/runtime/er",
            "/opt/senzing/er",
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: "\($0)/sdk/c/libSz.h") }
        return URL(fileURLWithPath: found ?? "/opt/senzing/er")
    }
}
