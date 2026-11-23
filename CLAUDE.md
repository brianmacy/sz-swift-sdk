# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

`sz-swift-sdk` is an unofficial Swift SDK for Senzing V4. It follows the C#
SDK's object model (as `sz-cpp-sdk` and `sz-rust-sdk` do) with Swift naming
and Swift 6 types. [docs/api-mapping.md](docs/api-mapping.md) is the C# to
Swift contract. The repository is public: no internal details, unreleased
Senzing features, or private build information.

## Layout

| Path | Contents |
|---|---|
| `Package.swift` | Locates the installed runtime (`SENZING_DIR`, Homebrew cask, `/opt/senzing/er`); `-I` to its C headers, `-L` and rpath to `libSz`. |
| `Sources/CSenzing` | Module map + umbrella header over the runtime's C headers (nothing vendored). |
| `Sources/SenzingSDK/*.swift` | Public protocols (`SzEnvironment`, `SzEngine`, ...), `SzError`, `SzFlags`, defaults, typed and async APIs. |
| `Sources/SenzingSDK/Core` | `SzCore*` classes over the C API. |
| `Sources/SenzingSDK/Internal` | Native call helpers, locks, JSON helpers. |
| `Sources/SenzingSDK/Generated` | Flag constants and error table from `szflags.json` / `szerrors.json`. Do not edit. |
| `Sources/SenzingSDK/Models` | `Codable` response models. |
| `Sources/SenzingSDK/SenzingSDK.docc` | DocC catalog. |
| `Tests/SenzingTestSupport` | Repository provisioning, truth-set data (shared with examples). |
| `Tests/SenzingSDKTests` | Swift Testing suites. |
| `Examples/` | `example_*` executables. |
| `tools/generate-sdk-tables.swift` | Code generator: flags and error table. |
| `tools/generate-async-engine.swift` | Code generator: `SzAsyncEngine`'s async mirror of `SzEngine`. Rerun after any `SzEngine` change. |

## Commands

```bash
swift build
swift test                                   # real engine; needs sqlite3
swift test --enable-code-coverage
swift format lint --strict --recursive Package.swift Sources Tests Examples tools
swift format format --in-place --recursive Package.swift Sources Tests Examples tools
swift tools/generate-sdk-tables.swift        # regenerate from the installed runtime
swift run example_load_truthset
```

Set `SENZING_DIR` to build against a runtime other than the default location.

## Rules

- **Ground every C call in the installed headers** (`<runtime>/er/sdk/c/*.h`,
  `szhelpers/SzLang_helpers.h`), never memory. Use the `*_helper` functions;
  free every helper response buffer with `SzHelper_free` (`Native.take`), and
  never free the `SzProduct_getVersion` / `getLicense` buffers (engine-owned).
  Export handles are released with `Sz_closeExportReport_helper`.
- **Read native errors on the calling thread**, immediately after the call:
  the last-exception state is per thread.
- **Every native call runs inside `EnvironmentState.execute`** (shared lock);
  `destroy()` takes the lock exclusively. Never nest `execute`.
- **`SzAsyncEngine` runs calls on its own pthread workers**, never GCD or the
  cooperative pool: the engine keeps working state per OS thread. Its methods
  are generated; edit `SzEngine`, then run `swift tools/generate-async-engine.swift`.
- **`SzLogging` is the exception**: process-wide, outside any environment's
  lock and lifetime. Each registration's slot is native `user_data`; sink
  changes inside a callback throw `.configuration`. Logging tests change state
  only while no engine is initialized and restore stderr/legacy/ERROR.
- **Typed throws everywhere**: `throws(SzError)`. Closures passed to typed APIs
  need an explicit `throws(SzError)` annotation.
- **Protocol defaults** live in `SzEngine+Defaults.swift` as same-signature
  extension methods with default arguments; conforming types must implement
  every requirement.
- **No mocks.** Tests use the real engine (see TEST_STANDARDS.md). Assertions
  about engine behavior come from observed output.
- **100% line coverage** of `SenzingSDK`; swift-format lint clean.
- **Generated files** change only through the generator; CI fails on drift.
- **No AI attribution** in commits, PR bodies or files. Commits are GPG-signed.
- Docs: README, CHANGELOG (Keep a Changelog), DocC articles, and
  `docs/api-mapping.md` change with the API.
