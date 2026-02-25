// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrangeBiliShared",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "OrangeBiliCore", targets: ["OrangeBiliCore"]),
        .library(name: "OrangeBiliUI", targets: ["OrangeBiliUI"])
    ],
    targets: [
        .target(
            name: "OrangeBiliCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "OrangeBiliUI",
            dependencies: ["OrangeBiliCore"]
        )
    ]
)
