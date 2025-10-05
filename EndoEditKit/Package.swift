// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EndoEditKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "EndoEditCore",
            targets: ["EndoEditCore"]
        ),
        .library(
            name: "EndoEditUI",
            targets: ["EndoEditUI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "EndoEditCore",
            dependencies: [],
            path: "Sources/EndoEditCore",
            resources: []
        ),
        .target(
            name: "EndoEditUI",
            dependencies: ["EndoEditCore"],
            path: "Sources/EndoEditUI",
            resources: []
        ),
        .testTarget(
            name: "EndoEditCoreTests",
            dependencies: ["EndoEditCore"],
            path: "Tests/EndoEditCoreTests"
        )
    ]
)
