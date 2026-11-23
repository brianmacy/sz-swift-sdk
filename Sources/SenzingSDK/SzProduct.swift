/// Version and license information, mirroring the C# `SzProduct` interface.
public protocol SzProduct: Sendable {
    /// Returns the license details as JSON.
    func getLicense() throws(SzError) -> String

    /// Returns the version and build details as JSON.
    func getVersion() throws(SzError) -> String
}

extension SzProduct {
    /// Returns the version details decoded into ``SzVersionInfo``.
    public func getVersion<T: Decodable>(as type: T.Type) throws(SzError) -> T {
        try SzJSON.decode(type, from: getVersion())
    }

    /// Returns the license details decoded into ``SzLicenseInfo``.
    public func getLicense<T: Decodable>(as type: T.Type) throws(SzError) -> T {
        try SzJSON.decode(type, from: getLicense())
    }
}
