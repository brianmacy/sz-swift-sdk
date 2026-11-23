# Concurrency

Use the engine from many threads, or from Swift concurrency with
``SzAsyncEngine``.

## Overview

The native engine is thread-safe and the SDK's subsystems are `Sendable`, so
one engine can serve many threads at once. There is one engine per process:
only one ``SzCoreEnvironment`` may be active at a time.

Engine calls block the calling thread until the engine finishes. Do not call
them from the main actor, and avoid calling them from Swift concurrency's
cooperative thread pool, which has one thread per core.

## SzAsyncEngine

``SzAsyncEngine`` is an actor that runs each engine call on its own concurrent
dispatch queue and suspends the caller until the call completes. It bounds how
many native calls run at once (``SzAsyncEngine/maxConcurrentCalls``, by default
the number of active processors) and queues the rest in order.

```swift
let engine = SzAsyncEngine(try environment.getEngine())

try await withThrowingTaskGroup(of: Void.self) { group in
    for contact in contacts {
        group.addTask {
            try await engine.addRecord(dataSourceCode: "CONTACTS", recordID: contact.id, record: contact)
        }
    }
    try await group.waitForAll()
}
try await engine.processRedoRecords()
```

Methods without an `async` variant run through ``SzAsyncEngine/perform(_:)``:

```swift
let stats = try await engine.perform { (engine) throws(SzError) -> String in
    try engine.getStats()
}
```

A native call cannot be interrupted; task cancellation takes effect only
before a call starts.

## Lifecycle

``SzEnvironment/destroy()`` waits for in-flight calls to finish, then releases
the native engine. Later calls on any subsystem throw
``SzErrorKind/environmentDestroyed``. Releasing the last reference to an
environment destroys it.
