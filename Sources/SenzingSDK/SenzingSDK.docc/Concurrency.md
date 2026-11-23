# Concurrency

Use the engine from many threads, or from Swift concurrency with
``SzAsyncEngine``.

## Overview

The Senzing engine is synchronous: each call blocks its thread until it
finishes. It is also thread-safe, so one engine serves many threads at once,
and the SDK's subsystems are `Sendable`.

`Sendable` means an object is safe to share across threads. It does not make
concurrent writes to the same record deterministic: Senzing applies the last
one.

## Which API should I use?

| You are writing | Use |
|---|---|
| A command-line tool, a server, or code on threads you own | The synchronous ``SzEngine`` |
| Swift concurrency code, SwiftUI, anything on the main actor | ``SzAsyncEngine`` |

Never call the synchronous API on the main actor or from Swift concurrency's
cooperative thread pool: a blocked thread there stalls the UI or other tasks.

``SzAsyncEngine`` is a Swift-only convenience, with no counterpart in the
official Senzing SDKs. `await` does not make a call faster or non-blocking: it
keeps the blocking work off the main actor and the cooperative pool by running
it on the SDK's own worker threads. Calls run in parallel inside the engine up
to ``SzAsyncEngine/maxConcurrentCalls``; the worker pool only enforces that cap.

## Threads and the engine

Senzing's published threading guidance, which this SDK follows:

- Create the environment once per process and share it across all threads.
  Never create one per call or per thread. Only one ``SzCoreEnvironment`` may
  be active at a time.
- Load data through a pool of threads that share one engine. Senzing suggests
  starting at 2–8 worker threads per CPU core and tuning to the storage's
  throughput; loading from a single thread is slow.
- Engine memory is native: about 4 GB per engine process plus 0.5–1 GB per
  engine thread.

The engine builds its working state per OS thread, on the thread's first engine
call, and releases it when the thread exits. With the synchronous API, call the
engine from long-lived threads you own and reuse, never from per-call threads or
detached tasks, which rebuild that state each time.

``SzAsyncEngine`` follows the same rule: it starts
``SzAsyncEngine/maxConcurrentCalls`` worker threads once and runs every call on
them, in submission order. The default,
``SzAsyncEngine/defaultMaxConcurrentCalls``, is the processor count capped at 4,
to bound per-thread memory on desktops and mobile devices. Raise it for server
loads. More concurrency does not raise throughput on SQLite, which allows one
writer at a time.

Loading the same data concurrently can resolve entities and relationships
slightly differently than loading it serially. That is expected engine
behavior, not a bug.

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
let redo = try await engine.processRedoRecords()
for failure in redo.failed where failure.error.isRetryable {
    _ = try await engine.processRedoRecord(failure.redoRecord)
}
```

``SzAsyncEngine/processRedoRecords()`` returns an ``SzRedoReport``. Fetching a
redo record removes it from the queue, so a record that fails to process is
returned in ``SzRedoReport/failed`` with its error instead of being lost.

Every ``SzEngine`` method has an `async` counterpart. Anything else runs on a
worker through ``SzAsyncEngine/perform(_:)``:

```swift
let stats = try await engine.perform { engine in
    try engine.getStats()
}
```

## Cancellation

A call whose task is cancelled before a worker starts it throws
`CancellationError` and never reaches the engine. A call that has started
cannot be interrupted: it runs to completion and its changes are committed.

## Lifecycle

``SzEnvironment/destroy()`` first stops every ``SzAsyncEngine`` over the
environment: queued calls fail with ``SzErrorKind/environmentDestroyed``,
running calls finish, and the worker threads are joined, so their per-thread
engine state is released. Then it waits for in-flight synchronous calls and
releases the native engine. Later calls on any subsystem throw
``SzErrorKind/environmentDestroyed``. Releasing the last reference to an
environment destroys it. ``SzAsyncEngine/shutdown()`` stops one
``SzAsyncEngine`` early.

## Re-entrant calls

Never call the SDK from a log callback. An SDK call made from inside another
SDK call on the same thread (from a log callback, the only code that runs
there) throws an ``SzError`` instead of deadlocking. ``SzEnvironment/destroy()``
called there returns at once, and the environment is destroyed as soon as the
running call returns.
