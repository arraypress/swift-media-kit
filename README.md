# Swift Media Metadata

Everything macOS knows about a file, read once, typed, and namespaced — from
the name and size through EXIF, IPTC, GPS, audio and video tags to the PDF's
own page count. On-device, no network, no third-party dependencies.

```swift
import MediaMetadata

let facts = try await URL(fileURLWithPath: "larsen-wedding-001.jpg").metadata()

facts.string(for: .camera)        // "NIKON Z 6"
facts.string(for: .lens)          // "NIKKOR Z 24-70mm f/4 S"
facts.string(for: .shutterSpeed)  // "1/250"
facts.string(for: .iptcCity)      // "Kyoto" — written by the photographer, not geocoded
facts.coordinate?.latitude        // 35.011636
facts.capturedDate                // when the shutter opened, not when the file was copied
```

Ask for only what you need, and only that is read:

```swift
// 27,000 files a second: nothing is opened.
let listing = try await MetadataReader.read(url, fields: [.name, .size, .modified])

// Opens the image. Still about a third of a millisecond.
let camera = try await MetadataReader.read(url, fields: [.camera, .lens, .shotDate])

// Reads every byte. Ask for this one deliberately.
let proof = try await MetadataReader.read(url, fields: [.sha256])
```

## Two layers

**104 curated fields** — named, labelled, typed and aliased. `size` is an
`Int64` and not a string, `captured` is a `Date`, `keywords` is a list. They
carry a category and a cost, so a column chooser or a `--help` listing can be
generated rather than written.

**And everything else.** The macOS 27 SDK declares 676 image property
constants across 26 dictionaries, 294 media metadata identifiers and 127 URL
resource keys — and a file may carry keys outside all of them, maker notes
especially. So nothing is transcribed into a Swift enum and nothing is
filtered: whatever the frameworks return is flattened, namespaced and reported.

```swift
let everything = try await url.allMetadata()

everything.raw["exif.LensMake"]
everything.raw["iptc.ArtworkTitle"]
everything.raw["dng.CameraSerialNumber"]
everything.raw["makerApple.0x0003"]
everything.raw["id3.TPE2"]
everything.raw["fs.inode"]

everything.value(forToken: "lens")            // curated
everything.value(forToken: "exif.LensModel")  // raw — same call
```

Coverage is therefore a property of the SDK rather than of this package. A key
Apple adds tomorrow arrives without an edit here, and there is a test that
asserts it: for every dictionary ImageIO returns, every key in it must be
present in `raw`.

## Measured

On this machine — Apple silicon, macOS 27:

| | |
|---|---|
| Name, size, dates and type for **107,765 files** (129 GB) | **3.9 s** |
| The same tree through Spotlight's `MDItem` | **54.8 s** |
| EXIF from an image | **0.32 ms**, about 10× faster across cores |
| SHA-256 | **998 MB/s** on one core, **9.5 GB/s** across them |

Which settles the design: read the file, don't ask the index. Spotlight is
14× slower, returns only filesystem attributes on a volume it has not indexed
— and **has no attribute for the lens at all**. `kMDItemAcquisitionModel` is
the camera body; the glass in front of it is only in the file.

Hashing is the exception to all of this: it is bounded by the disk, not the
processor. 9.5 GB/s is a warm cache. Half a terabyte on a USB drive is forty
minutes whatever the machine does, so checksum fields are never read unless
asked for by name.

## What survives, by format

Generated and measured rather than assumed — the test suite writes one file of
every type ImageIO can write and every container ffmpeg can build, then reads
them all back.

**EXIF is kept by** `jpeg` · `tiff` · `png` · `heic` · `avif` · `psd` · `gif`
**and absent from** `bmp` · `dds` · `exr` · `jp2` · `tga` · `pbm` · `astc` ·
`ktx` · `ktx2` · `atx` · `heics`.

**AVFoundation opens** `.mp4` (H.264, HEVC) · `.mov` (ProRes) · `.m4a` (AAC,
ALAC) · `.mp3` · `.flac` · `.wav` · `.aiff` · `.caf` · `.opus`
**and refuses** `.mkv` · `.avi` · `.webm`. A file it refuses yields an empty
row, never a wrong one.

**Tags round-trip through** `.mp4` · `.mov` · `.m4a` · `.mp3`. Genre survives
all four; track number survives all but ProRes.

## Things that cost an afternoon

Each of these is now a test, so it can only cost one once.

**`.directoryEntryCountKey` poisons a request set.** Include it alongside
anything else and `URLResourceValues` comes back with *every* value nil — no
throw, no partial answer. `[.fileSizeKey]` gives 3 bytes; `[.fileSizeKey,
.directoryEntryCountKey]` on the same file gives nil. It is asked for alone,
and only for directories.

**`URLResourceValues.allValues` is not all the values.** 50 keys requested, 7
returned; size, dates and `isDirectory` are readable only through the typed
properties. Both paths are read here.

**EXIF numbers are not all the same type.** The spec stores focal length as a
rational and ISO as a short, and ImageIO hands each back as whatever it was
stored as — measured, `FNumber` comes back as an `Int`. `value as? Double`
returns nil for it, silently, and the column looks like a camera that recorded
nothing. Every numeric tag goes through a coercion that accepts either.

**macOS declares no type for Matroska.** `UTType(filenameExtension: "mkv")` is
a dynamic type conforming to nothing, so the SDK alone calls the second most
common video container an unknown blob. Same for `.ape`, `.wv`, `.dsf`. A
short fallback table fills that silence and can never contradict a declared
type — there is a test.

**Genre, track and tempo are not common keys.** Asked for as
`AVMetadataKeySpaceCommon` they resolve to nothing from every file that has
them: the column is there, the data is there, and every cell is blank. They
come from the ID3, iTunes and QuickTime identifiers instead.

**`JSONEncoder` does not preserve key order.** It builds a dictionary, and
Swift seeds string hashing per process, so the same facts encode differently in
the next run. To diff two manifests or hash one, set
`outputFormatting = [.sortedKeys]`.

**iTunes keys are Latin-1 percent-encoded.** `©nam` arrives as `%A9nam`, and
`removingPercentEncoding` returns nil for it because it is not valid UTF-8 —
leaving the key reading `A9nam`, which looks like data and is not.

**A rotation flag is not decoration.** A camera held sideways writes the
sensor's dimensions and a flag saying to turn them. Reporting 6000x4000 for a
picture every viewer shows as 4000x6000 is wrong in the only way that matters.

**`CGImageDestination` drops tags it is given.** `FocalLenIn35mmFilm` written
into the properties dictionary is simply absent from the file that comes out —
worth knowing before trusting any fixture.

## Fields

Ten categories, 104 fields: **general** (name, path, size, kind, owner, tags,
Finder comment, where it was downloaded from), **dates** (created, modified,
accessed, added, captured, and the calendar parts), **image** (dimensions,
megapixels, orientation, colour model, depth, DPI, alpha, profile),
**camera** (make, model, lens, focal length, aperture, shutter, ISO, exposure
bias, metering, flash, white balance, software, shooting date), **IPTC**
(headline, caption, keywords, credit, copyright, by-line, source, city, state,
country), **location** (latitude, longitude, altitude), **audio** (title,
artist, album artist, album, composer, genre, year, track, disc, comment, BPM,
key, duration, sample rate, channels, bitrate, codec), **video** (dimensions,
resolution, frame rate, codec, bitrate, sound), **document** (pages, title,
author, subject, keywords, creator, producer, encryption, page size, its own
dates) and **checksums** (MD5, SHA-1, SHA-256, SHA-384, SHA-512, CRC-32).

```swift
MetadataField.fields(in: .camera)     // every camera field
MetadataField.freeFields              // everything answerable without opening the file
MetadataField(token: "fnumber")       // .aperture — aliases and punctuation are forgiven
FieldCatalogue.all                    // labels, categories, shapes and costs
```

## Reading many

```swift
let facts = await MetadataReader.read(urls, fields: [.name, .size, .camera]) { done in
    print("\(done) of \(urls.count)")
}
```

Bounded concurrency — a task per file over a hundred thousand of them spends
more on scheduling than on reading. Results come back in the order the URLs
were given, and a file that cannot be read yields an empty row rather than
stopping the batch.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-media-metadata.git", from: "0.1.0")
```

## Requirements

macOS 14+ / iOS 17+ / tvOS 17+ / visionOS 1+, Swift 6. One dependency,
[swift-codec-kit](https://github.com/arraypress/swift-codec-kit), for the
streamed digests — a multi-gigabyte video never has to fit in memory.

An SVG's width and height come from its own attributes or viewBox, since ImageIO does not open one.

PDF fields need PDFKit and are absent where it is not available. Finder tags,
comments and download origins are macOS only. Nothing here touches the network,
including for place names: coordinates stay coordinates, and the offline answer
to *where was this taken* is the photographer's own IPTC city.

## Licence

MIT.
