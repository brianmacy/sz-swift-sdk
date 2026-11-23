import CSenzing

/// The ``SzConfigManager`` over the native engine, mirroring the C#
/// `SzCoreConfigManager`.
public final class SzCoreConfigManager: SzConfigManager {
    let state: EnvironmentState

    init(state: EnvironmentState) {
        self.state = state
    }

    public func createConfig() throws(SzError) -> any SzConfig {
        let definition = try state.execute { () throws(SzError) -> String in
            try NativeConfig.template()
        }
        return SzCoreConfig(state: state, definition: definition)
    }

    public func createConfig(configDefinition: String) throws(SzError) -> any SzConfig {
        let definition = try state.execute { () throws(SzError) -> String in
            try NativeConfig.roundTrip(configDefinition)
        }
        return SzCoreConfig(state: state, definition: definition)
    }

    public func createConfig(configID: Int64) throws(SzError) -> any SzConfig {
        let definition = try state.execute { () throws(SzError) -> String in
            let result = SzConfigMgr_getConfig_helper(configID)
            return try Native.take(result.response, result.returnCode, .configManager)
        }
        return SzCoreConfig(state: state, definition: definition)
    }

    public func registerConfig(configDefinition: String, configComment: String) throws(SzError) -> Int64 {
        try state.execute { () throws(SzError) -> Int64 in
            let result = SzConfigMgr_registerConfig_helper(configDefinition, configComment)
            try Native.check(result.returnCode, .configManager)
            return result.configID
        }
    }

    public func getConfigRegistry() throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            let result = SzConfigMgr_getConfigRegistry_helper()
            return try Native.take(result.response, result.returnCode, .configManager)
        }
    }

    public func getDefaultConfigID() throws(SzError) -> Int64 {
        try state.execute { () throws(SzError) -> Int64 in
            let result = SzConfigMgr_getDefaultConfigID_helper()
            try Native.check(result.returnCode, .configManager)
            return result.configID
        }
    }

    public func replaceDefaultConfigID(currentDefaultConfigID: Int64, newDefaultConfigID: Int64) throws(SzError) {
        try state.execute { () throws(SzError) in
            try Native.check(
                SzConfigMgr_replaceDefaultConfigID(currentDefaultConfigID, newDefaultConfigID),
                .configManager
            )
        }
    }

    public func setDefaultConfigID(_ configID: Int64) throws(SzError) {
        try state.execute { () throws(SzError) in
            try Native.check(SzConfigMgr_setDefaultConfigID(configID), .configManager)
        }
    }

    public func setDefaultConfig(configDefinition: String, configComment: String) throws(SzError) -> Int64 {
        let configID = try registerConfig(configDefinition: configDefinition, configComment: configComment)
        try setDefaultConfigID(configID)
        return configID
    }
}
