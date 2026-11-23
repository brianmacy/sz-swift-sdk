#if canImport(Sz)
import Sz
#else
import CSenzing
#endif

/// The ``SzDiagnostic`` over the native engine, mirroring the C# `SzCoreDiagnostic`.
public final class SzCoreDiagnostic: SzDiagnostic {
    let state: EnvironmentState

    init(state: EnvironmentState) {
        self.state = state
    }

    public func getRepositoryInfo() throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            let result = SzDiagnostic_getRepositoryInfo_helper()
            return try Native.take(result.response, result.returnCode, .diagnostic)
        }
    }

    public func checkRepositoryPerformance(secondsToRun: Int) throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            let result = SzDiagnostic_checkRepositoryPerformance_helper(Int64(secondsToRun))
            return try Native.take(result.response, result.returnCode, .diagnostic)
        }
    }

    public func purgeRepository() throws(SzError) {
        try state.execute { () throws(SzError) in
            try Native.check(SzDiagnostic_purgeRepository(), .diagnostic)
        }
    }

    public func getFeature(featureID: Int64) throws(SzError) -> String {
        try state.execute { () throws(SzError) -> String in
            let result = SzDiagnostic_getFeature_helper(featureID)
            return try Native.take(result.response, result.returnCode, .diagnostic)
        }
    }
}
