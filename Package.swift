// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-audio-timbre",
    defaultLocalization: "en",
    // Accelerate for the maths, AVFoundation only to decode a file into samples.
    // No model, no network, no vendored codecs. macOS 14 to match its sibling
    // swift-audio-forge: nothing here touches a recent framework, and the point of
    // measuring rather than classifying is that it runs anywhere.
    platforms: [
        .macOS(.v14), .iOS(.v17)
    ],
    products: [
        .library(name: "AudioTimbre", targets: ["AudioTimbre"]),
    ],
    targets: [
        .target(name: "AudioTimbre", resources: [.process("Localizable.xcstrings")], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AudioTimbreTests", dependencies: ["AudioTimbre"]),
    ]
)
