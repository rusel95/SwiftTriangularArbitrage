// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "SwiftTriangularArbitrage",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/nerzh/telegram-vapor-bot", .upToNextMajor(from: "1.0.2")),
        .package(url: "https://github.com/BrettRToomey/Jobs.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "telegram-vapor-bot", package: "telegram-vapor-bot"),
                .product(name: "Jobs", package: "Jobs"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    ]
)
