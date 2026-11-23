import Foundation
import SenzingSDK
import SenzingTestSupport
import Testing

@Suite("SzError taxonomy")
struct SzErrorTests {
    @Test("test_hierarchy mirrors the C# exception tree")
    func test_hierarchy() {
        #expect(SzErrorKind.notFound.isKind(of: .badInput))
        #expect(SzErrorKind.notFound.isKind(of: .general))
        #expect(SzErrorKind.unknownDataSource.parent == .badInput)
        #expect(SzErrorKind.databaseTransient.isKind(of: .retryable))
        #expect(SzErrorKind.retryTimeoutExceeded.isKind(of: .retryable))
        #expect(SzErrorKind.license.isKind(of: .unrecoverable))
        #expect(SzErrorKind.configuration.parent == .general)
        #expect(SzErrorKind.general.parent == nil)
        #expect(!SzErrorKind.badInput.isKind(of: .notFound))
        #expect(!SzErrorKind.environmentDestroyed.isKind(of: .general))
        #expect(!SzErrorKind.json.isKind(of: .general))
    }

    @Test("test_every engine kind descends from general")
    func test_engineKindsDescendFromGeneral() {
        let sdkOnly: Set<SzErrorKind> = [.environmentDestroyed, .json]
        for kind in SzErrorKind.allCases where !sdkOnly.contains(kind) {
            #expect(kind.isKind(of: .general), "\(kind)")
        }
    }

    @Test("test_error codes map to kinds per szerrors.json")
    func test_errorCodeMapping() {
        // Codes and classes observed from the real engine (see SzEngineReadTests).
        #expect(SzErrorKind.forErrorCode(33) == .notFound)
        #expect(SzErrorKind.forErrorCode(37) == .notFound)
        #expect(SzErrorKind.forErrorCode(88) == .badInput)
        #expect(SzErrorKind.forErrorCode(2207) == .unknownDataSource)
        #expect(SzErrorKind.forErrorCode(7245) == .replaceConflict)
        #expect(SzErrorKind.forErrorCode(7221) == .configuration)
        #expect(SzErrorKind.forErrorCode(-1) == .general)
        #expect(SzErrorKind.forErrorCode(999_999) == .general)
    }

    @Test("test_generated table matches the installed szerrors.json")
    func test_tableMatchesInstalledJSON() throws {
        let url = SenzingRuntime.current.erDirectory.appendingPathComponent("sdk/szerrors.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: String]]
        let entries = try #require(object)
        #expect(!entries.isEmpty)
        for (code, entry) in entries {
            let kind = SzErrorKind.forErrorCode(try #require(Int64(code)))
            #expect(kind.rawValue == entry["class"], "code \(code)")
        }
    }

    @Test("test_SzError properties, description and patterns")
    func test_errorValues() {
        let error = SzError(errorCode: 33, message: "Unknown record")
        #expect(error.kind == .notFound)
        #expect(error.errorCode == 33)
        #expect(error.message == "Unknown record")
        #expect(error.description == "SzNotFoundError(33): Unknown record")
        #expect(error.errorDescription == error.description)
        #expect(!error.isRetryable)
        #expect(!error.isUnrecoverable)
        #expect(SzError.badInput ~= error)
        #expect(!(SzError.retryable ~= error))

        let plain = SzError(.license, message: "expired")
        #expect(plain.errorCode == nil)
        #expect(plain.description == "SzLicenseError: expired")
        #expect(plain.isUnrecoverable)
        #expect(SzError(.databaseTransient, message: "x").isRetryable)

        let anyError: any Error = error
        #expect(SzError.notFound ~= anyError)
        #expect(!(SzError.notFound ~= (CocoaError(.fileNoSuchFile) as any Error)))
    }

    @Test("test_catch clauses match kind patterns through the hierarchy")
    func test_catchPatterns() {
        func fail(_ kind: SzErrorKind) throws(SzError) {
            throw SzError(kind, message: "test")
        }
        var caught: [String] = []
        for kind in [SzErrorKind.notFound, .databaseConnectionLost, .unhandled, .environmentDestroyed] {
            do {
                try fail(kind)
            } catch SzError.badInput {
                caught.append("badInput")
            } catch SzError.retryable {
                caught.append("retryable")
            } catch SzError.unrecoverable {
                caught.append("unrecoverable")
            } catch {
                caught.append("other")
            }
        }
        #expect(caught == ["badInput", "retryable", "unrecoverable", "other"])
    }

    @Test("test_every kind pattern names its kind")
    func test_kindPatternConstants() {
        let patterns: [SzErrorKind] = [
            SzError.general, SzError.badInput, SzError.notFound, SzError.unknownDataSource,
            SzError.configuration, SzError.replaceConflict, SzError.retryable,
            SzError.databaseConnectionLost, SzError.databaseTransient, SzError.retryTimeoutExceeded,
            SzError.unrecoverable, SzError.database, SzError.license, SzError.notInitialized,
            SzError.unhandled, SzError.environmentDestroyed, SzError.json,
        ]
        #expect(Set(patterns) == Set(SzErrorKind.allCases))
    }
}
