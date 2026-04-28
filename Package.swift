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
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.72.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CMySQL",
            pkgConfig: "mysqlclient",
            providers: [
                .brew(["mysql@8.0", "mysql-client"]),
            ]
        ),
        .executableTarget(
            name: "MacAPITester",
            dependencies: [
                "CMySQL",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
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
