# sz-swift-sdk

[![CI](https://github.com/brianmacy/sz-swift-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/brianmacy/sz-swift-sdk/actions/workflows/ci.yml)
[![Docs](https://github.com/brianmacy/sz-swift-sdk/actions/workflows/docs.yml/badge.svg)](https://brianmacy.github.io/sz-swift-sdk/documentation/senzingsdk/)
[![Security](https://github.com/brianmacy/sz-swift-sdk/actions/workflows/security.yml/badge.svg)](https://github.com/brianmacy/sz-swift-sdk/actions/workflows/security.yml)

An idiomatic Swift SDK for [Senzing](https://senzing.com) V4 entity resolution,
for Swift developers on Apple platforms and Linux. It follows the object model
of the official C# SDK (`SzEnvironment` → `SzEngine`, `SzConfigManager`,
`SzConfig`, `SzDiagnostic`, `SzProduct`), like its siblings
[sz-cpp-sdk](https://github.com/brianmacy/sz-cpp-sdk) and
[sz-rust-sdk](https://github.com/brianmacy/sz-rust-sdk), with Swift 6 types:
typed throws, `Sendable` subsystems, an `async` actor for Swift concurrency,
and `Codable` results.

All entity resolution is done by the native Senzing engine (`libSz`); this
package binds its stable C API.

> This is an unofficial SDK; it is not supported by Senzing, Inc. Licensed
> under Apache-2.0. It requires a separate Senzing installation, which has its
> own license terms.

**[API documentation](https://brianmacy.github.io/sz-swift-sdk/documentation/senzingsdk/)**

## Requirements

| | |
|---|---|
| Swift | 6.0 or later (Swift 6 language mode) |
| Senzing | 4.5 or later, installed separately |
| macOS | 15 or later, Apple silicon (the Senzing Homebrew cask) |
| Linux | x86-64 or arm64 with the Senzing apt packages (CI: Ubuntu 24.04) |
| iOS | Not yet: see [iOS](#ios) |

## Install Senzing

**macOS** (Homebrew):

```bash
brew tap senzing/senzingsdk https://github.com/Senzing/homebrew-senzingsdk
brew install --cask senzingsdk
```

**Linux** (Debian/Ubuntu, Senzing's apt repository):

```bash
wget https://senzing-production-apt.s3.amazonaws.com/senzingrepo_2.0.2-1_all.deb
sudo apt-get install -y ./senzingrepo_2.0.2-1_all.deb
sudo apt-get update
sudo apt-get install -y senzingsdk-runtime senzingsdk-setup sqlite3
```

Installing Senzing requires accepting the
[Senzing EULA](https://senzing.com/end-user-license-agreement); see each
installer for the non-interactive acceptance setting.

## Add the package

```swift
dependencies: [
    .package(url: "https://github.com/brianmacy/sz-swift-sdk.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "SenzingSDK", package: "sz-swift-sdk")]),
]
```

`Package.swift` finds the installed runtime's headers and `libSz` in this
order: `$SENZING_DIR` (the runtime's `er` directory), the Homebrew cask
locations, then `/opt/senzing/er`. It embeds the library directory as an
rpath, so programs run without `DYLD_LIBRARY_PATH` or `LD_LIBRARY_PATH`.

Locating an installed library uses SwiftPM's unsafe build flags, which SwiftPM
accepts for root packages and for branch, revision or local-path dependencies,
but not for dependencies pinned to a version.

## Quick start

```swift
import SenzingSDK

let settings = """
    {"PIPELINE":{"CONFIGPATH":"/etc/opt/senzing","RESOURCEPATH":"/opt/senzing/er/resources",
     "SUPPORTPATH":"/opt/senzing/data"},"SQL":{"CONNECTION":"sqlite3://na:na@/tmp/G2C.db"}}
    """

do {
    let environment = try SzCoreEnvironment(instanceName: "quick-start", settings: settings)
    defer { environment.destroy() }
    let engine = try environment.getEngine()

    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "1001",
        recordDefinition: #"{"NAME_FULL":"Robert Smith","DATE_OF_BIRTH":"12/11/1978"}"#
    )
    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "1002",
        recordDefinition: #"{"NAME_FULL":"Bob Smith","DATE_OF_BIRTH":"11/12/1978"}"#
    )

    let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
    print(entity.resolvedEntity.entityName ?? "", entity.resolvedEntity.records?.map(\.recordID) ?? [])
} catch SzError.notFound {
    print("no such record")
} catch {
    print(error)  // SzError: kind, errorCode, message
}
```

The repository needs its schema and a default configuration that registers
`CUSTOMERS`; the [examples](Examples/README.md) and the tests create a fresh
SQLite repository that way.

## The API

| Type | Role |
|---|---|
| `SzEnvironment` / `SzCoreEnvironment` | Entry point and lifecycle; lazily creates each subsystem. One per process. |
| `SzEngine` | Records, entities, search, why/how, paths, networks, export, redo. |
| `SzConfigManager`, `SzConfig` | Register data sources; manage and set the default configuration. |
| `SzDiagnostic`, `SzProduct` | Repository diagnostics; version and license. |
| `SzAsyncEngine` | An actor with `async` variants of the engine calls. |
| `SzFlags` | An `OptionSet` of every flag in `szflags.json`; each method defaults to its `...DefaultFlags`. |
| `SzError`, `SzErrorKind` | Typed errors in the C# exception hierarchy, generated from `szerrors.json`. |

Names follow the C# SDK in Swift form: `AddRecord` → `addRecord`,
`SzEntityDefaultFlags` → `.entityDefaultFlags`, `SzNotFoundException` →
`SzError` of kind `.notFound`. [docs/api-mapping.md](docs/api-mapping.md) has the
full mapping.

**Raw JSON or `Codable`.** Every engine method returns the engine's JSON. The
common calls also take `as:` to decode into the models in this package
(`SzEntityResponse`, `SzSearchResponse`, `SzWhyResponse`, `SzWithInfoResponse`,
...) or any `Decodable` type of your own, and `addRecord` accepts any
`Encodable` record whose coding keys are Senzing attribute names.

**Errors.** Every method `throws(SzError)`. Match a kind and its descendants
with `catch SzError.badInput` (which also catches `.notFound` and
`.unknownDataSource`), or test `error.isKind(of:)`, `error.isRetryable`.

**Concurrency.** The subsystems are `Sendable` and the native engine is
thread-safe. Engine calls block their thread, so from the main actor or Swift
concurrency use `SzAsyncEngine`, which runs calls on its own dispatch queue
and bounds how many run at once:

```swift
let engine = SzAsyncEngine(try environment.getEngine())
try await engine.addRecord(dataSourceCode: "CONTACTS", recordID: contact.id, record: contact)
let results = try await engine.searchByAttributes(query, as: SzSearchResponse.self)
```

## Examples

| Program | Shows |
|---|---|
| `example_load_truthset` | Register data sources, load the Senzing truth set, summarize the entities. |
| `example_search` | Search by attributes with an `Encodable` query; decoded results. |
| `example_why` | Why two records resolved; why two entities are related. |
| `example_async_engine` | Concurrent loading with `SzAsyncEngine` from a task group. |

```bash
swift run example_load_truthset
```

Each creates a throwaway SQLite repository unless
`SENZING_ENGINE_CONFIGURATION_JSON` is set. See [Examples/README.md](Examples/README.md).

## Build and test

```bash
swift build
swift test
swift test --enable-code-coverage
swift format lint --strict --recursive Package.swift Sources Tests Examples tools
```

The tests run against the real engine, with no mocks: each test creates its
own SQLite repository from the schema shipped with the runtime (with the
`sqlite3` tool) and deletes it afterwards. Engine suites run serially because
the native engine is one per process. See [TEST_STANDARDS.md](TEST_STANDARDS.md).

`SzFlags` constants and the error-code table are generated from the runtime's
`szflags.json` and `szerrors.json`:

```bash
swift tools/generate-sdk-tables.swift
```

CI regenerates them against the installed runtime and fails on any drift.

## iOS

The package declares iOS as a platform so an app can depend on it, but
building for iOS needs a separately built static Senzing library that is not
available yet.

## License

Apache-2.0; see [LICENSE](LICENSE). The bundled truth-set test data comes from
[Senzing/truth-sets](https://github.com/Senzing/truth-sets) under Apache-2.0.
Senzing itself is installed separately under its own license terms.
