// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacAPITester",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MacAPITester",
            targets: ["MacAPITester"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacAPITester",
            path: "Sources/MacAPITester",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("mysqlclient"),
            ]
        ),
        .testTarget(
            name: "MacAPITesterTests",
            dependencies: ["MacAPITester"],
            path: "Tests/MacAPITesterTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
