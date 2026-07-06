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
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
