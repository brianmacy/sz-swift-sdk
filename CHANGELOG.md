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
- `SzLogging` over the `libSzLogging.h` C API, following the Senzing C++ and
  Rust SDKs: `environment.getLogging()` / `SzCoreLogging.getInstance()`,
  process-wide callbacks (`registerCallback`, released or `unregister()`ed
  registrations, `leak()`), the default callback, output (stderr, stdout,
  file, null), format and level, and `getEffectiveLogLevel()`. Example
  `example_logging`.
- `SzAsyncEngine`: an `async` counterpart of every `SzEngine` method,
  generated from the `SzEngine` declarations (`tools/generate-async-engine.swift`,
  drift-checked in CI), run on a fixed pool of long-lived worker threads
  (`maxConcurrentCalls`, default: processor count capped at 4). Calls
  cancelled before they start throw `CancellationError`; started calls run to
  completion. `destroy()` fails queued calls and joins the workers before
  native teardown. Measured on Senzing 4.5.0 (macOS, Apple silicon, 4 bursts
  of 400 `getEntity` calls 8 s apart, 8 concurrent calls): a GCD-queue design
  touched 32 distinct OS threads, and the first call on each new thread took
  a median 9.1 ms against 1.0 ms warm; the worker pool used exactly 8 threads, paid the
  cold first call 8 times instead of 32, and ran warm calls at a median 0.95 ms.
- SDK calls made from inside an SDK call on the same thread (from a log
  callback) throw instead of deadlocking behind a waiting `destroy()`;
  `destroy()` from there takes effect when the running call returns.
- `tools/generate-sdk-tables.swift`: regenerates the flag and error tables
  from an installed runtime.
- Swift Testing suite against the real engine (no mocks), an isolated SQLite
  repository per test, the Senzing demo truth set; 100% line coverage of the
  `SenzingSDK` module.
- Examples: `example_load_truthset`, `example_search`, `example_why`,
  `example_async_engine`.
- DocC documentation published to GitHub Pages; CI on macOS and Linux;
  swift-format lint; CodeQL and dependency review.
