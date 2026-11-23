# C# SDK to Swift mapping

The Swift SDK follows the object model of the official C# SDK (as do
[sz-cpp-sdk](https://github.com/brianmacy/sz-cpp-sdk) and
[sz-rust-sdk](https://github.com/brianmacy/sz-rust-sdk)). Type names are the
same; members use Swift naming.

## Rules

| C# | Swift |
|---|---|
| Interface `SzEngine`, class `SzCoreEngine` | Protocol `SzEngine`, final class `SzCoreEngine` (same for every subsystem) |
| Method `GetEntity` | Method `getEntity`, with argument labels (`getEntity(dataSourceCode:recordID:flags:)`) |
| `string` (JSON) | `String`; the common calls also take `as: T.Type` to decode into a `Decodable` type |
| `long` IDs | `Int64` |
| `int` degrees, counts, seconds | `Int` |
| `string` that is `null` without `SzWithInfo` | `String?` (`nil` without `.withInfo`) |
| `ISet<long>`, `ISet<string>` | `Set<Int64>`, `Set<String>` |
| `ISet<(string, string)>` record keys | `Set<SzRecordKey>` |
| `IntPtr` export handle | `SzExportHandle` |
| `FetchNext` returning `null` at the end | `fetchNext(_:)` returning `nil` |
| `SzFlag?` with a per-method default | `flags: SzFlags = .<method>DefaultFlags` |
| `SzFlag.SzEntityIncludeEntityName` | `SzFlags.entityIncludeEntityName` (the `Sz` prefix dropped, lower camel case) |
| `SzException` and subclasses | `SzError` with an `SzErrorKind` (same tree) |
| `SzEnvironmentDestroyedException` | `SzError` of kind `.environmentDestroyed` (outside the engine tree, as in C#) |
| `SzCoreEnvironment.NewBuilder()...Build()` | `SzCoreEnvironment.newBuilder()...build()`, or `SzCoreEnvironment(instanceName:settings:verboseLogging:configID:)` |

## SzEnvironment

| C# | Swift |
|---|---|
| `GetProduct()` | `getProduct()` |
| `GetEngine()` | `getEngine()` |
| `GetConfigManager()` | `getConfigManager()` |
| `GetDiagnostic()` | `getDiagnostic()` |
| `GetActiveConfigID()` | `getActiveConfigID()` |
| `Reinitialize(configID)` | `reinitialize(configID:)` |
| `Destroy()` | `destroy()` |
| `IsDestroyed()` | `isDestroyed` |
| `SzCoreEnvironment.GetActiveInstance()` | `SzCoreEnvironment.getActiveInstance()` |
| `GetLogging()` (C++/Rust SDKs) | `getLogging()` |

## SzEngine

| C# | Swift |
|---|---|
| `PrimeEngine()` | `primeEngine()` |
| `GetStats()` | `getStats()` |
| `AddRecord(ds, id, def, flags)` | `addRecord(dataSourceCode:recordID:recordDefinition:flags:)`; also `record:` (any `Encodable`) and `as:` |
| `GetRecordPreview(def, flags)` | `getRecordPreview(_:flags:)` |
| `DeleteRecord(ds, id, flags)` | `deleteRecord(dataSourceCode:recordID:flags:)`; also `as:` |
| `ReevaluateRecord(ds, id, flags)` | `reevaluateRecord(dataSourceCode:recordID:flags:)` |
| `ReevaluateEntity(id, flags)` | `reevaluateEntity(_:flags:)` |
| `SearchByAttributes(attrs, profile, flags)` | `searchByAttributes(_:searchProfile:flags:)`; also `as:` |
| `WhySearch(attrs, id, profile, flags)` | `whySearch(_:entityID:searchProfile:flags:)` |
| `GetEntity(id, flags)` | `getEntity(_:flags:)`; also `as:` |
| `GetEntity(ds, id, flags)` | `getEntity(dataSourceCode:recordID:flags:)`; also `as:` |
| `GetRecord(ds, id, flags)` | `getRecord(dataSourceCode:recordID:flags:)` |
| `FindInterestingEntities(id, flags)` | `findInterestingEntities(_:flags:)` |
| `FindInterestingEntities(ds, id, flags)` | `findInterestingEntities(dataSourceCode:recordID:flags:)` |
| `FindPath(start, end, degrees, avoid, required, flags)` | `findPath(startEntityID:endEntityID:maxDegrees:avoidEntityIDs:requiredDataSources:flags:)` |
| `FindPath(ds1, id1, ds2, id2, degrees, avoid, required, flags)` | `findPath(startDataSourceCode:startRecordID:endDataSourceCode:endRecordID:maxDegrees:avoidRecordKeys:requiredDataSources:flags:)` |
| `FindNetwork(ids, degrees, buildOut, maxEntities, flags)` | `findNetwork(entityIDs:maxDegrees:buildOutDegrees:buildOutMaxEntities:flags:)` |
| `FindNetwork(keys, degrees, buildOut, maxEntities, flags)` | `findNetwork(recordKeys:maxDegrees:buildOutDegrees:buildOutMaxEntities:flags:)` |
| `WhyRecordInEntity(ds, id, flags)` | `whyRecordInEntity(dataSourceCode:recordID:flags:)`; also `as:` |
| `WhyRecords(ds1, id1, ds2, id2, flags)` | `whyRecords(dataSourceCode1:recordID1:dataSourceCode2:recordID2:flags:)`; also `as:` |
| `WhyEntities(id1, id2, flags)` | `whyEntities(entityID1:entityID2:flags:)`; also `as:` |
| `HowEntity(id, flags)` | `howEntity(_:flags:)` |
| `GetVirtualEntity(keys, flags)` | `getVirtualEntity(_:flags:)` |
| `ExportJsonEntityReport(flags)` | `exportJsonEntityReport(flags:)`; also `exportJsonEntityLines(flags:)` and `exportJsonEntityReport(flags:as:)` |
| `ExportCsvEntityReport(columns, flags)` | `exportCsvEntityReport(csvColumnList:flags:)` |
| `FetchNext(handle)` | `fetchNext(_:)` |
| `CloseExportReport(handle)` | `closeExportReport(_:)` |
| `ProcessRedoRecord(redo, flags)` | `processRedoRecord(_:flags:)` |
| `GetRedoRecord()` | `getRedoRecord()` (`nil` when none is pending) |
| `CountRedoRecords()` | `countRedoRecords()` |

## SzConfigManager and SzConfig

| C# | Swift |
|---|---|
| `CreateConfig()` | `createConfig()` |
| `CreateConfig(definition)` | `createConfig(configDefinition:)` |
| `CreateConfig(configID)` | `createConfig(configID:)` |
| `RegisterConfig(definition, comment)` | `registerConfig(configDefinition:configComment:)` |
| `RegisterConfig(definition)` | `registerConfig(configDefinition:)` (comment generated as in C#) |
| `GetConfigRegistry()` | `getConfigRegistry()`; also `as:` |
| `GetDefaultConfigID()` | `getDefaultConfigID()` |
| `ReplaceDefaultConfigID(current, new)` | `replaceDefaultConfigID(currentDefaultConfigID:newDefaultConfigID:)` |
| `SetDefaultConfigID(configID)` | `setDefaultConfigID(_:)` |
| `SetDefaultConfig(definition, comment)` | `setDefaultConfig(configDefinition:configComment:)` |
| `SetDefaultConfig(definition)` | `setDefaultConfig(configDefinition:)` |
| `SzConfig.Export()` | `export()` |
| `SzConfig.GetDataSourceRegistry()` | `getDataSourceRegistry()`; also `as:` |
| `SzConfig.RegisterDataSource(code)` | `registerDataSource(_:)` |
| `SzConfig.UnregisterDataSource(code)` | `unregisterDataSource(_:)` |

## SzDiagnostic and SzProduct

| C# | Swift |
|---|---|
| `GetRepositoryInfo()` | `getRepositoryInfo()` |
| `CheckRepositoryPerformance(seconds)` | `checkRepositoryPerformance(secondsToRun:)` |
| `PurgeRepository()` | `purgeRepository()` |
| `GetFeature(featureID)` | `getFeature(featureID:)` |
| `GetLicense()` | `getLicense()`; also `as:` |
| `GetVersion()` | `getVersion()`; also `as:` |

## SzLogging

The C# SDK has no logging API. `SzLogging` follows the Senzing C++ and Rust
SDKs (C# naming) over the 4.5 `libSzLogging.h` C API.

| C++ SDK | Swift | C API |
|---|---|---|
| `SzCoreLogging::GetInstance()` | `SzCoreLogging.getInstance()` | |
| `RegisterCallback(options, callback)` | `registerCallback(_:_:)`, `registerCallback(minLevel:_:)` | `SzLogging_registerCallbackWithFormat` |
| `SetDefaultCallback(options, callback)` | `setDefaultCallback(_:_:)` | `SzLogging_setDefaultCallback` (+ `SzLogging_setDefaultFormatter`) |
| `SetDefaultOutput(output)` | `setDefaultOutput(_:)` | `SzLogging_setDefaultOutput` |
| `SetDefaultFormat(format)` | `setDefaultFormat(_:)` | `SzLogging_setDefaultFormatter` |
| `SetDefaultLogLevel(level)` | `setDefaultLogLevel(_:)` | `SzLogging_setLogLevel` |
| `GetEffectiveLogLevel()` | `getEffectiveLogLevel()` | `SzLogging_getLogLevel` |
| `SzLogRegistration::Unregister()` / `Leak()` | `unregister()` / `leak()`; released = unregistered | `SzLogging_unregisterCallback` |
| `SzLogLevel`, `SzLogFormat`, `SzLogOutputType` | enums of the same names; `init(parsing:)`, `description` | |
| `SzLogOutput::Stderr()` ... `File(path)` | `SzLogOutput.stderr` ... `.file(path)` | |
| `SzLogCallbackOptions(minLevel).WithFormat(f)` | `SzLogCallbackOptions(minLevel:format:)`, `withFormat(_:)` | |
| `SzLogRecord` / `SzLogEntry` | `SzLogRecord` (an owned value) | |

Not wrapped: `SzLogging_registerThreadLocalCallback` (the 4.5 runtime accepts
the registration but delivers no messages) and `SzLogging_registerCallback`
(the legacy-format form of `registerCallbackWithFormat`).

## C API coverage

Every function in the 4.5 headers is wrapped except these, which the C++ and
Rust SDKs do not wrap either:

- `Sz_setBundleArchive`, `Sz_setBundleArchiveFromMemory` (`libSz.h`).
- `SzProduct_validateLicenseFile`, `SzProduct_validateLicenseStringBase64`
  (`libSzProduct.h`) and their helpers.
- The non-`_V2` engine helpers, superseded by the `_V2` forms the SDK calls.
- `libSzEngineFlags.h` and `libSzEngineFlagGroups.h`: the same flags as
  `szflags.json`, from which `SzFlags` is generated.

## Swift additions

- `SzAsyncEngine`: an `async` counterpart of every `SzEngine` method
  (generated by `tools/generate-async-engine.swift`), plus `perform(_:)` and
  `processRedoRecords()`, run on a fixed pool of long-lived worker threads.
  No official Senzing SDK has it.
- `SzFlagUsageGroup`: the flag usage groups from `szflags.json`, with
  `allFlags` for each.
- `SzRecordKey`: the record-key value type used in sets.
- `Codable` models of the common responses.
