// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InMyFace",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "InMyFace",
            path: "Sources/InMyFace",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                // Debug builds get a Developer menu with overlay previews;
                // release builds (what we distribute) don't.
                .define("DEVELOPER", .when(configuration: .debug))
            ]
        )
    ]
)
