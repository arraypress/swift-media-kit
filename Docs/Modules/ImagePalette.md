# Swift Image Palette

The colours of an image, with how much of it each one covers.

```swift
import ImagePalette

let palette = try PaletteExtractor.extract(from: url, options: PaletteOptions(count: 6))
for swatch in palette {
    print(swatch.hex, String(format: "%.1f%%", swatch.share * 100), swatch.isNeutral ? "neutral" : "colour")
}
// #141E50  70.2%
// #F06E5A  19.9%
// #FAF0DC   9.9%
```

## Features

- 📊 **Shares, not just colours** — every swatch carries the fraction of the picture nearest it; a palette's shares sum to 1
- 👁️ **Clustered in OKLab** — k-means in a perceptual space, so "different" means different to the eye: a navy and a black separate, two greens the eye cannot tell apart merge
- 🎯 **Deterministic** — k-means++ seeded from a fixed generator; the same picture gives the same palette on every run and every machine
- 🧹 **Merges and drops** — colours within a just-noticeable distance become one; slivers under 1 % hand their pixels to the nearest survivor
- 🫥 **Transparency respected** — clear pixels are not colours; semi-transparent ones are un-premultiplied first
- 🖼️ **Any image ImageIO reads** — PNG, JPEG, HEIC, TIFF, GIF, WebP, RAW, a PDF's first page — drawn down to 256 px on the long side before sampling, so a 50-megapixel photo takes the same few milliseconds as a thumbnail
- 🎨 **Every swatch in four forms** — `#RRGGBB`, `rgb()`, `hsl()`, and OKLab lightness / chroma / hue, with `isNeutral`
- 📦 **Zero dependencies** — CoreGraphics and ImageIO; no UI framework, every Apple platform, headless

## Measured

Synthetic pictures with known blocks: a 70 / 20 / 10 image comes back as three swatches at 70.2 / 19.9 / 9.9 %, the exact colours; two greens two units apart merge into one; a one-pixel column of red is dropped and its share absorbed; clear pixels contribute nothing. Tests pin all of it.

## Requirements

macOS 14+ / iOS 17+ / tvOS 17+ / watchOS 10+ / visionOS 1+, Swift 6.

## License

MIT — see LICENSE.
