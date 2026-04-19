// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSwitch",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "OpenSwitch",
            path: "Sources/OpenSwitch"
        ),
        .testTarget(
            name: "OpenSwitchTests",
            dependencies: ["OpenSwitch"],
            path: "Tests/OpenSwitchTests"
        ),
    ]
)
