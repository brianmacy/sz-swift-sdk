// example_logging: capture the engine's native log messages with SzLogging.
//
// The lifecycle the logging usage rule asks for:
//   1. getLogging() and register a callback BEFORE the engine is initialized,
//      so initialization messages are captured;
//   2. silence the default output (the callback is the only sink);
//   3. use the engine; setDefaultLogLevel is safe at any time;
//   4. destroy the environment, THEN unregister and restore the default output.
//
// The callback only updates counters under a lock: callbacks must be fast and
// must never call back into the engine.
//
// Run: swift run example_logging

import Foundation
import SenzingSDK
import SenzingTestSupport
import Synchronization

/// What the callback collects: counts per level and the first few messages.
struct LogStats {
    var byLevel: [SzLogLevel: Int] = [:]
    var firstMessages: [String] = []
}

func run() throws {
    let repository = try ExampleRepository()
    defer { repository.remove() }
    let environment = try SzCoreEnvironment(
        instanceName: "example_logging",
        settings: repository.settings,
        verboseLogging: true
    )
    defer { environment.destroy() }

    // (1) + (2): before the first getEngine().
    let logging = environment.getLogging()
    let stats = Mutex(LogStats())
    let registration = try logging.registerCallback(minLevel: .trace) { record in
        stats.withLock { stats in
            stats.byLevel[record.level, default: 0] += 1
            if stats.firstMessages.count < 3 {
                stats.firstMessages.append("[\(record.level)] \(record.module): \(record.message.prefix(100))")
            }
        }
    }
    try logging.setDefaultOutput(.null)
    print("Effective log level with a TRACE callback: \(logging.getEffectiveLogLevel())")

    // (3): initialization and engine calls reach the callback.
    let engine = try environment.getEngine()
    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "LOG1",
        recordDefinition: #"{"NAME_FULL":"Robert Smith","PHONE_NUMBER":"702-919-1300"}"#
    )
    logging.setDefaultLogLevel(.warn)
    try engine.addRecord(
        dataSourceCode: "CUSTOMERS",
        recordID: "LOG2",
        recordDefinition: #"{"NAME_FULL":"Bob Smith","PHONE_NUMBER":"702-919-1300"}"#
    )

    // (4): nothing else is logging after destroy(), so sinks may change.
    environment.destroy()
    registration.unregister()
    try logging.setDefaultOutput(.stderr)
    logging.setDefaultLogLevel(.error)

    let result = stats.withLock { $0 }
    let total = result.byLevel.values.reduce(0, +)
    guard total > 0 else {
        throw ExampleFailure("the callback received no log messages")
    }
    print("Captured \(total) messages:")
    for level in SzLogLevel.allCases {
        if let count = result.byLevel[level] {
            print("  \(level): \(count)")
        }
    }
    print("First messages:")
    result.firstMessages.forEach { print("  \($0)") }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("example_logging failed: \(error)\n".utf8))
    exit(1)
}
