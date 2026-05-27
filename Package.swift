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
