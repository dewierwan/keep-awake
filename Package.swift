// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeepAwake",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic with no system calls, so it can be tested anywhere.
        .target(name: "KeepAwakeCore"),
        .executableTarget(
            name: "KeepAwake",
            dependencies: ["KeepAwakeCore"]
        ),
        // The unit tests, run with `swift run Checks`.
        .executableTarget(
            name: "Checks",
            dependencies: ["KeepAwakeCore"]
        ),
    ]
)
