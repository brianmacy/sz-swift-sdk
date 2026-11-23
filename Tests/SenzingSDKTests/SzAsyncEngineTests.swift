import Foundation
import SenzingTestSupport
import Synchronization
import Testing

@testable import SenzingSDK

/// An identifier of the current OS thread, stable while the thread lives.
func currentThreadToken() -> UInt {
    #if canImport(Darwin)
    UInt(bitPattern: Int(bitPattern: UnsafeRawPointer(pthread_self())))
    #else
    UInt(pthread_self())
    #endif
}

/// A thread-safe counter that closures and tasks can share.
final class Counter: Sendable {
    private let value = Atomic(0)

    init() {}

    var count: Int {
        value.load(ordering: .relaxed)
    }

    func increment() {
        value.add(1, ordering: .relaxed)
    }
}

/// A thread-safe set of the OS threads that ran some code.
final class ThreadSet: Sendable {
    private let threads = Mutex<Set<UInt>>([])

    init() {}

    var all: Set<UInt> {
        threads.withLock { $0 }
    }

    func insertCurrent() {
        threads.withLock { _ = $0.insert(currentThreadToken()) }
    }
}

/// A gate that holds a worker inside `perform` until the test opens it.
final class Gate: Sendable {
    private let entered = DispatchSemaphore(value: 0)
    private let released = DispatchSemaphore(value: 0)

    /// Called on the worker: signals entry, then blocks until ``open()``.
    func hold() {
        entered.signal()
        released.wait()
    }

    /// Waits (off the cooperative pool) until a worker is held.
    func waitUntilHeld() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.entered.wait()
                continuation.resume()
            }
        }
    }

    func open() {
        released.signal()
    }
}

/// Polls `condition` (each check off the cooperative pool) until it holds.
func eventually(_ condition: @escaping @Sendable () -> Bool) async throws {
    for _ in 0..<500 where !condition() {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
}

extension EngineTests {
    @Suite("SzAsyncEngine")
    struct SzAsyncEngineTests {
        @Test("test_concurrent async loading resolves the truth set")
        func test_concurrentLoad() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 3)
            #expect(engine.maxConcurrentCalls == 3)
            let records = try Truthset.allRecords()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for record in records {
                    group.addTask {
                        try await engine.addRecord(
                            dataSourceCode: record.dataSourceCode,
                            recordID: record.recordID,
                            recordDefinition: record.definition
                        )
                    }
                }
                try await group.waitForAll()
            }
            #expect(try await engine.processRedoRecords() >= 0)
            let entity = try await engine.getEntity(
                dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
            let keys = Set(try #require(entity.resolvedEntity.records).map(\.recordKey))
            #expect(
                keys.isSuperset(of: [.of("CUSTOMERS", "1002"), .of("CUSTOMERS", "1003"), .of("CUSTOMERS", "1004")]))
            let exported = try await engine.exportJsonEntityReport(as: SzEntityResponse.self)
            let total = exported.reduce(0) { $0 + ($1.resolvedEntity.records?.count ?? 0) }
            #expect(total == records.count)
        }

        @Test("test_records: every async record method matches the engine")
        func test_records() async throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = SzAsyncEngine(fixture.engine)
            #expect(engine.maxConcurrentCalls == SzAsyncEngine.defaultMaxConcurrentCalls)
            #expect((1...4).contains(SzAsyncEngine.defaultMaxConcurrentCalls))
            try await engine.primeEngine()
            #expect(try await engine.getStats().contains("workload"))
            let info = try await engine.addRecord(
                dataSourceCode: "CUSTOMERS", recordID: "A1", recordDefinition: person("Ann Lee"), flags: .withInfo)
            #expect(info?.contains("A1") == true)
            let typedInfo = try await engine.addRecord(
                dataSourceCode: "CUSTOMERS", recordID: "A2", recordDefinition: person("Ann Lee"),
                as: SzWithInfoResponse.self)
            #expect(typedInfo.recordID == "A2")
            try await engine.addRecord(
                dataSourceCode: "CUSTOMERS", recordID: "A3", record: Contact(fullName: "Ann Lee", email: "ann@x.com"))
            #expect(try await engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "A3").contains("ann@x.com"))
            #expect(try await engine.getRecordPreview(person("Ann Lee")).contains("FEATURES"))
            #expect(try await engine.reevaluateRecord(dataSourceCode: "CUSTOMERS", recordID: "A3") == nil)
            let entityID = try fixture.entityID("CUSTOMERS", "A3")
            #expect(try await engine.reevaluateEntity(entityID) == nil)
            #expect(try await engine.deleteRecord(dataSourceCode: "CUSTOMERS", recordID: "A3") == nil)
            let deleted = try await engine.deleteRecord(
                dataSourceCode: "CUSTOMERS", recordID: "A2", as: SzWithInfoResponse.self)
            #expect(deleted.recordID == "A2")

            #expect(try await engine.countRedoRecords() >= 0)
            while let redo = try await engine.getRedoRecord() {
                try await engine.processRedoRecord(redo)
            }
            #expect(try await engine.countRedoRecords() == 0)
        }

        @Test("test_entities: every async read method matches the engine")
        func test_entities() async throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let sync = fixture.engine
            let engine = SzAsyncEngine(sync)
            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            let other = try fixture.entityID("WATCHLIST", "1006")
            #expect(try await engine.getEntity(entityID) == sync.getEntity(entityID))
            #expect(try await engine.getEntity(entityID, as: SzEntityResponse.self).resolvedEntity.entityID == entityID)
            #expect(
                try await engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001")
                    == sync.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001"))
            let byRecord = try await engine.getEntity(
                dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
            #expect(byRecord.resolvedEntity.entityID == entityID)

            let query = person("Robert Smith", ["DATE_OF_BIRTH": "12/11/1978"])
            #expect(try await engine.searchByAttributes(query) == sync.searchByAttributes(query))
            let results = try await engine.searchByAttributes(query, as: SzSearchResponse.self)
            #expect(results.resolvedEntities.first?.entity.resolvedEntity.entityID == entityID)
            #expect(try await engine.whySearch(query, entityID: entityID).contains("WHY_RESULTS"))
            #expect(try await engine.howEntity(entityID).contains("RESOLUTION_STEPS"))
            #expect(try await engine.findInterestingEntities(entityID).contains("INTERESTING_ENTITIES"))
            #expect(
                try await engine.findInterestingEntities(dataSourceCode: "CUSTOMERS", recordID: "1001")
                    .contains("INTERESTING_ENTITIES"))
            let virtual = try await engine.getVirtualEntity([.of("CUSTOMERS", "1001"), .of("CUSTOMERS", "1002")])
            #expect(virtual.contains("RESOLVED_ENTITY"))

            #expect(
                try await engine.findPath(startEntityID: entityID, endEntityID: other, maxDegrees: 3)
                    .contains("ENTITY_PATHS"))
            let pathByRecord = try await engine.findPath(
                startDataSourceCode: "CUSTOMERS", startRecordID: "1001",
                endDataSourceCode: "WATCHLIST", endRecordID: "1006", maxDegrees: 3)
            #expect(pathByRecord.contains("ENTITY_PATHS"))
            let network = try await engine.findNetwork(
                entityIDs: [entityID, other], maxDegrees: 2, buildOutDegrees: 1, buildOutMaxEntities: 10)
            #expect(network.contains("ENTITY_NETWORK_LINKS"))
            let networkByRecord = try await engine.findNetwork(
                recordKeys: [.of("CUSTOMERS", "1001")], maxDegrees: 1, buildOutDegrees: 1, buildOutMaxEntities: 10)
            #expect(networkByRecord.contains("ENTITY_NETWORK_LINKS"))
        }

        @Test("test_whyAndExport: every async why and export method matches the engine")
        func test_whyAndExport() async throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = SzAsyncEngine(fixture.engine)
            let entityID = try fixture.entityID("CUSTOMERS", "1001")
            let other = try fixture.entityID("WATCHLIST", "1006")
            #expect(try await engine.whyRecordInEntity(dataSourceCode: "CUSTOMERS", recordID: "1001").contains("WHY"))
            let inEntity = try await engine.whyRecordInEntity(
                dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzWhyResponse.self)
            #expect(inEntity.whyResults.isEmpty == false)
            let whyRecords = try await engine.whyRecords(
                dataSourceCode1: "CUSTOMERS", recordID1: "1001", dataSourceCode2: "CUSTOMERS", recordID2: "1002")
            #expect(whyRecords.contains("WHY_RESULTS"))
            let typedRecords = try await engine.whyRecords(
                dataSourceCode1: "CUSTOMERS", recordID1: "1001", dataSourceCode2: "CUSTOMERS", recordID2: "1002",
                as: SzWhyResponse.self)
            #expect(typedRecords.whyResults.first?.matchInfo.matchLevelCode == "RESOLVED")
            #expect(try await engine.whyEntities(entityID1: entityID, entityID2: other).contains("WHY_RESULTS"))
            let typedEntities = try await engine.whyEntities(
                entityID1: entityID, entityID2: other, as: SzWhyResponse.self)
            #expect(typedEntities.whyResults.first?.entityID2 == other)

            let lines = try await engine.exportJsonEntityLines()
            #expect(lines == (try fixture.engine.exportJsonEntityLines()))
            #expect(try await engine.exportJsonEntityReport(as: SzEntityResponse.self).count == lines.count)
            let handle = try await engine.exportJsonEntityReport()
            var fetched = 0
            while try await engine.fetchNext(handle) != nil {
                fetched += 1
            }
            try await engine.closeExportReport(handle)
            #expect(fetched == lines.count)
            let csv = try await engine.exportCsvEntityReport(csvColumnList: "*")
            #expect(try await engine.fetchNext(csv)?.contains("RESOLVED_ENTITY_ID") == true)
            try await engine.closeExportReport(csv)

            do {
                _ = try await engine.getEntity(999_999)
                Issue.record("expected notFound")
            } catch SzError.notFound {
            }
        }

        @Test("test_workers: calls run on the same long-lived worker threads")
        func test_workers() async throws {
            let fixture = try EngineFixture(loadTruthset: true)
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 2)
            let threads = ThreadSet()
            let caller = currentThreadToken()
            for round in 0..<3 {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for _ in 0..<100 {
                        group.addTask {
                            try await engine.perform { engine in
                                threads.insertCurrent()
                                _ = try engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001")
                            }
                        }
                    }
                    try await group.waitForAll()
                }
                if round < 2 {
                    try await Task.sleep(for: .milliseconds(200))
                }
            }
            let used = threads.all
            #expect(used.count == 2, "\(used.count) threads touched the engine")
            #expect(!used.contains(caller))
        }

        @Test("test_cancellation: a call cancelled before a worker starts it never reaches the engine")
        func test_cancellation() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 1)
            let reached = Counter()
            let gate = Gate()
            let blocker = Task { try await engine.perform { _ in gate.hold() } }
            await gate.waitUntilHeld()

            let waiting = Task { try await engine.perform { _ in reached.increment() } }
            try await eventually { engine.workers.pendingCount == 1 }
            waiting.cancel()
            await #expect(throws: CancellationError.self) { try await waiting.value }

            // A task cancelled before it calls the engine.
            let early = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await engine.perform { _ in reached.increment() }
            }
            await #expect(throws: CancellationError.self) { try await early.value }

            gate.open()
            try await blocker.value
            try await engine.perform { _ in }
            #expect(reached.count == 0)
        }

        @Test("test_cancellation: a call a worker has started runs to completion and commits")
        func test_cancellationAfterStart() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 1)
            let gate = Gate()
            let started = Task {
                try await engine.perform { engine in
                    gate.hold()
                    return try engine.addRecord(
                        dataSourceCode: "CUSTOMERS", recordID: "C1", recordDefinition: person("Cora Diaz"),
                        flags: .withInfo)
                }
            }
            await gate.waitUntilHeld()
            started.cancel()
            gate.open()
            let info = try await started.value
            #expect(info?.contains("C1") == true)
            #expect(try fixture.engine.getRecord(dataSourceCode: "CUSTOMERS", recordID: "C1").contains("C1"))
        }

        @Test("test_destroy: queued calls fail, the running call finishes, nothing reaches the engine after")
        func test_destroy() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 1)
            let second = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 1)
            let reached = Counter()
            let gate = Gate()
            let running = Task {
                try await engine.perform { engine in
                    gate.hold()
                    return try engine.getStats()
                }
            }
            await gate.waitUntilHeld()
            let queued = (0..<3).map { _ in
                Task { try await engine.perform { _ in reached.increment() } }
            }
            try await eventually { engine.workers.pendingCount == 3 }

            let environment = fixture.environment
            let destroyed = Task.detached { environment.destroy() }
            try await eventually { engine.isShutDown && second.isShutDown }
            for task in queued {
                await #expect(throws: SzError.self) { try await task.value }
            }
            #expect(!environment.isDestroyed, "native teardown waits for the running call")
            gate.open()
            #expect(try await running.value.contains("workload"))
            await destroyed.value
            #expect(environment.isDestroyed)

            do {
                try await engine.perform { _ in reached.increment() }
                Issue.record("expected environmentDestroyed")
            } catch SzError.environmentDestroyed {
            }
            #expect(reached.count == 0)

            // An SzAsyncEngine created after destroy is shut down at once.
            let late = SzAsyncEngine(fixture.engine)
            #expect(late.isShutDown)
        }

        @Test("test_shutdown: explicit, idempotent, from a worker, and on release")
        func test_shutdown() async throws {
            let fixture = try EngineFixture()
            let engine = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 2)
            #expect(!engine.isShutDown)
            engine.shutdown()
            engine.shutdown()
            #expect(engine.isShutDown)
            do {
                try await engine.perform { _ in }
                Issue.record("expected the shutdown error")
            } catch SzError.general {
            }

            // A worker shutting down its own pool detaches itself.
            let selfStopping = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 2)
            try await selfStopping.perform { [selfStopping] _ in selfStopping.shutdown() }
            #expect(selfStopping.isShutDown)

            // Releasing an SzAsyncEngine joins its workers.
            let pool: EngineWorkerPool
            do {
                let released = SzAsyncEngine(fixture.engine, maxConcurrentCalls: 1)
                pool = released.workers
                _ = try await released.getStats()
            }
            #expect(pool.isShutDown)
            #expect(try fixture.engine.getStats().contains("workload"))
        }
    }
}
