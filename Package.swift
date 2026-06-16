// swift-tools-version:5.9
import PackageDescription

// SPM manifest so the app can be edited, built, and run (⌘R) directly in Xcode.
// NOTE: This compiles/runs the Swift code for development. It does NOT reproduce
// the full .app bundle that build.sh creates (universal binary, the dlopen'd
// MediaRemoteAdapter.framework + perl adapter, the .icns, and codesigning).
// For a distributable bundle, use ./build.sh — Now Playing media features rely on
// the bundled perl adapter and won't work from a plain `swift run`/Xcode run.
let package = Package(
    name: "StupidNotch",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StupidNotch",
            path: "Sources"
        )
    ]
)
