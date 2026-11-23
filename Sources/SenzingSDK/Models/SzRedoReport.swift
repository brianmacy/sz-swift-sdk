/// The outcome of ``SzAsyncEngine/processRedoRecords()``.
public struct SzRedoReport: Sendable {
    /// One redo record that failed to process, with its error.
    public struct Failure: Sendable {
        /// The redo record, already removed from the engine's redo queue.
        public let redoRecord: String
        /// Why processing it failed.
        public let error: SzError
    }

    /// How many redo records were processed.
    public var processed = 0
    /// The redo records that failed, in the order they were fetched.
    public var failed: [Failure] = []

    /// Fetches redo records with `next` and processes each with `process`
    /// until `next` returns `nil`, collecting the failures.
    static func drain(
        next: () throws(SzError) -> String?,
        process: (String) throws(SzError) -> Void
    ) throws(SzError) -> SzRedoReport {
        var report = SzRedoReport()
        while let redo = try next() {
            do {
                try process(redo)
                report.processed += 1
            } catch {
                report.failed.append(Failure(redoRecord: redo, error: error))
            }
        }
        return report
    }
}
