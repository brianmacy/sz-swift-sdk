# ``SenzingSDK``

An idiomatic Swift SDK for Senzing V4 entity resolution.

## Overview

SenzingSDK binds the C API of an installed Senzing runtime and presents the
object model of the official C# SDK with Swift 6 types: typed throws,
`Sendable` subsystems, an `async` actor, and `Codable` results.

```swift
let environment = try SzCoreEnvironment(instanceName: "my-app", settings: settings)
defer { environment.destroy() }
let engine = try environment.getEngine()
try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1001", recordDefinition: json)
let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
```

This is an unofficial SDK; it is not supported by Senzing, Inc. It requires a
separate Senzing installation, which has its own license terms.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ErrorHandling>
- <doc:Concurrency>
- ``SzEnvironment``
- ``SzCoreEnvironment``

### Subsystems

- ``SzEngine``
- ``SzConfigManager``
- ``SzConfig``
- ``SzDiagnostic``
- ``SzProduct``
- ``SzAsyncEngine``

### Flags

- ``SzFlags``
- ``SzFlagUsageGroup``

### Errors

- ``SzError``
- ``SzErrorKind``

### Results

- ``SzEntityResponse``
- ``SzResolvedEntity``
- ``SzRelatedEntity``
- ``SzEntityRecord``
- ``SzEntityFeature``
- ``SzFeatureValue``
- ``SzRecordSummary``
- ``SzSearchResponse``
- ``SzSearchResult``
- ``SzMatchInfo``
- ``SzFeatureScore``
- ``SzCandidateKey``
- ``SzWhyResponse``
- ``SzWhyResult``
- ``SzWithInfoResponse``
- ``SzEntityReference``
- ``SzVersionInfo``
- ``SzLicenseInfo``
- ``SzConfigRegistry``
- ``SzDataSourceRegistry``

### Values

- ``SzRecordKey``
- ``SzExportHandle``

### Implementations

- ``SzCoreEngine``
- ``SzCoreConfigManager``
- ``SzCoreConfig``
- ``SzCoreDiagnostic``
- ``SzCoreProduct``
