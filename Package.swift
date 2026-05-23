// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ssap",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "ssap",
            dependencies: [
                "Yams",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ssap",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Resources/Info.plist"]),
            ]
        ),
    ]
)
