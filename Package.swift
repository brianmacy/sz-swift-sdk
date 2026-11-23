// swift-tools-version: 6.0
//
// SenzingSDK: an unofficial, idiomatic Swift SDK over the Senzing V4 C API.
//
// The package binds the C headers and the `libSz` shared library of an
// INSTALLED Senzing runtime; nothing from the runtime is vendored here. SwiftPM
// finds them through pkg-config: a `senzing.pc` file, which
// `tools/senzing-pkgconfig.sh` writes for an installed runtime. No unsafe build
// flags are involved, so the package works as a version-pinned dependency.
//
// `libSz` is loaded through @rpath (macOS) or the library path (Linux): an app
// bundles it or adds an rpath to the runtime's `lib` directory; see README.md.
// This repository's own tests and examples embed that rpath themselves.

import Foundation
import PackageDescription

/// The Senzing runtime's `lib` directory, for the rpath of this repository's
/// tests and examples: the `libdir` of the `senzing.pc` SwiftPM would find,
/// else `$SENZING_DIR/lib`, else the platform default.
func senzingLibraryDirectory() -> String {
    let environment = ProcessInfo.processInfo.environment
    let searchPath =
        (environment["PKG_CONFIG_PATH"] ?? "").split(separator: ":").map(String.init) + [
            "/opt/homebrew/lib/pkgconfig", "/usr/local/lib/pkgconfig", "/usr/local/share/pkgconfig",
            "/usr/lib/pkgconfig", "/usr/share/pkgconfig",
        ]
    for directory in searchPath {
        guard let text = try? String(contentsOfFile: "\(directory)/senzing.pc", encoding: .utf8) else {
            continue
        }
        for line in text.split(separator: "\n") where line.hasPrefix("libdir=") {
            return String(line.dropFirst("libdir=".count))
        }
    }
    if let explicit = environment["SENZING_DIR"], !explicit.isEmpty {
        return "\(explicit)/lib"
    }
    return FileManager.default.fileExists(atPath: "/opt/homebrew/opt/senzing/er/lib")
        ? "/opt/homebrew/opt/senzing/er/lib" : "/opt/senzing/er/lib"
}

/// The rpath for this repository's tests and examples. Unsafe flags are allowed
/// here because these targets are not part of the `SenzingSDK` product.
let runtimeSearchPath: [LinkerSetting] = [
    .unsafeFlags(
        ["-Xlinker", "-rpath", "-Xlinker", senzingLibraryDirectory()],
        .when(platforms: [.macOS, .linux])
    )
]

let package = Package(
    name: "SenzingSDK",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "SenzingSDK", targets: ["SenzingSDK"])
    ],
    targets: [
        // The module map over the installed Senzing C headers.
        .systemLibrary(
            name: "CSenzing",
            path: "Sources/CSenzing",
            pkgConfig: "senzing"
        ),
        .target(
            name: "SenzingSDK",
            dependencies: ["CSenzing"]
        ),
        .target(
            name: "SenzingTestSupport",
            dependencies: ["SenzingSDK"],
            path: "Tests/SenzingTestSupport",
            exclude: ["Resources/truthset/README.md"],
            resources: [.copy("Resources/truthset")]
        ),
        .testTarget(
            name: "SenzingSDKTests",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            linkerSettings: runtimeSearchPath
        ),
        .executableTarget(
            name: "example_load_truthset",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/LoadTruthset",
            linkerSettings: runtimeSearchPath
        ),
        .executableTarget(
            name: "example_search",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/Search",
            linkerSettings: runtimeSearchPath
        ),
        .executableTarget(
            name: "example_why",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/Why",
            linkerSettings: runtimeSearchPath
        ),
        .executableTarget(
            name: "example_async_engine",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/AsyncEngine",
            linkerSettings: runtimeSearchPath
        ),
        .executableTarget(
            name: "example_logging",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/Logging",
            linkerSettings: runtimeSearchPath
        ),
    ],
    swiftLanguageModes: [.v6]
)
