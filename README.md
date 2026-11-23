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
brew trust --tap senzing/senzingsdk
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
    .package(url: "https://github.com/brianmacy/sz-swift-sdk.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "SenzingSDK", package: "sz-swift-sdk")]),
]
```

SwiftPM finds the runtime's C headers and `libSz` through pkg-config, from a
`senzing.pc` file. Senzing does not ship one; `tools/senzing-pkgconfig.sh`
writes it for an installed runtime, into a directory SwiftPM always searches
(`$(brew --prefix)/lib/pkgconfig` on macOS, `/usr/local/lib/pkgconfig` on
Linux):

```bash
curl -fsSL https://raw.githubusercontent.com/brianmacy/sz-swift-sdk/0.1.0/tools/senzing-pkgconfig.sh | bash
```

It takes the runtime's `er` directory as an optional argument (default:
`$SENZING_DIR`, the Homebrew cask, then `/opt/senzing/er`). The file it writes
is short enough to write by hand:

```text
libdir=/opt/senzing/er/lib
includedir=/opt/senzing/er/sdk/c

Name: senzing
Description: Senzing SDK runtime (C API and libSz)
Version: 4.5.0
Cflags: -I${includedir}
Libs: -L${libdir} -lSz
```

At run time `libSz` must be found by the loader. A macOS app bundles it, or a
command-line tool adds an rpath to the runtime's `lib` directory in its own
target (allowed in a root package):

```swift
.executableTarget(
    name: "MyTool",
    dependencies: [.product(name: "SenzingSDK", package: "sz-swift-sdk")],
    // The runtime's lib directory: on macOS, $(brew --prefix)/opt/senzing/er/lib.
    linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "<runtime>/er/lib"])]
)
```

On Linux, set `LD_LIBRARY_PATH=/opt/senzing/er/lib` (as for every Senzing
SDK) or add an rpath the same way.

## Quick start

```swift
import Foundation
import SenzingSDK

// The engine settings come from the environment, not the code.
let settings = ProcessInfo.processInfo.environment["SENZING_ENGINE_CONFIGURATION_JSON"] ?? ""

do {
    let environment = try SzCoreEnvironment(instanceName: "quick-start", settings: settings)
    defer { environment.destroy() }
    let engine = try environment.getEngine()

    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "1001",
        recordDefinition: #"{"NAME_FULL":"Robert Smith","DATE_OF_BIRTH":"1978-12-11"}"#
    )
    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "1002",
        recordDefinition: #"{"NAME_FULL":"Bob Smith","DATE_OF_BIRTH":"1978-11-12"}"#
    )

    let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
    print(entity.resolvedEntity.entityName ?? "", entity.resolvedEntity.records?.map(\.recordID) ?? [])
} catch SzError.notFound {
    print("no such record")
} catch {
    print(error)  // SzError: kind, errorCode, message
}
```

`SENZING_ENGINE_CONFIGURATION_JSON` holds the engine settings. On Linux:

```json
{"PIPELINE":{"CONFIGPATH":"/etc/opt/senzing","RESOURCEPATH":"/opt/senzing/er/resources",
 "SUPPORTPATH":"/opt/senzing/data"},"SQL":{"CONNECTION":"sqlite3://na:na@/tmp/G2C.db"}}
```

On macOS with the Homebrew cask, the same paths are under
`$(brew --prefix)/opt/senzing`: `er/etc` (`CONFIGPATH`), `er/resources` and
`data`.

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
| `SzAsyncEngine` | Every engine method as `async`, on a fixed pool of worker threads. |
| `SzLogging` | Native log callbacks, default output, format and level (`environment.getLogging()`). |
| `SzFlags` | An `OptionSet` of every flag in `szflags.json`; each method defaults to its `...DefaultFlags` (for getting started: production code should pass the flags it needs). |
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

**Which API should I use?** The Senzing engine is synchronous and
thread-safe: each call blocks its thread, and calls from many threads run in
parallel.

- CLI tools, servers, threads you own: the synchronous `SzEngine`. Call it
  from long-lived threads you reuse; the engine builds working state per
  thread, so per-call threads and detached tasks rebuild it each time.
- Swift concurrency and SwiftUI: `SzAsyncEngine`. Never call the synchronous
  API on the main actor or the cooperative thread pool.

`SzAsyncEngine` is a Swift-only convenience with no counterpart in the
official Senzing SDKs. `await` does not make calls faster or non-blocking: it
runs them on a fixed pool of long-lived worker threads
(`maxConcurrentCalls`, default: processor count capped at 4) so the blocking
work stays off the main actor and the cooperative pool. Every `SzEngine`
method has an `async` counterpart; a task cancelled before its call starts
throws `CancellationError` and never reaches the engine, and a started call
runs to completion. More concurrency does not raise throughput on SQLite (one
writer at a time), and concurrent loading can resolve entities slightly
differently than a serial load of the same data, as the engine does.

```swift
let engine = SzAsyncEngine(try environment.getEngine())
try await engine.addRecord(dataSourceCode: "CONTACTS", recordID: contact.id, record: contact)
let results = try await engine.searchByAttributes(query, as: SzSearchResponse.self)
```

**Logging.** `environment.getLogging()` receives the engine's native log
messages in a callback or redirects its default output. Register before the
first `getEngine()` and unregister after `destroy()`:

```swift
let logging = environment.getLogging()
let registration = try logging.registerCallback(minLevel: .warn) { record in
    print("[\(record.level)] \(record.message)")
}
try logging.setDefaultOutput(.null)
```

## Examples

| Program | Shows |
|---|---|
| `example_load_truthset` | Register data sources, load the Senzing truth set, summarize the entities. |
| `example_search` | Search by attributes with an `Encodable` query; decoded results. |
| `example_why` | Why two records resolved; why two entities are related. |
| `example_async_engine` | Concurrent loading with `SzAsyncEngine` from a task group. |
| `example_logging` | Capture native log messages with an `SzLogging` callback. |

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
tools/tsan.sh        # ThreadSanitizer, macOS only, local (not in CI)
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

CI runs lint, the full Linux suite (tests, 100% coverage, examples, generated
code drift), DocC and CodeQL for the workflows on Linux ARM runners; macOS CI
only builds and runs the tests. CodeQL for the Swift sources needs macOS, so it
runs weekly and on demand. ThreadSanitizer runs locally with `tools/tsan.sh` on macOS: on
Linux the Senzing runtime loads its database plugins with `RTLD_DEEPBIND`,
which ThreadSanitizer cannot run with.

## iOS

The package declares iOS as a platform so an app can depend on it, but
building for iOS needs a separately built static Senzing library that is not
available yet.

## License

Apache-2.0; see [LICENSE](LICENSE). The bundled truth-set test data comes from
[Senzing/truth-sets](https://github.com/Senzing/truth-sets) under Apache-2.0.
Senzing itself is installed separately under its own license terms.
