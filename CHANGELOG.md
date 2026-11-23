# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- SwiftPM package `SenzingSDK` over the Senzing V4 C API of an installed
  runtime (Senzing 4.5 or later): a `CSenzing` module map over the runtime's C
  headers, located through `$SENZING_DIR`, the Homebrew cask locations or
  `/opt/senzing/er`, with an rpath to `libSz`.
- The C# SDK object model: `SzEnvironment`/`SzCoreEnvironment` (initializer and
  builder; one active environment per process), `SzEngine`, `SzConfigManager`,
  `SzConfig`, `SzDiagnostic`, `SzProduct`, as protocols with native-backed
  `SzCore*` classes. Every C# method is present; each `flags` argument defaults
  to the method's `...DefaultFlags`.
- `SzFlags` (`OptionSet`) and `SzFlagUsageGroup`, generated from `szflags.json`.
- `SzError` with `SzErrorKind`: the C# exception hierarchy, with the native
  error-code table generated from `szerrors.json`; typed throws everywhere;
  `catch SzError.badInput`-style patterns that honor the hierarchy.
- `Codable` models for the common responses (`SzEntityResponse`,
  `SzSearchResponse`, `SzWhyResponse`, `SzWithInfoResponse`, `SzVersionInfo`,
  `SzLicenseInfo`, `SzConfigRegistry`, `SzDataSourceRegistry`), `as:` variants
  of the common calls, and `addRecord` for any `Encodable` record.
- `SzAsyncEngine`: an actor with `async` engine calls that run on a dedicated
  dispatch queue with bounded concurrency.
- `tools/generate-sdk-tables.swift`: regenerates the flag and error tables
  from an installed runtime.
- Swift Testing suite against the real engine (no mocks), an isolated SQLite
  repository per test, the Senzing demo truth set; 100% line coverage of the
  `SenzingSDK` module.
- Examples: `example_load_truthset`, `example_search`, `example_why`,
  `example_async_engine`.
- DocC documentation published to GitHub Pages; CI on macOS and Linux;
  swift-format lint; CodeQL and dependency review.
