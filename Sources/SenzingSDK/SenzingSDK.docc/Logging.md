# Logging

Receive the engine's native log messages in Swift, or redirect its default
output.

## Overview

``SzLogging`` wraps the runtime's `libSzLogging` C API. Its names follow the
Senzing C++ and Rust SDKs in the C# style. Get it from
``SzEnvironment/getLogging()``: logging is process-wide and does not depend on
the environment being initialized or alive.

```swift
let environment = try SzCoreEnvironment(instanceName: "my-app", settings: settings)
let logging = environment.getLogging()

// Before the first getEngine(): register, then silence stderr.
let registration = try logging.registerCallback(minLevel: .info) { record in
    print("[\(record.level)] \(record.module): \(record.message)")
}
try logging.setDefaultOutput(.null)

let engine = try environment.getEngine()
// ... use the engine; setDefaultLogLevel(_:) is safe at any time ...

environment.destroy()
registration.unregister()
try logging.setDefaultOutput(.stderr)
```

### When to change logging

Native applies sinks to its loggers as they are created. Register and
unregister callbacks, and change the default callback, output or format, only
before the first subsystem is initialized or after the environment is
destroyed. ``SzLogging/setDefaultLogLevel(_:)`` and
``SzLogging/getEffectiveLogLevel()`` are safe at any time.

### Callbacks

A callback receives an ``SzLogRecord``: the ``SzLogLevel``, the native module
and thread hash, and the message in the registration's ``SzLogFormat``
(``SzLogFormat/bare`` unless the options say otherwise). Native may call it
concurrently from many threads, so keep it fast and thread-safe, and never
call the engine from it. From inside a callback, calls that change sinks throw
``SzErrorKind/configuration``, and ``SzLogRegistration/unregister()`` stops
delivery without unregistering natively.

A registration unregisters when it is released; ``SzLogRegistration/leak()``
keeps it for the process lifetime. Registering a callback lowers the native
level to its minimum level if needed, and the native level stays there while
the callback is registered.

### The default sink

``SzLogging/setDefaultOutput(_:)`` sends the default sink to stderr, stdout, a
file or nowhere; ``SzLogging/setDefaultCallback(_:_:)`` makes a callback the
default sink. Changing the output resets the default format to
``SzLogFormat/legacy``, so call ``SzLogging/setDefaultFormat(_:)`` afterwards.
A file is created with its parent directories, truncated when opened, and
flushed when the output is replaced and at process exit.

### Verbose logging

`verboseLogging: true` on ``SzCoreEnvironment`` makes the subsystems log their
calls at ``SzLogLevel/trace``; a callback registered at that level receives
them.

### Not wrapped

`SzLogging_registerThreadLocalCallback` is not wrapped: the Senzing 4.5 runtime
accepts such a registration but delivers no messages to it.

## Topics

### Controls

- ``SzLogging``
- ``SzCoreLogging``
- ``SzLogRegistration``

### Values

- ``SzLogLevel``
- ``SzLogFormat``
- ``SzLogOutput``
- ``SzLogOutputType``
- ``SzLogCallbackOptions``
- ``SzLogRecord``
- ``SzLogCallback``
