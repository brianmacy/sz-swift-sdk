# Getting Started

Install Senzing, add the package, create a repository, and resolve records.

## Install Senzing

SenzingSDK binds an installed Senzing runtime, version 4.5 or later. Nothing
from the runtime is part of this package.

On macOS (Apple silicon), install the Homebrew cask:

```bash
brew tap senzing/senzingsdk https://github.com/Senzing/homebrew-senzingsdk
brew trust --tap senzing/senzingsdk
brew install --cask senzingsdk
```

On Debian or Ubuntu, add Senzing's apt repository and install the runtime,
the setup package (the database schema scripts) and `sqlite3`:

```bash
wget https://senzing-production-apt.s3.amazonaws.com/senzingrepo_2.0.2-1_all.deb
sudo apt-get install -y ./senzingrepo_2.0.2-1_all.deb
sudo apt-get update
sudo apt-get install -y senzingsdk-runtime senzingsdk-setup sqlite3
```

## Add the package

```swift
.package(url: "https://github.com/brianmacy/sz-swift-sdk.git", from: "0.1.0")
```

SwiftPM finds the runtime's C headers and `libSz` through pkg-config. Write a
`senzing.pc` for the installed runtime with the repository's
`tools/senzing-pkgconfig.sh`. At run time, `libSz` must be found by the
loader: bundle it in an app, add an rpath to the runtime's `lib` directory, or
on Linux set `LD_LIBRARY_PATH`. The README has the details.

## Create a repository

The engine works on a repository described by its settings JSON. For a local
SQLite repository, create the database from the schema script that ships with
the runtime:

```bash
sqlite3 /tmp/G2C.db < /opt/senzing/er/resources/schema/szcore-schema-sqlite-create.sql
```

Then register a default configuration with the data sources you will load:

```swift
// The engine settings, from SENZING_ENGINE_CONFIGURATION_JSON. On Linux:
// {"PIPELINE":{"CONFIGPATH":"/etc/opt/senzing","RESOURCEPATH":"/opt/senzing/er/resources",
//  "SUPPORTPATH":"/opt/senzing/data"},"SQL":{"CONNECTION":"sqlite3://na:na@/tmp/G2C.db"}}
let settings = ProcessInfo.processInfo.environment["SENZING_ENGINE_CONFIGURATION_JSON"] ?? ""
let setup = try SzCoreEnvironment(instanceName: "setup", settings: settings)
let configManager = try setup.getConfigManager()
let config = try configManager.createConfig()
try config.registerDataSource("CUSTOMERS")
try configManager.setDefaultConfig(configDefinition: config.export())
setup.destroy()
```

Read the settings from the environment rather than writing them into code. On
macOS with the Homebrew cask, the paths are under
`$(brew --prefix)/opt/senzing`: `er/resources`, `data`, and `er/etc` for
`CONFIGPATH`.

## Resolve records

```swift
let environment = try SzCoreEnvironment(instanceName: "my-app", settings: settings)
defer { environment.destroy() }
let engine = try environment.getEngine()

try engine.addRecord(
    dataSourceCode: "CUSTOMERS",
    recordID: "1001",
    recordDefinition: #"{"NAME_FULL":"Robert Smith","DATE_OF_BIRTH":"1978-12-11"}"#
)

let entity = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
print(entity.resolvedEntity.entityID, entity.resolvedEntity.entityName ?? "")
```

Records can be any `Encodable` value whose coding keys are Senzing attribute
names:

```swift
struct Contact: Encodable {
    var name: String
    var email: String?
    enum CodingKeys: String, CodingKey {
        case name = "NAME_FULL"
        case email = "EMAIL_ADDRESS"
    }
}
try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1002", record: Contact(name: "Bob Smith"))
```

## Search and explain

```swift
let results = try engine.searchByAttributes(#"{"NAME_FULL":"Bob Smith"}"#, as: SzSearchResponse.self)
let why = try engine.whyRecords(
    dataSourceCode1: "CUSTOMERS", recordID1: "1001",
    dataSourceCode2: "CUSTOMERS", recordID2: "1002",
    as: SzWhyResponse.self
)
print(why.whyResults.first?.matchInfo.whyKey ?? "")
```

Every method also returns the engine's raw JSON when called without `as:`.
Pass ``SzFlags`` to control what the engine returns; each method defaults to
its own `...DefaultFlags`. Those defaults are for getting started: their
members can change between Senzing versions, so production code should pass
the flags it needs.

## iOS

The package declares iOS as a platform, but building for iOS needs a
separately built static Senzing library that is not available yet.
