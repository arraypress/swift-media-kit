# Swift Media Metadata

Everything macOS knows about a file, read once, typed, and namespaced — from the name and size
through EXIF, IPTC, GPS, audio and video tags to a PDF's own page count. On-device, no network.
Ask for only the fields you need and only those are read: a listing of 27,000 files opens
nothing, a camera read opens the image, a digest reads every byte.

- Module `MediaMetadata` in `Sources/MediaMetadata`; tests in `Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+ (iOS 17, tvOS 17, visionOS 1). One dependency,
  swift-codec-kit, for the streamed digests — the README says so.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Core/` — `MetadataReader`: classify the file, work out which readers the wanted fields need, run them
- `Enums/` — `MetadataField` (the 104 curated fields), `FieldCategory`, `FieldSource`, `MediaKind`, `ValueKind`
- `Models/` — `FileFacts` (the answer), `FieldValue`, `FieldDescriptor`, `Coordinate`
- `Errors/` — `MetadataError`
- `Extensions/` — `URL.metadata()`
- `Support/` — the readers and helpers: `FileSystemFacts` / `FileSystemRaw`, `ImageFacts` (ImageIO; an SVG's size from its own attributes or viewBox, since ImageIO cannot open one) / `ImageRaw`, `MediaFacts` (AVFoundation) / `MediaRaw`, `DocumentFacts` (PDFKit), `ChecksumFacts`, `DerivedFacts`, `ExtendedAttributes`, `FieldCatalogue`, `Lookup` (codec names), `Format`, `Numbers`, `RawValue`, `ExifDate`, `ISO6709`

## Rules

@CONTRIBUTING.md

- **Auditing? Read `AUDIT.md` first** — what the last full audit checked and fixed, and the known non-issues to skip; extend it, do not redo it.
