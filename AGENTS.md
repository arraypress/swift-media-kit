# Swift Media Kit

Media files, as measured facts: everything macOS knows about a file's metadata, what a sound sounds like, and the colours of an image.

- Modules `MediaMetadata`, `AudioTimbre`, `ImagePalette`, `FontSpecimen`, `ImageCompare`, each in `Sources/<Module>` with tests in `Tests/<Module>Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.
- Each module's user-facing documentation is `Docs/Modules/<Module>.md`; its last audit is `Docs/Audits/<Module>.md` — read it before auditing, and extend it rather than redo it.

## MediaMetadata — `Sources/MediaMetadata`

### Module map
- `Core/` — `MetadataReader`: classify the file, work out which readers the wanted fields need, run them
- `Enums/` — `MetadataField` (the 104 curated fields), `FieldCategory`, `FieldSource`, `MediaKind`, `ValueKind`
- `Models/` — `FileFacts` (the answer), `FieldValue`, `FieldDescriptor`, `Coordinate`
- `Errors/` — `MetadataError`
- `Extensions/` — `URL.metadata()`
- `Support/` — the readers and helpers: `FileSystemFacts` / `FileSystemRaw`, `ImageFacts` (ImageIO; an SVG's size from its own attributes or viewBox, since ImageIO cannot open one) / `ImageRaw`, `MediaFacts` (AVFoundation) / `MediaRaw`, `DocumentFacts` (PDFKit), `ChecksumFacts`, `DerivedFacts`, `ExtendedAttributes`, `FieldCatalogue`, `Lookup` (codec names), `Format`, `Numbers`, `RawValue`, `ExifDate`, `ISO6709`; `Format.clock` (`1:42`, `1:02:03`, a dash for nonsense — a player's clock, beside `Format.duration`'s file-name form)

## AudioTimbre — `Sources/AudioTimbre`

### Module map
- `Core/` — `TimbreAnalyzer` (the whole description), `SpectralFeatures`, `HarmonicAnalyzer`, `PitchEstimator`, `ChromaAnalysis`, `Envelope`, `Loudness` (peak / RMS of samples in memory), `StereoAnalysis`; the streamed pair added 22 Sep 2026 for a media gallery — `Waveform` (`peaks(fileAt:bins:)`: one normalised peak per bin from an 8 kHz mono read, capped at 20 minutes) and `Level` (`measure(fileAt:)`: the loudest sample and the count at the 16-bit rails, at the file's own rate and channels)
- `Models/` — `Timbre`, `Pitch`, `PitchClassProfile`, `StereoImage`, `AttackRejection`, `LevelReport`
- `Enums/` — `Brightness`, `Texture`
- `Errors/` — `AudioTimbreError`
- `Support/` — `AudioDecoder` (a whole file into Float channels), `SampleStream` (blocks of Int16 through a sink, never the whole file), and the maths helpers

## ImagePalette — `Sources/ImagePalette`

### Module map
- `Core/` — `PaletteExtractor` (`extract(from:options:)` over a URL, a `CGImage` or OKLab samples; `PaletteOptions`), `ImageSampling` (load, draw down, un-premultiply, drop clear pixels)
- `Models/` — `Swatch` (sRGB bytes, share, OKLab lightness / chroma / hue, `hex` / `rgb` / `hsl`), `OKLab`
- `Support/` — `ColorFormats` (the string forms), `SplitMix` (the seeded generator)

## ImageCompare — `Sources/ImageCompare`

### Module map
- `Core/` — `ImageComparison` (`compare(old:new:)` over file bytes; `difference(_:_:limit:)` over two `CGImage`s, both drawn into 8-bit premultiplied sRGB and compared a 32-bit word a pixel)
- `Models/` — `ComparedImage` (picture, size, vector or not, bytes, type, frames), `PixelDifference` (count, total, changed bounds from the top-left, grayscale mask), `ImageComparisonResult`
- `Extensions/` — `PixelDifference.changedFraction`, `ImageComparisonResult.sizesDiffer`
- `Support/` — `ImageDecoding` (ImageIO, first frame; SVG through `NSImage` at 2 pixels a point, where AppKit is present), `PixelBuffer` (the top row first: a bitmap context keeps it first in memory, so the picture is drawn UNflipped — a flip mirrored every position and the tests caught it)

## Rules

Read `CONTRIBUTING.md` for the folder layout and the pull-request rules.

@CONTRIBUTING.md

## FontSpecimen — `Sources/FontSpecimen`

- `FontSpecimen(fileAt:)` / `(data:title:)`: the first face CoreText reads from the bytes (never registered) and the specimen's `lines`, each with a `Role`; `font(size:)` gives the face at a size.
