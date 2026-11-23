#if canImport(Sz)
import Sz
#else
import CSenzing
#endif

/// The ``SzProduct`` over the native engine, mirroring the C# `SzCoreProduct`.
public final class SzCoreProduct: SzProduct {
    let state: EnvironmentState

    init(state: EnvironmentState) {
        self.state = state
    }

    public func getLicense() throws(SzError) -> String {
        // The native function returns a buffer owned by the engine: not freed here.
        try state.execute { () throws(SzError) -> String in
            try Native.borrowedString(SzProduct_getLicense(), .product)
        }
    }

    public func getVersion() throws(SzError) -> String {
        // The native function returns a buffer owned by the engine: not freed here.
        try state.execute { () throws(SzError) -> String in
            try Native.borrowedString(SzProduct_getVersion(), .product)
        }
    }
}
