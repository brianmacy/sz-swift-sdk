import Foundation
import SenzingTestSupport
import Synchronization
import Testing

@testable import SenzingSDK

/// Runs `body(index)` on `count` threads at once and waits for all of them.
func onThreads(_ count: Int, _ body: @escaping @Sendable (Int) -> Void) {
    let group = DispatchGroup()
    for index in 0..<count {
        group.enter()
        Thread {
            body(index)
            group.leave()
        }.start()
    }
    group.wait()
}

extension EngineTests {
    @Suite("Concurrency")
    struct SzConcurrencyTests {
        @Test("test_syncEngine: many threads add, get and delete distinct and shared records")
        func test_syncEngine() throws {
            let fixture = try EngineFixture()
            let engine = fixture.engine
            let failures = Mutex<[String]>([])
            onThreads(8) { worker in
                for index in 0..<25 {
                    let own = "T\(worker)-\(index)"
                    let shared = "SHARED-\(index % 5)"
                    do {
                        try engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: own, recordDefinition: person(own))
                        try engine.addRecord(
                            dataSourceCode: "CUSTOMERS", recordID: shared, recordDefinition: person("Shared \(worker)"))
                        _ = try engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: own)
                        do {
                            _ = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: shared)
                        } catch SzError.notFound {
                            // Another thread is re-resolving this shared record's
                            // entity: the engine reports SENZ0037 for the moment.
                        }
                        try engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: own)
                    } catch {
                        failures.withLock { $0.append("\(own): \(error)") }
                    }
                }
            }
            #expect(failures.withLock { $0 }.isEmpty, "\(failures.withLock { $0 })")
            for index in 0..<5 {
                #expect(
                    try engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "SHARED-\(index)").contains("Shared"))
            }
            expectSzError(.notFound) { _ = try engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "T0-0") }
        }

        @Test("test_destroyRace: calls racing destroy() succeed or fail with environmentDestroyed")
        func test_destroyRace() throws {
            let fixture = try EngineFixture()
            let engine = fixture.engine
            let environment = fixture.environment
            let completed = Atomic(0)
            let outcomes = Mutex<[String]>([])
            let started = DispatchSemaphore(value: 0)
            let group = DispatchGroup()
            for worker in 0..<8 {
                group.enter()
                Thread {
                    defer { group.leave() }
                    started.signal()
                    var index = 0
                    while true {
                        do {
                            let id = "R\(worker)-\(index)"
                            try engine.addRecord(
                                dataSourceCode: "CUSTOMERS", recordID: id, recordDefinition: person(id))
                            _ = try engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: id)
                            completed.add(1, ordering: .relaxed)
                            index += 1
                        } catch {
                            outcomes.withLock { $0.append((error as? SzError)?.kind.rawValue ?? "\(error)") }
                            return
                        }
                    }
                }.start()
            }
            for _ in 0..<8 {
                started.wait()
            }
            while completed.load(ordering: .relaxed) < 40 {
                Thread.sleep(forTimeInterval: 0.005)
            }
            environment.destroy()
            group.wait()
            #expect(outcomes.withLock { $0 } == Array(repeating: SzErrorKind.environmentDestroyed.rawValue, count: 8))
        }

        @Test("test_reentrancy: an SDK call from a log callback during an SDK call fails instead of deadlocking")
        func test_reentrancy() throws {
            let logging = try LoggingFixture()
            let repository = try TestRepository()
            defer { repository.remove() }
            let environment = try SzCoreEnvironment(
                instanceName: "reentrancy", settings: repository.settings, verboseLogging: true)
            let engine = try environment.getEngine()
            let outcome = Mutex<String?>(nil)
            let destroyed = DispatchSemaphore(value: 0)
            let registration = try logging.logging.registerCallback(minLevel: .trace) { record in
                guard record.message.hasPrefix("Sz_stats("), outcome.withLock({ $0 == nil }) else {
                    return
                }
                outcome.withLock { $0 = "pending" }
                // destroy() now waits for this call to finish.
                Thread {
                    environment.destroy()
                    destroyed.signal()
                }.start()
                Thread.sleep(forTimeInterval: 0.2)
                do {
                    _ = try engine.countRedoRecords()
                    outcome.withLock { $0 = "reentered" }
                } catch {
                    outcome.withLock { $0 = "\(error)" }
                }
            }
            _ = try engine.getStats()
            #expect(destroyed.wait(timeout: .now() + 60) == .success, "destroy() finished after the call")
            registration.unregister()
            #expect(environment.isDestroyed)
            let result = try #require(outcome.withLock { $0 })
            #expect(result.contains("Re-entrant Senzing call"), "\(result)")
        }

        @Test("test_destroyInsideCall: destroy() from a log callback runs when the SDK call returns")
        func test_destroyInsideCall() throws {
            let logging = try LoggingFixture()
            let repository = try TestRepository()
            defer { repository.remove() }
            let environment = try SzCoreEnvironment(
                instanceName: "destroy-inside", settings: repository.settings, verboseLogging: true)
            let engine = try environment.getEngine()
            let seenDuringCall = Mutex<Bool?>(nil)
            let registration = try logging.logging.registerCallback(minLevel: .trace) { record in
                guard record.message.hasPrefix("Sz_stats("), seenDuringCall.withLock({ $0 == nil }) else {
                    return
                }
                environment.destroy()  // returns at once: waiting here would deadlock
                seenDuringCall.withLock { $0 = environment.isDestroyed }
            }
            #expect(try engine.getStats().contains("workload"), "the running call completes")
            registration.unregister()
            #expect(seenDuringCall.withLock { $0 } == false, "not destroyed while the call ran")
            #expect(environment.isDestroyed, "destroyed when the call returned")
            #expect(SzCoreEnvironment.getActiveInstance() == nil)
            expectSzError(.environmentDestroyed) { _ = try engine.getStats() }
        }
    }
}
