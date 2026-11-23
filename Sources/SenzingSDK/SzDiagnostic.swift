/// Repository diagnostics, mirroring the C# `SzDiagnostic` interface.
public protocol SzDiagnostic: Sendable {
    /// Returns details about the repository's data stores as JSON.
    func getRepositoryInfo() throws(SzError) -> String

    /// Runs a write/read benchmark for `secondsToRun` seconds and returns the results as JSON.
    func checkRepositoryPerformance(secondsToRun: Int) throws(SzError) -> String

    /// Deletes all entity and record data from the repository.
    ///
    /// - Warning: Irreversible. Intended for tests and demonstrations.
    func purgeRepository() throws(SzError)

    /// Returns the details of a feature as JSON (an unsupported, undocumented
    /// native function, kept for parity with the C# SDK).
    func getFeature(featureID: Int64) throws(SzError) -> String
}
