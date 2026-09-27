# Swift Media Kit

Media files, as measured facts: everything macOS knows about a file's metadata, what a sound sounds like, and the colours of an image.

## Modules

Each module is its own library product: depend on the package, then only on the products you use.

| Module | What it is |
|---|---|
| [`MediaMetadata`](Docs/Modules/MediaMetadata.md) | Everything macOS knows about a media file, read once, typed and namespaced. |
| [`AudioTimbre`](Docs/Modules/AudioTimbre.md) | What a sound sounds like, as measured facts: brightness, texture, pitch, envelope, level. |
| [`ImagePalette`](Docs/Modules/ImagePalette.md) | The colours of an image, with how much of it each one covers. |

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-media-kit.git", from: "0.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "MediaMetadata", package: "swift-media-kit"),
    ]),
]
```

## Requirements

- macOS 14+ (the media modules also build for iOS 17+)
- Swift 6.2+ (Swift 6 language mode)

## History

The modules were separate packages until 27 September 2026 (`swift-media-metadata`, `swift-audio-timbre`, `swift-image-palette`); their commits are kept here, so `git log --follow` traces any file back through them.

## Licence

MIT — see [LICENSE](LICENSE).
