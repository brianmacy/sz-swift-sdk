# Error Handling

Every SenzingSDK method throws ``SzError``, with a kind from the C# exception
hierarchy.

## Overview

The engine reports a native error code; ``SzErrorKind/forErrorCode(_:)`` maps
it to a kind with the table generated from the runtime's `szerrors.json`. The
kinds form the same tree as the C# exceptions:

| Kind | Parent |
|---|---|
| ``SzErrorKind/general`` | (root) |
| ``SzErrorKind/badInput`` | general |
| ``SzErrorKind/notFound``, ``SzErrorKind/unknownDataSource`` | badInput |
| ``SzErrorKind/configuration``, ``SzErrorKind/replaceConflict`` | general |
| ``SzErrorKind/retryable`` | general |
| ``SzErrorKind/databaseConnectionLost``, ``SzErrorKind/databaseTransient``, ``SzErrorKind/retryTimeoutExceeded`` | retryable |
| ``SzErrorKind/unrecoverable`` | general |
| ``SzErrorKind/database``, ``SzErrorKind/license``, ``SzErrorKind/notInitialized``, ``SzErrorKind/unhandled`` | unrecoverable |

Two kinds come from the SDK rather than the engine and sit outside the tree:
``SzErrorKind/environmentDestroyed`` (a subsystem used after
``SzEnvironment/destroy()``) and ``SzErrorKind/json`` (a typed record or
result could not be encoded or decoded).

## Matching errors

The kind patterns on ``SzError`` match a kind and everything below it:

```swift
do {
    try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1", recordDefinition: json)
} catch SzError.unknownDataSource {
    // register the data source first
} catch SzError.badInput {
    // any other bad input, including notFound
} catch SzError.retryable {
    // try again later
} catch {
    print(error.kind, error.errorCode ?? 0, error.message)
}
```

``SzError/isKind(of:)``, ``SzError/isRetryable`` and
``SzError/isUnrecoverable`` answer the same questions in code.
