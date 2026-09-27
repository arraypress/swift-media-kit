// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-media-kit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1),
    ],
    products: [
        .library(name: "MediaMetadata", targets: ["MediaMetadata"]),
        .library(name: "AudioTimbre", targets: ["AudioTimbre"]),
        .library(name: "ImagePalette", targets: ["ImagePalette"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-codec-kit.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "MediaMetadata", dependencies: [.product(name: "CodecKit", package: "swift-codec-kit")],
            resources: [.process("Localizable.xcstrings")], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AudioTimbre", resources: [.process("Localizable.xcstrings")], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "ImagePalette", resources: [.process("Localizable.xcstrings")], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "MediaMetadataTests", dependencies: ["MediaMetadata"]),
        .testTarget(name: "AudioTimbreTests", dependencies: ["AudioTimbre"]),
        .testTarget(name: "ImagePaletteTests", dependencies: ["ImagePalette"]),
    ]
)
