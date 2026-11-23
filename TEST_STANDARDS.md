# Test standards

## Real engine only

There are no mocks, fakes or stubs of the native engine. Every engine test
runs against the installed Senzing runtime over a real SQLite repository.

## Isolation

- Each test creates its own `TestRepository`: a new temporary directory, a
  SQLite database built from the runtime's `szcore-schema-sqlite-create.sql`,
  and a default configuration registered through this SDK. `EngineFixture`
  wraps it with an environment and deletes everything on `deinit`.
- The native engine is one per process, so every engine suite is nested in the
  `EngineTests` suite, which is `.serialized`. Suites that do not touch the
  engine (`SzErrorTests`, `SzFlagsTests`, `InternalTests`) run in parallel.
- Test data is the Senzing demo truth set in
  `Tests/SenzingTestSupport/Resources/truthset`, plus small inline records.

## Naming and failure rules

- `test_*`: tests that fail on any error. A test never prints a failure and
  passes: use `#expect` / `#require`, or let the error propagate.
- `example_*`: example programs that must succeed completely; they exit
  non-zero when anything fails or the result is wrong.
- Expected engine errors are asserted with `expectSzError(kind) { ... }`, which
  fails if nothing is thrown or the kind is wrong.
- Expectations about engine behavior come from observed engine output, not
  from assumptions; when the engine's behavior is surprising (for example,
  reevaluating a missing record is a no-op), the test says so.

## Verification pattern for changes that persist

For anything that registers or creates state:

1. The operation succeeds.
2. The result is readable immediately.
3. It survives persistence (for example, `createConfig(configID:)` after
   `setDefaultConfig`).
4. The engine can use it (for example, add a record to a new data source).

## Coverage

`swift test --enable-code-coverage` reports coverage; the `SenzingSDK` module
is held at 100% line coverage. CI prints the per-file report.
