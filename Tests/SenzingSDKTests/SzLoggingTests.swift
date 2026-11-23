import CSenzing
import Foundation
import SenzingTestSupport
import Synchronization
import Testing

@testable import SenzingSDK

/// A thread-safe sink of the records a callback receives.
final class LogCollector: Sendable {
    private let storage = Mutex<[SzLogRecord]>([])

    var records: [SzLogRecord] {
        storage.withLock { $0 }
    }

    func add(_ record: SzLogRecord) {
        storage.withLock { $0.append(record) }
    }

    func matching(_ marker: String) -> [SzLogRecord] {
        records.filter { $0.message.contains(marker) }
    }
}

/// Process-wide logging state for one test, against the real native
/// `libSzLogging` (no mocks).
///
/// Logging is process-global, so the default output is silenced on entry and
/// the native defaults (stderr, legacy format, ERROR) are restored on exit.
/// Tests change logging only while no engine is initialized, as the
/// ``SzLogging`` usage rule asks.
final class LoggingFixture {
    let logging = SzCoreLogging.getInstance()
    let directory: URL
    /// A regular file: any path beneath it cannot be opened.
    private let blocker: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sz-swift-sdk-logging-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        blocker = directory.appendingPathComponent("blocker")
        try Data("blocker".utf8).write(to: blocker)
        try logging.setDefaultOutput(.null)
        logging.setDefaultLogLevel(.error)
    }

    deinit {
        try? logging.setDefaultOutput(.stderr)
        try? logging.setDefaultFormat(.legacy)
        logging.setDefaultLogLevel(.error)
        try? FileManager.default.removeItem(at: directory)
    }

    /// A path that cannot be opened, naming `marker`.
    func unopenablePath(_ marker: String) -> String {
        blocker.appendingPathComponent("\(marker).log").path
    }

    /// Makes native log an ERROR that names `marker`, on the calling thread.
    ///
    /// Native `SzLogging_setDefaultOutput` with a file it cannot open logs the
    /// failure and keeps the previous output. The SDK rejects such a path
    /// before the native call, so this calls native directly.
    func emitError(_ marker: String) {
        SzLogging_setDefaultOutput(SzLogOutputType.file.rawValue, unopenablePath(marker))
    }

    func readFile(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}

extension EngineTests {
    @Suite("SzLogging")
    struct SzLoggingTests {
        @Test("test_levels parse and print their canonical names")
        func test_levels() throws {
            for level in SzLogLevel.allCases {
                #expect(try SzLogLevel(parsing: level.description) == level)
                #expect(try SzLogLevel(parsing: " \(level.description.lowercased())\n") == level)
            }
            #expect(
                SzLogLevel.allCases.map(\.description) == [
                    "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL", "OFF",
                ])
            #expect(try SzLogLevel(parsing: "Warning") == .warn)
            #expect(SzLogLevel.trace < .debug && SzLogLevel.critical < .off)
            #expect(SzLogLevel.allCases.sorted() == SzLogLevel.allCases)
            #expect(SzLogLevel.allCases.map(\.rawValue) == Array(0...6))
            let error = expectSzError(.badInput) { _ = try SzLogLevel(parsing: "LOUD") }
            #expect(error?.message.contains("LOUD") == true)
        }

        @Test("test_formats parse and print their canonical names")
        func test_formats() throws {
            for format in SzLogFormat.allCases {
                #expect(try SzLogFormat(parsing: format.description.lowercased()) == format)
            }
            #expect(SzLogFormat.allCases.map(\.description) == ["LEGACY", "JSONL", "BARE", "DEFAULT"])
            #expect(try SzLogFormat(parsing: " json ") == .jsonl)
            #expect(SzLogFormat.allCases.map(\.rawValue) == Array(0...3))
            #expect(SzLogOutputType.allCases.map(\.rawValue) == Array(0...3))
            expectSzError(.badInput) { _ = try SzLogFormat(parsing: "XML") }
        }

        @Test("test_valueTypes: options, outputs and records")
        func test_valueTypes() {
            let options = SzLogCallbackOptions(minLevel: .warn)
            #expect(options.format == .bare)
            #expect(options.withFormat(.jsonl) == SzLogCallbackOptions(minLevel: .warn, format: .jsonl))
            #expect(options.format == .bare)

            #expect(SzLogOutput.stderr.outputType == .stderr && SzLogOutput.stderr.path == nil)
            #expect(SzLogOutput.stdout.outputType == .stdout)
            #expect(SzLogOutput.null.outputType == .null && SzLogOutput.null.path == nil)
            #expect(SzLogOutput.file("/x/y.log").outputType == .file)
            #expect(SzLogOutput.file("/x/y.log").path == "/x/y.log")

            let record = SzLogRecord(level: .info, rawModule: "a:b:82eb15f5", message: "hello")
            #expect(record.module == "a:b" && record.threadHash == "82eb15f5")
            #expect(record.rawModule == "a:b:82eb15f5" && record.message == "hello" && record.level == .info)
            let bare = SzLogRecord(level: .info, rawModule: "solo", message: "")
            #expect(bare.module == "solo" && bare.threadHash.isEmpty)
        }

        @Test("test_getLogging works without and after an initialized environment")
        func test_getLogging() throws {
            let fixture = try LoggingFixture()
            let environment = try SzCoreEnvironment()
            #expect(environment.getLogging() === SzCoreLogging.getInstance())
            environment.destroy()
            let logging = environment.getLogging()
            logging.setDefaultLogLevel(.warn)
            #expect(logging.getEffectiveLogLevel() == .warn)
            _ = fixture
        }

        @Test("test_registerCallback receives native messages in the bare format")
        func test_registerCallback() throws {
            let fixture = try LoggingFixture()
            let collector = LogCollector()
            let registration = try fixture.logging.registerCallback(minLevel: .error, collector.add)
            fixture.emitError("register-bare")
            registration.unregister()

            let records = collector.matching("register-bare")
            try #require(records.count == 1)
            let record = records[0]
            #expect(record.level == .error)
            #expect(!record.module.isEmpty && !record.threadHash.isEmpty)
            #expect(record.rawModule == "\(record.module):\(record.threadHash)")
            #expect(!record.message.hasPrefix("20"), "bare has no timestamp: \(record.message)")
        }

        @Test("test_callbackFormats: legacy, JSONL and default")
        func test_callbackFormats() throws {
            let fixture = try LoggingFixture()
            let legacy = LogCollector()
            let jsonl = LogCollector()
            let raw = LogCollector()
            let registrations = [
                try fixture.logging.registerCallback(
                    SzLogCallbackOptions(minLevel: .error, format: .legacy), legacy.add),
                try fixture.logging.registerCallback(SzLogCallbackOptions(minLevel: .error, format: .jsonl), jsonl.add),
                try fixture.logging.registerCallback(SzLogCallbackOptions(minLevel: .error, format: .default), raw.add),
            ]
            fixture.emitError("formats")
            registrations.forEach { $0.unregister() }

            let legacyRecord = try #require(legacy.matching("formats").first)
            #expect(legacyRecord.message.contains("[\(legacyRecord.rawModule)]"), "\(legacyRecord.message)")
            let jsonRecord = try #require(jsonl.matching("formats").first)
            let object = try JSONSerialization.jsonObject(with: Data(jsonRecord.message.utf8)) as? [String: Any]
            #expect(object?["severity"] as? String == "error")
            #expect((object?["message"] as? String)?.contains("formats") == true)
            #expect(raw.matching("formats").count == 1)
        }

        @Test("test_minLevel filters lower-severity messages")
        func test_minLevel() throws {
            let fixture = try LoggingFixture()
            let collector = LogCollector()
            let registration = try fixture.logging.registerCallback(minLevel: .critical, collector.add)
            fixture.emitError("filtered")
            registration.unregister()
            #expect(collector.matching("filtered").isEmpty)
        }

        @Test("test_unregister stops delivery, is idempotent and runs on release")
        func test_unregister() throws {
            let fixture = try LoggingFixture()
            let collector = LogCollector()
            let registration = try fixture.logging.registerCallback(minLevel: .error, collector.add)
            #expect(registration.isRegistered)
            fixture.emitError("unregister-1")
            registration.unregister()
            #expect(!registration.isRegistered)
            registration.unregister()
            fixture.emitError("unregister-2")
            #expect(collector.matching("unregister-1").count == 1)
            #expect(collector.matching("unregister-2").isEmpty)

            let released = LogCollector()
            do {
                let scoped = try fixture.logging.registerCallback(minLevel: .error, released.add)
                fixture.emitError("released-1")
                withExtendedLifetime(scoped) {}
            }
            fixture.emitError("released-2")
            #expect(released.matching("released-1").count == 1)
            #expect(released.matching("released-2").isEmpty)
        }

        @Test("test_leak keeps a released callback registered")
        func test_leak() throws {
            let fixture = try LoggingFixture()
            let collector = LogCollector()
            do {
                // Stays registered for the rest of the process; ERROR matches
                // the native default level, so it lowers nothing.
                let registration = try fixture.logging.registerCallback(minLevel: .error, collector.add)
                registration.leak()
                #expect(registration.isRegistered)
                registration.unregister()
                #expect(registration.isRegistered, "a leaked registration cannot be unregistered")
            }
            fixture.emitError("leaked")
            #expect(collector.matching("leaked").count == 1)
        }

        @Test("test_insideCallback refuses sink changes and defers unregistration")
        func test_insideCallback() throws {
            let fixture = try LoggingFixture()
            let logging = fixture.logging
            let outcomes = Mutex<[String]>([])
            let handle = Mutex<(any SzLogRegistration)?>(nil)
            let directory = fixture.directory.path
            let registration = try logging.registerCallback(minLevel: .error) { record in
                guard record.message.contains("inside") else {
                    return
                }
                func attempt(_ name: String, _ body: () throws(SzError) -> Void) {
                    do {
                        try body()
                        outcomes.withLock { $0.append("\(name):ok") }
                    } catch {
                        outcomes.withLock { $0.append("\(name):\(error.kind.rawValue)") }
                    }
                }
                attempt("register") { () throws(SzError) in _ = try logging.registerCallback(minLevel: .error) { _ in }
                }
                attempt("defaultCallback") { () throws(SzError) in
                    try logging.setDefaultCallback(SzLogCallbackOptions(minLevel: .error)) { _ in }
                }
                attempt("output") { () throws(SzError) in try logging.setDefaultOutput(.file(directory + "/x.log")) }
                attempt("format") { () throws(SzError) in try logging.setDefaultFormat(.jsonl) }
                attempt("level") { () throws(SzError) in logging.setDefaultLogLevel(.error) }
                handle.withLock { $0?.unregister() }
            }
            handle.withLock { $0 = registration }
            fixture.emitError("inside-1")
            #expect(!registration.isRegistered)
            fixture.emitError("inside-2")
            let failure = SzErrorKind.configuration.rawValue
            #expect(
                outcomes.withLock { $0 } == [
                    "register:\(failure)", "defaultCallback:\(failure)", "output:\(failure)", "format:\(failure)",
                    "level:ok",
                ]
            )
            #expect(!FileManager.default.fileExists(atPath: directory + "/x.log"))
        }

        @Test("test_setDefaultCallback replaces the default sink until the output changes")
        func test_setDefaultCallback() throws {
            let fixture = try LoggingFixture()
            let bare = LogCollector()
            try fixture.logging.setDefaultCallback(SzLogCallbackOptions(minLevel: .error), bare.add)
            fixture.emitError("default-bare")
            let legacy = LogCollector()
            try fixture.logging.setDefaultCallback(SzLogCallbackOptions(minLevel: .error, format: .legacy), legacy.add)
            fixture.emitError("default-legacy")
            try fixture.logging.setDefaultOutput(.null)
            fixture.emitError("default-replaced")

            let bareRecord = try #require(bare.matching("default-bare").first)
            #expect(!bareRecord.message.hasPrefix("20"), "\(bareRecord.message)")
            let legacyRecord = try #require(legacy.matching("default-legacy").first)
            #expect(legacyRecord.message.contains("[\(legacyRecord.rawModule)]"), "\(legacyRecord.message)")
            #expect(bare.matching("default-legacy").isEmpty)
            #expect(legacy.matching("default-replaced").isEmpty)
        }

        @Test("test_defaultOutputFile writes JSONL after the output change resets the format")
        func test_defaultOutputFile() throws {
            let fixture = try LoggingFixture()
            let path = fixture.directory.appendingPathComponent("missing/nested/sz.log").path
            try fixture.logging.setDefaultOutput(.file(path))
            #expect(FileManager.default.fileExists(atPath: path), "parent directories are created")
            try fixture.logging.setDefaultFormat(.jsonl)
            fixture.emitError("file-jsonl")
            try fixture.logging.setDefaultOutput(.null)  // flushes and closes

            let line = try #require(fixture.readFile(path).split(separator: "\n").first { $0.contains("file-jsonl") })
            let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            #expect(object?["severity"] as? String == "error", "\(line)")

            // Changing the output resets the format to legacy, and truncates.
            try fixture.logging.setDefaultOutput(.file(path))
            fixture.emitError("file-legacy")
            try fixture.logging.setDefaultOutput(.stdout)
            try fixture.logging.setDefaultOutput(.stderr)
            try fixture.logging.setDefaultOutput(.null)
            let text = try fixture.readFile(path)
            #expect(!text.contains("file-jsonl"), "\(text)")
            let legacy = try #require(text.split(separator: "\n").first { $0.contains("file-legacy") })
            #expect(!legacy.hasPrefix("{"), "\(legacy)")
        }

        @Test("test_defaultOutputFile rejects unusable paths before native")
        func test_defaultOutputFileErrors() throws {
            let fixture = try LoggingFixture()
            expectSzError(.badInput) { try fixture.logging.setDefaultOutput(.file("")) }
            expectSzError(.badInput) { try fixture.logging.setDefaultOutput(.file("a\0b.log")) }
            let error = expectSzError(.badInput) {
                try fixture.logging.setDefaultOutput(.file(fixture.unopenablePath("bad")))
            }
            #expect(error?.message.contains("bad.log") == true)
            expectSzError(.badInput) { try fixture.logging.setDefaultOutput(.file(fixture.directory.path)) }
        }

        @Test("test_effectiveLogLevel follows the default level and registered callbacks")
        func test_effectiveLogLevel() throws {
            let fixture = try LoggingFixture()
            fixture.logging.setDefaultLogLevel(.warn)
            #expect(fixture.logging.getEffectiveLogLevel() == .warn)
            fixture.logging.setDefaultLogLevel(.off)
            // At most ERROR: test_leak's callback stays registered at ERROR.
            #expect(fixture.logging.getEffectiveLogLevel() >= .error)

            let registration = try fixture.logging.registerCallback(minLevel: .debug) { _ in }
            #expect(fixture.logging.getEffectiveLogLevel() == .debug, "lowered to the callback's level")
            fixture.logging.setDefaultLogLevel(.error)
            #expect(fixture.logging.getEffectiveLogLevel() == .debug, "kept for the callback")
            registration.unregister()
            fixture.logging.setDefaultLogLevel(.error)
            #expect(fixture.logging.getEffectiveLogLevel() == .error)
        }

        @Test("test_verboseLogging delivers engine trace messages to a callback")
        func test_verboseLogging() throws {
            let fixture = try LoggingFixture()
            let collector = LogCollector()
            let registration = try fixture.logging.registerCallback(minLevel: .trace, collector.add)
            let environment = try SzCoreEnvironment(instanceName: "logging-verbose", verboseLogging: true)
            // No repository in the settings: initialization fails, after logging.
            expectSzError(.general) { _ = try environment.getEngine() }
            environment.destroy()
            registration.unregister()

            let trace = collector.records.filter { $0.level == .trace && $0.message.contains("Sz_init(") }
            #expect(trace.count == 1, "\(collector.records)")
            #expect(trace.first?.message.contains("logging-verbose") == true)
        }

        @Test("test_nativeBoundary drops invalid deliveries and refused registrations")
        func test_nativeBoundary() throws {
            let collector = LogCollector()
            let slot = LogCallbackSlot(collector.add)
            let userData = Unmanaged.passUnretained(slot).toOpaque()
            "m:h".withCString { module in
                "boundary".withCString { message in
                    logTrampoline(SzLogLevel.info.rawValue, nil, message, userData)
                    logTrampoline(SzLogLevel.info.rawValue, module, nil, userData)
                    logTrampoline(SzLogLevel.info.rawValue, module, message, nil)
                    logTrampoline(SzLogLevel.off.rawValue, module, message, userData)
                    logTrampoline(99, module, message, userData)
                    logTrampoline(-1, module, message, userData)
                    logTrampoline(SzLogLevel.info.rawValue, module, message, userData)
                    slot.active.store(false, ordering: .releasing)
                    logTrampoline(SzLogLevel.info.rawValue, module, message, userData)
                }
            }
            #expect(collector.records == [SzLogRecord(level: .info, rawModule: "m:h", message: "boundary")])

            // A refused registration releases the native user_data reference.
            let refused = LogCallbackSlot { _ in }
            _ = Unmanaged.passRetained(refused)
            let error = expectSzError(.unrecoverable) { _ = try SzCoreLogRegistration.adopt(nil, slot: refused) }
            #expect(error?.message.contains("refused") == true)
            withExtendedLifetime(refused) {}  // an over-release would crash here
        }
    }
}
