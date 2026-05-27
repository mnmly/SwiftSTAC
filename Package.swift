// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftSTAC",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "SwiftSTAC", targets: ["SwiftSTAC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "SwiftSTAC",
            path: "Sources/SwiftSTAC"
        ),
        .testTarget(
            name: "SwiftSTACTests",
            dependencies: ["SwiftSTAC"],
            path: "Tests/SwiftSTACTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
