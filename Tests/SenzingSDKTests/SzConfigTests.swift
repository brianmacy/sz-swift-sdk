import SenzingSDK
import SenzingTestSupport
import Testing

extension EngineTests {
    @Suite("SzConfig and SzConfigManager")
    struct SzConfigTests {
        @Test("test_register, persist and verify a data source")
        func test_registerDataSource() throws {
            let fixture = try EngineFixture(dataSources: [])
            let configManager = try fixture.environment.getConfigManager()

            // Step 1: register.
            let config = try configManager.createConfig()
            let registered = try config.registerDataSource("CONTACTS")
            #expect(registered.contains("DSRC_ID"))
            // Step 2: persist.
            let configID = try configManager.setDefaultConfig(configDefinition: config.export())
            #expect(try configManager.getDefaultConfigID() == configID)
            // Step 3: verify persistence.
            let reloaded = try configManager.createConfig(configID: configID)
            let registry = try reloaded.getDataSourceRegistry(as: SzDataSourceRegistry.self)
            #expect(registry.dataSourceCodes.contains("CONTACTS"))
            // Step 4: verify the engine can use it.
            try fixture.environment.reinitialize(configID: configID)
            try fixture.engine.addRecord(dataSourceCode: "CONTACTS", recordID: "1", recordDefinition: person("Ann Lee"))
            #expect(try fixture.engine.getRecord(dataSourceCode: "CONTACTS", recordID: "1").contains("CONTACTS"))
        }

        @Test("test_unregister a data source")
        func test_unregisterDataSource() throws {
            let fixture = try EngineFixture()
            let configManager = try fixture.environment.getConfigManager()
            let config = try configManager.createConfig(configID: fixture.repository.defaultConfigID)
            #expect(try config.getDataSourceRegistry().contains("WATCHLIST"))
            try config.unregisterDataSource("WATCHLIST")
            #expect(!(try config.getDataSourceRegistry().contains("WATCHLIST")))
            // Unregistering an unknown data source is accepted by the engine.
            try config.unregisterDataSource("NOPE")
            // The definition round-trips through createConfig(configDefinition:).
            let copy = try configManager.createConfig(configDefinition: config.export())
            #expect(try copy.getDataSourceRegistry() == config.getDataSourceRegistry())
        }

        @Test("test_template configuration has the default data sources")
        func test_template() throws {
            let fixture = try EngineFixture()
            let config = try fixture.environment.getConfigManager().createConfig()
            let registry = try config.getDataSourceRegistry(as: SzDataSourceRegistry.self)
            #expect(Set(registry.dataSourceCodes) == ["TEST", "SEARCH"])
            #expect(registry.dataSources.allSatisfy { $0.dataSourceID > 0 })
        }

        @Test("test_configuration registry, comments and default ID")
        func test_registry() throws {
            let fixture = try EngineFixture()
            let configManager = try fixture.environment.getConfigManager()
            let config = try configManager.createConfig()
            try config.registerDataSource("ALPHA")
            let commented = try configManager.registerConfig(configDefinition: config.export(), configComment: "mine")
            // The engine returns the existing ID for an identical definition.
            #expect(try configManager.registerConfig(configDefinition: config.export()) == commented)
            try config.registerDataSource("BETA")
            let generated = try configManager.registerConfig(configDefinition: config.export())
            let registry = try configManager.getConfigRegistry(as: SzConfigRegistry.self)
            let comments = Dictionary(uniqueKeysWithValues: registry.configs.map { ($0.configID, $0.configComments) })
            #expect(comments[commented] == "mine")
            #expect(comments[generated] == "Data Sources: ALPHA, BETA")
            #expect(registry.configs.allSatisfy { $0.createdDate != nil })
            #expect(try configManager.getConfigRegistry().contains("CONFIGS"))

            try configManager.setDefaultConfigID(commented)
            #expect(try configManager.getDefaultConfigID() == commented)
            try configManager.replaceDefaultConfigID(currentDefaultConfigID: commented, newDefaultConfigID: generated)
            #expect(try configManager.getDefaultConfigID() == generated)
            try config.registerDataSource("GAMMA")
            let explicit = try configManager.setDefaultConfig(
                configDefinition: config.export(), configComment: "explicit")
            #expect(try configManager.getDefaultConfigID() == explicit)
        }

        @Test("test_configuration errors map to their kinds")
        func test_errors() throws {
            let fixture = try EngineFixture()
            let configManager = try fixture.environment.getConfigManager()
            let conflict = expectSzError(.replaceConflict) {
                try configManager.replaceDefaultConfigID(currentDefaultConfigID: 12_345, newDefaultConfigID: 1)
            }
            #expect(conflict?.errorCode == 7245)
            expectSzError(.configuration) { _ = try configManager.createConfig(configID: 4242) }
            expectSzError(.configuration) { _ = try configManager.createConfig(configDefinition: "{}") }
            expectSzError(.general) { try configManager.setDefaultConfigID(4242) }
        }

        @Test("test_a new repository has no default configuration")
        func test_noDefault() throws {
            let repository = try TestRepository(dataSources: [])
            defer { repository.remove() }
            let environment = try repository.makeEnvironment()
            defer { environment.destroy() }
            let configManager = try environment.getConfigManager()
            #expect(try configManager.getDefaultConfigID() == repository.defaultConfigID)
        }
    }

    @Suite("SzProduct and SzDiagnostic")
    struct SzProductDiagnosticTests {
        @Test("test_version and license decode")
        func test_product() throws {
            let fixture = try EngineFixture()
            let product = try fixture.environment.getProduct()
            let version = try product.getVersion(as: SzVersionInfo.self)
            #expect(version.version.hasPrefix("4."))
            #expect(version.productName.isEmpty == false)
            #expect(version.compatibilityVersion?.configVersion.isEmpty == false)
            #expect(version.schemaVersion?.engineSchemaVersion.isEmpty == false)
            #expect(try product.getVersion().contains(version.buildVersion))
            let license = try product.getLicense(as: SzLicenseInfo.self)
            #expect((license.recordLimit ?? 0) > 0)
            #expect(try product.getLicense().contains("licenseType"))
        }

        @Test("test_repository info, performance, feature and purge")
        func test_diagnostic() throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let diagnostic = try fixture.environment.getDiagnostic()
            #expect(try diagnostic.getRepositoryInfo().contains("sqlite3"))
            #expect(try diagnostic.checkRepositoryPerformance(secondsToRun: 1).contains("numRecordsInserted"))
            #expect(try diagnostic.getFeature(featureID: 1).contains("LIB_FEAT_ID"))
            expectSzError(.general) { _ = try diagnostic.getFeature(featureID: -5) }
            try diagnostic.purgeRepository()
            expectSzError(.notFound) {
                _ = try fixture.engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001")
            }
        }

        @Test("test_diagnostic initializes with a pinned configuration")
        func test_diagnosticWithConfigID() throws {
            let repository = try TestRepository()
            defer { repository.remove() }
            let environment = try SzCoreEnvironment(settings: repository.settings, configID: repository.defaultConfigID)
            defer { environment.destroy() }
            #expect(try environment.getDiagnostic().getRepositoryInfo().contains("dataStores"))
        }
    }
}
