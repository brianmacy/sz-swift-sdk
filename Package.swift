// swift-tools-version: 6.0
//
// SenzingSDK: an unofficial, idiomatic Swift SDK over the Senzing V4 C API.
//
// The package binds the C headers and the `libSz` shared library of an
// INSTALLED Senzing runtime. Nothing from the runtime is vendored here. The
// runtime is located at manifest-evaluation time, in this order:
//
//   1. `SENZING_DIR`: the runtime's `er` directory (the one that contains
//      `lib/`, `sdk/c/` and `resources/`).
//   2. The Homebrew cask locations (Apple silicon, then Intel), including the
//      layout of the older unofficial Homebrew tap.
//   3. The Linux package location, `/opt/senzing/er`.
//
// The native library's directory is embedded as an rpath, so programs and
// tests run without `DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH`.

import Foundation
import PackageDescription

/// Returns the Senzing runtime's `er` directory.
func senzingRuntimeDirectory() -> String {
    let environment = ProcessInfo.processInfo.environment
    if let explicit = environment["SENZING_DIR"], !explicit.isEmpty {
        return explicit
    }
    let candidates = [
        "/opt/homebrew/opt/senzing/er",
        "/usr/local/opt/senzing/er",
        "/opt/homebrew/opt/senzing/runtime/er",
        "/usr/local/opt/senzing/runtime/er",
        "/opt/senzing/er",
    ]
    let found = candidates.first {
        FileManager.default.fileExists(atPath: "\($0)/sdk/c/libSz.h")
    }
    return found ?? "/opt/senzing/er"
}

let senzingDirectory = senzingRuntimeDirectory()
let senzingHeaders = "\(senzingDirectory)/sdk/c"
let senzingLibraries = "\(senzingDirectory)/lib"

let nativePlatforms: [Platform] = [.macOS, .linux]

let senzingSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(senzingHeaders)"], .when(platforms: nativePlatforms))
]

let senzingLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(
        ["-L\(senzingLibraries)", "-Xlinker", "-rpath", "-Xlinker", senzingLibraries],
        .when(platforms: nativePlatforms)
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
            path: "Sources/CSenzing"
        ),
        .target(
            name: "SenzingSDK",
            dependencies: ["CSenzing"],
            swiftSettings: senzingSwiftSettings,
            linkerSettings: senzingLinkerSettings
        ),
        .target(
            name: "SenzingTestSupport",
            dependencies: ["SenzingSDK"],
            path: "Tests/SenzingTestSupport",
            exclude: ["Resources/truthset/README.md"],
            resources: [.copy("Resources/truthset")],
            swiftSettings: senzingSwiftSettings
        ),
        .testTarget(
            name: "SenzingSDKTests",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            swiftSettings: senzingSwiftSettings
        ),
        .executableTarget(
            name: "example_load_truthset",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/LoadTruthset",
            swiftSettings: senzingSwiftSettings
        ),
        .executableTarget(
            name: "example_search",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/Search",
            swiftSettings: senzingSwiftSettings
        ),
        .executableTarget(
            name: "example_why",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/Why",
            swiftSettings: senzingSwiftSettings
        ),
        .executableTarget(
            name: "example_async_engine",
            dependencies: ["SenzingSDK", "SenzingTestSupport"],
            path: "Examples/AsyncEngine",
            swiftSettings: senzingSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
