import Foundation
import SenzingSDK

/// An error provisioning a test repository.
public struct TestRepositoryError: Error, CustomStringConvertible {
    public let description: String
}

/// A fresh, isolated SQLite repository in its own temporary directory.
///
/// No mocks: the repository is created from the schema script shipped with the
/// installed runtime (with the `sqlite3` command-line tool), and its default
/// configuration is registered through this SDK. ``remove()`` deletes it.
public final class TestRepository: @unchecked Sendable {
    /// The temporary directory that holds the repository.
    public let directory: URL
    /// The SQLite database file.
    public let databasePath: String
    /// The engine settings JSON for this repository.
    public let settings: String
    /// The data sources registered in the default configuration.
    public let dataSources: [String]
    /// The default configuration ID registered when the repository was created.
    public let defaultConfigID: Int64

    /// Creates the repository and registers a default configuration with
    /// `dataSources`.
    public init(dataSources: [String] = Truthset.dataSources) throws {
        let runtime = SenzingRuntime.current
        guard FileManager.default.fileExists(atPath: runtime.sqliteSchema.path) else {
            throw TestRepositoryError(
                description: "Missing \(runtime.sqliteSchema.path): install the Senzing runtime "
                    + "(on Linux, the senzingsdk-runtime and senzingsdk-setup packages)."
            )
        }
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sz-swift-sdk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        databasePath = directory.appendingPathComponent("G2C.db").path
        settings = runtime.settings(databasePath: databasePath)
        self.dataSources = dataSources
        try Self.applySchema(runtime.sqliteSchema, to: databasePath)
        defaultConfigID = try Self.registerDefaultConfig(settings: settings, dataSources: dataSources)
    }

    /// Creates an environment over this repository.
    public func makeEnvironment(instanceName: String = "sz-swift-sdk-test") throws(SzError) -> SzCoreEnvironment {
        try SzCoreEnvironment(instanceName: instanceName, settings: settings)
    }

    /// Deletes the repository's directory.
    public func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func applySchema(_ schema: URL, to databasePath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sqlite3", databasePath]
        process.standardInput = try FileHandle(forReadingFrom: schema)
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw TestRepositoryError(
                description: "sqlite3 failed (\(process.terminationStatus)) creating \(databasePath): \(message)"
            )
        }
    }

    private static func registerDefaultConfig(settings: String, dataSources: [String]) throws -> Int64 {
        let environment = try SzCoreEnvironment(instanceName: "sz-swift-sdk-bootstrap", settings: settings)
        defer { environment.destroy() }
        let configManager = try environment.getConfigManager()
        let config = try configManager.createConfig()
        for dataSource in dataSources {
            try config.registerDataSource(dataSource)
        }
        return try configManager.setDefaultConfig(configDefinition: config.export())
    }
}
