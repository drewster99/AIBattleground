// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AIBattleground",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AIBattleground",
            targets: ["AIBattleground"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "AIBattleground",
            dependencies: [],
            path: "AIBattleground"),
        .testTarget(
            name: "AIBattlegroundTests",
            dependencies: [
                "AIBattleground",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "AIBattlegroundTests")
    ]
) 