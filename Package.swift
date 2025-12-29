// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ptp-tool",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        // ライブラリターゲット（テスト可能なコア機能）
        .target(
            name: "PTPToolCore",
            path: "Sources/Core"
        ),
        // 実行ファイルターゲット
        .executableTarget(
            name: "ptp-tool",
            dependencies: [
                "PTPToolCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CLI",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        // テストターゲット
        .testTarget(
            name: "PTPToolTests",
            dependencies: ["PTPToolCore"],
            path: "Tests"
        ),
    ]
)
