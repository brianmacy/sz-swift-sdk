import Dispatch
import Foundation

/// An actor that exposes ``SzEngine`` to Swift concurrency.
///
/// Native engine calls block their thread, so they must not run on the main
/// actor or on the cooperative thread pool. `SzAsyncEngine` runs each call on
/// a dedicated concurrent dispatch queue and suspends the caller until it
/// finishes. The actor bounds how many calls run at once
/// (``maxConcurrentCalls``) and queues the rest in order, so firing thousands
/// of tasks does not create thousands of threads. Calls run concurrently up
/// to that bound: the native engine is thread-safe.
///
/// ```swift
/// let engine = SzAsyncEngine(try environment.getEngine())
/// try await engine.addRecord(dataSourceCode: "CUSTOMERS", recordID: "1001", recordDefinition: json)
/// let entity = try await engine.getEntity(dataSourceCode: "CUSTOMERS", recordID: "1001", as: SzEntityResponse.self)
/// ```
///
/// Any other engine method runs through ``perform(_:)``. A native call cannot
/// be interrupted, so task cancellation takes effect only before a call starts.
public actor SzAsyncEngine {
    /// The wrapped synchronous engine.
    public nonisolated let engine: any SzEngine
    /// The maximum number of native calls that run at the same time.
    public nonisolated let maxConcurrentCalls: Int

    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private nonisolated let queue = DispatchQueue(
        label: "senzing.sz-swift-sdk.async-engine",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Wraps an engine.
    ///
    /// - Parameters:
    ///   - engine: The engine to run calls on.
    ///   - maxConcurrentCalls: The bound on concurrent native calls; defaults
    ///     to the number of active processors.
    public init(_ engine: any SzEngine, maxConcurrentCalls: Int? = nil) {
        self.engine = engine
        self.maxConcurrentCalls = max(1, maxConcurrentCalls ?? ProcessInfo.processInfo.activeProcessorCount)
    }

    /// Runs `operation` with the engine on the engine queue and returns its result.
    ///
    /// The operation's error type is preserved: annotate the closure with
    /// `throws(SzError)` to keep typed errors, or let it infer `any Error`.
    public func perform<T: Sendable, E: Error>(
        _ operation: @escaping @Sendable (any SzEngine) throws(E) -> T
    ) async throws(E) -> T {
        await acquireSlot()
        defer { releaseSlot() }
        let engine = self.engine
        let result: Result<T, E> = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Result { () throws(E) -> T in try operation(engine) })
            }
        }
        return try result.get()
    }

    private func acquireSlot() async {
        if running < maxConcurrentCalls {
            running += 1
            return
        }
        // The releasing call hands its slot over, so `running` is unchanged.
        await withCheckedContinuation { waiting.append($0) }
    }

    private func releaseSlot() {
        if waiting.isEmpty {
            running -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }

    // MARK: Records

    /// Async ``SzEngine/addRecord(dataSourceCode:recordID:recordDefinition:flags:)``.
    @discardableResult
    public func addRecord(
        dataSourceCode: String,
        recordID: String,
        recordDefinition: String,
        flags: SzFlags = .addRecordDefaultFlags
    ) async throws(SzError) -> String? {
        try await perform { (engine) throws(SzError) in
            try engine.addRecord(
                dataSourceCode: dataSourceCode,
                recordID: recordID,
                recordDefinition: recordDefinition,
                flags: flags
            )
        }
    }

    /// Async ``SzEngine/addRecord(dataSourceCode:recordID:record:flags:)`` for an `Encodable` record.
    @discardableResult
    public func addRecord<Record: Encodable & Sendable>(
        dataSourceCode: String,
        recordID: String,
        record: Record,
        flags: SzFlags = .addRecordDefaultFlags
    ) async throws(SzError) -> String? {
        try await perform { (engine) throws(SzError) in
            try engine.addRecord(dataSourceCode: dataSourceCode, recordID: recordID, record: record, flags: flags)
        }
    }

    /// Async ``SzEngine/addRecord(dataSourceCode:recordID:recordDefinition:flags:as:)``.
    public func addRecord<T: Decodable & Sendable>(
        dataSourceCode: String,
        recordID: String,
        recordDefinition: String,
        flags: SzFlags = .addRecordDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in
            try engine.addRecord(
                dataSourceCode: dataSourceCode,
                recordID: recordID,
                recordDefinition: recordDefinition,
                flags: flags,
                as: type
            )
        }
    }

    /// Async ``SzEngine/deleteRecord(dataSourceCode:recordID:flags:)``.
    @discardableResult
    public func deleteRecord(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .deleteRecordDefaultFlags
    ) async throws(SzError) -> String? {
        try await perform { (engine) throws(SzError) in
            try engine.deleteRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
        }
    }

    /// Async ``SzEngine/getRecord(dataSourceCode:recordID:flags:)``.
    public func getRecord(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .recordDefaultFlags
    ) async throws(SzError) -> String {
        try await perform { (engine) throws(SzError) in
            try engine.getRecord(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
        }
    }

    // MARK: Entities

    /// Async ``SzEngine/getEntity(_:flags:)``.
    public func getEntity(_ entityID: Int64, flags: SzFlags = .entityDefaultFlags) async throws(SzError) -> String {
        try await perform { (engine) throws(SzError) in try engine.getEntity(entityID, flags: flags) }
    }

    /// Async ``SzEngine/getEntity(_:flags:as:)``.
    public func getEntity<T: Decodable & Sendable>(
        _ entityID: Int64,
        flags: SzFlags = .entityDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in try engine.getEntity(entityID, flags: flags, as: type) }
    }

    /// Async ``SzEngine/getEntity(dataSourceCode:recordID:flags:)``.
    public func getEntity(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .entityDefaultFlags
    ) async throws(SzError) -> String {
        try await perform { (engine) throws(SzError) in
            try engine.getEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags)
        }
    }

    /// Async ``SzEngine/getEntity(dataSourceCode:recordID:flags:as:)``.
    public func getEntity<T: Decodable & Sendable>(
        dataSourceCode: String,
        recordID: String,
        flags: SzFlags = .entityDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in
            try engine.getEntity(dataSourceCode: dataSourceCode, recordID: recordID, flags: flags, as: type)
        }
    }

    // MARK: Search and why

    /// Async ``SzEngine/searchByAttributes(_:searchProfile:flags:)``.
    public func searchByAttributes(
        _ attributes: String,
        searchProfile: String? = nil,
        flags: SzFlags = .searchByAttributesDefaultFlags
    ) async throws(SzError) -> String {
        try await perform { (engine) throws(SzError) in
            try engine.searchByAttributes(attributes, searchProfile: searchProfile, flags: flags)
        }
    }

    /// Async ``SzEngine/searchByAttributes(_:searchProfile:flags:as:)``.
    public func searchByAttributes<T: Decodable & Sendable>(
        _ attributes: String,
        searchProfile: String? = nil,
        flags: SzFlags = .searchByAttributesDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in
            try engine.searchByAttributes(attributes, searchProfile: searchProfile, flags: flags, as: type)
        }
    }

    /// Async ``SzEngine/whyEntities(entityID1:entityID2:flags:as:)``.
    public func whyEntities<T: Decodable & Sendable>(
        entityID1: Int64,
        entityID2: Int64,
        flags: SzFlags = .whyEntitiesDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in
            try engine.whyEntities(entityID1: entityID1, entityID2: entityID2, flags: flags, as: type)
        }
    }

    /// Async ``SzEngine/whyRecords(dataSourceCode1:recordID1:dataSourceCode2:recordID2:flags:as:)``.
    public func whyRecords<T: Decodable & Sendable>(
        dataSourceCode1: String,
        recordID1: String,
        dataSourceCode2: String,
        recordID2: String,
        flags: SzFlags = .whyRecordsDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> T {
        try await perform { (engine) throws(SzError) in
            try engine.whyRecords(
                dataSourceCode1: dataSourceCode1,
                recordID1: recordID1,
                dataSourceCode2: dataSourceCode2,
                recordID2: recordID2,
                flags: flags,
                as: type
            )
        }
    }

    // MARK: Export and redo

    /// Async ``SzEngine/exportJsonEntityReport(flags:as:)``.
    public func exportJsonEntityReport<T: Decodable & Sendable>(
        flags: SzFlags = .exportDefaultFlags,
        as type: T.Type
    ) async throws(SzError) -> [T] {
        try await perform { (engine) throws(SzError) in try engine.exportJsonEntityReport(flags: flags, as: type) }
    }

    /// Processes pending redo records until none remain; returns how many ran.
    @discardableResult
    public func processRedoRecords() async throws(SzError) -> Int {
        try await perform { (engine) throws(SzError) -> Int in
            var processed = 0
            while let redo = try engine.getRedoRecord() {
                try engine.processRedoRecord(redo, flags: [])
                processed += 1
            }
            return processed
        }
    }
}
