import SenzingSDK
import SenzingTestSupport
import Testing

extension EngineTests {
    @Suite("SzEnvironment")
    struct SzEnvironmentTests {
        @Test("test_builder sets every property and normalizes blanks")
        func test_builder() throws {
            let repository = try TestRepository()
            defer { repository.remove() }
            let environment = try SzCoreEnvironment.newBuilder()
                .instanceName("  builder-test  ")
                .settings(repository.settings)
                .verboseLogging(false)
                .configID(repository.defaultConfigID)
                .build()
            defer { environment.destroy() }
            #expect(environment.instanceName == "builder-test")
            #expect(environment.settings == repository.settings)
            #expect(!environment.verboseLogging)
            #expect(environment.configID == repository.defaultConfigID)
            #expect(try environment.getActiveConfigID() == repository.defaultConfigID)
            environment.destroy()

            let defaults = try SzCoreEnvironment(instanceName: " ", settings: "")
            #expect(defaults.instanceName == SzCoreEnvironment.defaultInstanceName)
            #expect(defaults.settings == SzCoreEnvironment.defaultSettings)
            #expect(defaults.configID == nil)
            defaults.destroy()
        }

        @Test("test_only one environment may be active")
        func test_singleActiveEnvironment() throws {
            let repository = try TestRepository()
            defer { repository.remove() }
            let first = try repository.makeEnvironment()
            #expect(SzCoreEnvironment.getActiveInstance() === first)
            expectSzError(.general) {
                _ = try repository.makeEnvironment()
            }
            first.destroy()
            #expect(SzCoreEnvironment.getActiveInstance() == nil)
            let second = try repository.makeEnvironment()
            #expect(SzCoreEnvironment.getActiveInstance() === second)
            second.destroy()
        }

        @Test("test_releasing an environment destroys it")
        func test_deinitDestroys() throws {
            let repository = try TestRepository()
            defer { repository.remove() }
            var environment: SzCoreEnvironment? = try repository.makeEnvironment()
            let engine = try #require(environment).getEngine()
            environment = nil
            #expect(SzCoreEnvironment.getActiveInstance() == nil)
            expectSzError(.environmentDestroyed) {
                _ = try engine.getStats()
            }
        }

        @Test("test_subsystems are cached and fail after destroy")
        func test_lifecycle() throws {
            let fixture = try EngineFixture()
            let environment = fixture.environment
            #expect(try environment.getEngine() as AnyObject === environment.getEngine() as AnyObject)
            let product = try environment.getProduct()
            #expect(try environment.getProduct() as AnyObject === product as AnyObject)
            let configManager = try environment.getConfigManager()
            #expect(try environment.getConfigManager() as AnyObject === configManager as AnyObject)
            let diagnostic = try environment.getDiagnostic()
            #expect(try environment.getDiagnostic() as AnyObject === diagnostic as AnyObject)
            let config = try configManager.createConfig()
            #expect(!environment.isDestroyed)

            environment.destroy()
            environment.destroy()
            #expect(environment.isDestroyed)
            expectSzError(.environmentDestroyed) { _ = try environment.getEngine() }
            expectSzError(.environmentDestroyed) { _ = try environment.getProduct() }
            expectSzError(.environmentDestroyed) { _ = try environment.getConfigManager() }
            expectSzError(.environmentDestroyed) { _ = try environment.getDiagnostic() }
            expectSzError(.environmentDestroyed) { _ = try environment.getActiveConfigID() }
            expectSzError(.environmentDestroyed) { try environment.reinitialize(configID: 1) }
            expectSzError(.environmentDestroyed) { _ = try fixture.engine.getStats() }
            expectSzError(.environmentDestroyed) { _ = try product.getVersion() }
            expectSzError(.environmentDestroyed) { _ = try configManager.getDefaultConfigID() }
            expectSzError(.environmentDestroyed) { _ = try diagnostic.getRepositoryInfo() }
            expectSzError(.environmentDestroyed) { _ = try config.export() }
            let destroyed = expectSzError(.environmentDestroyed) { try fixture.engine.primeEngine() }
            #expect(destroyed?.isKind(of: .general) == false)
        }

        @Test("test_reinitialize switches the active configuration")
        func test_reinitialize() throws {
            let fixture = try EngineFixture()
            let environment = fixture.environment
            let configManager = try environment.getConfigManager()
            #expect(try environment.getActiveConfigID() == fixture.repository.defaultConfigID)

            let config = try configManager.createConfig(configID: fixture.repository.defaultConfigID)
            try config.registerDataSource("CONTACTS")
            let newConfigID = try configManager.registerConfig(configDefinition: config.export())
            _ = try environment.getDiagnostic()
            try environment.reinitialize(configID: newConfigID)
            #expect(try environment.getActiveConfigID() == newConfigID)
            #expect(environment.configID == newConfigID)
            try fixture.engine.addRecord(dataSourceCode: "CONTACTS", recordID: "1", recordDefinition: person("Ann Lee"))

            // A failed reinitialize keeps the previous configuration.
            expectSzError(.configuration) { try environment.reinitialize(configID: 4242) }
            #expect(environment.configID == newConfigID)
        }

        @Test("test_reinitialize before the engine exists only records the ID")
        func test_reinitializeBeforeEngine() throws {
            let repository = try TestRepository()
            defer { repository.remove() }
            let environment = try repository.makeEnvironment()
            defer { environment.destroy() }
            try environment.reinitialize(configID: repository.defaultConfigID)
            #expect(environment.configID == repository.defaultConfigID)
            _ = try environment.getDiagnostic()
            #expect(try environment.getActiveConfigID() == repository.defaultConfigID)
        }

        @Test("test_invalid settings fail with the engine's error")
        func test_invalidSettings() throws {
            let environment = try SzCoreEnvironment(settings: #"{"PIPELINE":{}}"#)
            defer { environment.destroy() }
            let error = expectSzError(.general) { _ = try environment.getEngine() }
            #expect(error?.errorCode != nil)
            expectSzError(.general) { _ = try environment.getConfigManager() }
            expectSzError(.general) { _ = try environment.getDiagnostic() }
        }
    }
}
