// swift-tools-version:6.0
import PackageDescription

// Swift 5 language mode on purpose. The Carbon hot key API hands its callback
// a C function pointer with no context, so the only way to find the object
// that registered it is a static table, and strict concurrency will not have
// that. Nothing here is threaded: everything runs on the main run loop.
let package = Package(
    name: "capturezone",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "capturezone",
            path: "Sources/capturezone",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
