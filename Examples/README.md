# Examples

Each example is a SwiftPM executable that runs against the real engine and
exits non-zero if anything fails or the result is wrong.

| Program | Source | Shows |
|---|---|---|
| `example_load_truthset` | [LoadTruthset](LoadTruthset/main.swift) | Load the Senzing truth set with info, process redo records, export and summarize the entities. |
| `example_search` | [Search](Search/main.swift) | Search by attributes built from an `Encodable` value; decode `SzSearchResponse`. |
| `example_why` | [Why](Why/main.swift) | `whyRecords`, `whyEntities` and `howEntity`, decoded into `SzWhyResponse`. |
| `example_async_engine` | [AsyncEngine](AsyncEngine/main.swift) | Concurrent `Encodable` contacts through `SzAsyncEngine` in a task group. |

```bash
swift run example_load_truthset
swift run example_search
swift run example_why
swift run example_async_engine
```

## The repository they use

By default each example creates a throwaway SQLite repository in a temporary
directory (schema from the runtime's `szcore-schema-sqlite-create.sql`, a
default configuration registered through this SDK) and deletes it on exit.
That needs the `sqlite3` command-line tool.

To run against an existing repository instead, set
`SENZING_ENGINE_CONFIGURATION_JSON` to its settings. Its default configuration
must already register the data sources the example loads (`CUSTOMERS`,
`REFERENCE`, `WATCHLIST`, or `CONTACTS` for `example_async_engine`). The
examples add records to it.

The shared helpers (`ExampleRepository`, `Truthset`) live in the
`SenzingTestSupport` target, which the tests use too.
