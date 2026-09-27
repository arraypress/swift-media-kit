//
//  CatalogueTests.swift
//  MediaMetadataTests
//
//  The field catalogue is what a column chooser, a `--help` listing and a
//  table renderer all read, so its integrity is worth asserting rather than
//  assuming.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import MediaMetadata

final class CatalogueTests: XCTestCase {

    // MARK: - Integrity

    func testEveryFieldIsDescribed() {
        for field in MetadataField.allCases {
            let descriptor = field.descriptor
            XCTAssertEqual(descriptor.key, field.rawValue)
            XCTAssertFalse(descriptor.label.isEmpty, "\(field.key) has no label")
            XCTAssertFalse(descriptor.key.isEmpty)
        }
        XCTAssertEqual(FieldCatalogue.all.count, MetadataField.allCases.count)
    }

    func testKeysAndLabelsAreUnique() {
        let keys = MetadataField.allCases.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "two fields share a key")

        let labels = MetadataField.allCases.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count, "two fields share a label")
    }

    func testEveryCategoryHasFields() {
        for category in FieldCategory.allCases {
            XCTAssertFalse(
                MetadataField.fields(in: category).isEmpty,
                "\(category.rawValue) has no fields"
            )
            XCTAssertFalse(category.label.isEmpty)
        }
    }

    /// Normalising a key must never make two of them the same, or a typed
    /// token would resolve to whichever came first.
    func testNormalisedKeysDoNotCollide() {
        let normalised = MetadataField.allCases.map { FieldCatalogue.normalise($0.rawValue) }
        XCTAssertEqual(Set(normalised).count, normalised.count)
    }

    /// An alias must not shadow a real field's key.
    func testAliasesDoNotShadowRealKeys() {
        let keys = Set(MetadataField.allCases.map { FieldCatalogue.normalise($0.rawValue) })
        for alias in FieldCatalogue.aliases.keys {
            XCTAssertFalse(
                keys.contains(FieldCatalogue.normalise(alias)),
                "\(alias) is both an alias and a real key"
            )
        }
    }

    // MARK: - Lookup

    func testTokensResolveHoweverTheyAreTyped() {
        XCTAssertEqual(MetadataField(token: "sha256"), .sha256)
        XCTAssertEqual(MetadataField(token: "SHA-256"), .sha256)
        XCTAssertEqual(MetadataField(token: "sha_256"), .sha256)
        XCTAssertEqual(MetadataField(token: "focal length"), .focalLength)
        XCTAssertEqual(MetadataField(token: "Focal-Length"), .focalLength)
        XCTAssertNil(MetadataField(token: "not a field"))
    }

    /// The obvious word and the precise one are rarely the same.
    func testAliasesResolve() {
        XCTAssertEqual(MetadataField(token: "filename"), .name)
        XCTAssertEqual(MetadataField(token: "shot"), .shotDate)
        XCTAssertEqual(MetadataField(token: "fnumber"), .aperture)
        XCTAssertEqual(MetadataField(token: "author"), .byline)
        XCTAssertEqual(MetadataField(token: "pages"), .pageCount)
        XCTAssertEqual(MetadataField(token: "checksum"), .sha256)
    }

    // MARK: - Cost

    /// Nothing in the free tier may open the file.
    func testFreeFieldsNeverOpenTheFile() {
        for field in MetadataField.freeFields {
            XCTAssertFalse(field.source.opensTheFile, "\(field.key) is not free")
        }
        XCTAssertTrue(MetadataField.freeFields.contains(.name))
        XCTAssertTrue(MetadataField.freeFields.contains(.size))
        XCTAssertFalse(MetadataField.freeFields.contains(.camera))
        XCTAssertFalse(MetadataField.freeFields.contains(.sha256))
    }

    func testSourcesRankByCost() {
        XCTAssertLessThan(FieldSource.fileSystem, FieldSource.image)
        XCTAssertLessThan(FieldSource.image, FieldSource.checksum)
        XCTAssertFalse(FieldSource.derived.opensTheFile)
        XCTAssertTrue(FieldSource.media.opensTheFile)
    }

    /// A JPEG is never handed to AVFoundation and an MP3 never to ImageIO.
    func testMediaKindsClaimOnlyTheirOwnFields() {
        XCTAssertTrue(MediaKind.image.answers(.camera))
        XCTAssertFalse(MediaKind.image.answers(.duration))
        XCTAssertTrue(MediaKind.audio.answers(.duration))
        XCTAssertFalse(MediaKind.audio.answers(.camera))
        XCTAssertTrue(MediaKind.document.answers(.pageCount))
        XCTAssertTrue(MediaKind.other.answers(.name))

        // A checksum is answerable for anything with bytes in it.
        for kind in MediaKind.allCases {
            XCTAssertTrue(kind.answers(.sha256), "\(kind.rawValue) cannot be hashed")
        }
    }

    // MARK: - Values

    /// Sorting by a formatted string puts "9 MB" above "10 MB", which is the
    /// reason values stay typed until something prints them.
    func testSizesSortByMagnitudeNotByCharacter() {
        let sizes: [FieldValue] = [.bytes(10_000_000), .bytes(9_000_000), .bytes(100)]
        let ordered = sizes.sorted { ($0.sortKey.0 ?? 0) < ($1.sortKey.0 ?? 0) }
        XCTAssertEqual(ordered, [.bytes(100), .bytes(9_000_000), .bytes(10_000_000)])

        let asText = sizes.map(\.plain).sorted()
        XCTAssertEqual(asText.first, "100", "and this is what sorting them as text does")
    }

    func testTextSortsCaseInsensitively() {
        let names: [FieldValue] = [.text("banana"), .text("Apple"), .text("cherry")]
        let ordered = names.sorted { $0.sortKey.1 < $1.sortKey.1 }
        XCTAssertEqual(ordered, [.text("Apple"), .text("banana"), .text("cherry")])
    }

    func testEmptinessIsDetectable() {
        XCTAssertTrue(FieldValue.text("").isEmpty)
        XCTAssertTrue(FieldValue.text("   ").isEmpty)
        XCTAssertTrue(FieldValue.list([]).isEmpty)
        XCTAssertFalse(FieldValue.integer(0).isEmpty, "zero is a value")
        XCTAssertFalse(FieldValue.boolean(false).isEmpty, "so is false")
    }

    func testAlignmentFollowsTheValueShape() {
        XCTAssertTrue(ValueKind.bytes.prefersTrailingAlignment)
        XCTAssertTrue(ValueKind.integer.prefersTrailingAlignment)
        XCTAssertFalse(ValueKind.text.prefersTrailingAlignment)
        XCTAssertFalse(ValueKind.date.prefersTrailingAlignment)
        XCTAssertTrue(ValueKind.date.sortsNumerically)
    }

    func testPlainRenderingDropsTrailingZeroes() {
        XCTAssertEqual(FieldValue.decimal(4.0).plain, "4")
        XCTAssertEqual(FieldValue.decimal(4.5).plain, "4.5")
        XCTAssertEqual(FieldValue.list(["a", "b"]).plain, "a, b")
        XCTAssertEqual(FieldValue.boolean(true).plain, "true")
    }

    // MARK: - Coding

    func testFactsRoundTripThroughJSON() throws {
        let facts = FileFacts(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            kind: .image,
            values: [
                .name: .text("photo.jpg"),
                .size: .bytes(5_242_880),
                .iso: .integer(320),
                .megapixels: .decimal(24.2),
                .shotDate: .date(Date(timeIntervalSince1970: 1_780_000_000)),
                .keywords: .list(["wedding", "larsen"]),
                .hasAlpha: .boolean(false),
                .latitude: .coordinate(35.0116),
                .duration: .duration(12.5),
            ],
            raw: ["exif.LensModel": .text("NIKKOR Z 24-70mm f/4 S"), "fs.inode": .integer(99)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(facts)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(FileFacts.self, from: data)

        XCTAssertEqual(back.kind, facts.kind)
        XCTAssertEqual(back.values, facts.values)
        XCTAssertEqual(back.raw["exif.LensModel"], .text("NIKKOR Z 24-70mm f/4 S"))
        XCTAssertEqual(back.url.path, facts.url.path)
    }

    /// Numbers must arrive as numbers, or every consumer has to re-parse them.
    func testJSONCarriesRealTypes() throws {
        let facts = FileFacts(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            kind: .image,
            values: [.size: .bytes(1024), .iso: .integer(320), .hasAlpha: .boolean(false)]
        )
        let data = try JSONEncoder().encode(facts)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(text.contains("\"size\":1024"), "size was quoted: \(text)")
        XCTAssertTrue(text.contains("\"iso\":320"))
        XCTAssertTrue(text.contains("\"hasAlpha\":false"))
    }

    /// Diffing two manifests, or hashing one, needs byte-identical output from
    /// one run to the next — and `JSONEncoder` does not give it by default.
    /// It builds a dictionary for a keyed container, and Swift seeds string
    /// hashing per process, so key order changes between runs however the
    /// values were encoded. `.sortedKeys` is the fix, and it is the caller's
    /// to apply.
    func testStableOutputNeedsSortedKeys() throws {
        let facts = FileFacts(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            kind: .image,
            values: [.size: .bytes(1), .name: .text("a"), .iso: .integer(2), .camera: .text("c")],
            raw: ["z.last": .integer(1), "a.first": .integer(2)]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let first = try encoder.encode(facts)
        for _ in 0..<20 {
            XCTAssertEqual(try encoder.encode(facts), first, "sorted output must not vary")
        }

        let text = String(decoding: first, as: UTF8.self)
        let camera = try XCTUnwrap(text.range(of: "\"camera\""))
        let iso = try XCTUnwrap(text.range(of: "\"iso\""))
        let name = try XCTUnwrap(text.range(of: "\"name\""))
        XCTAssertLessThan(camera.lowerBound, iso.lowerBound, "sorted, not catalogue order")
        XCTAssertLessThan(iso.lowerBound, name.lowerBound)

        // And the round trip survives either way.
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(FileFacts.self, from: first).values, facts.values)
    }

    // MARK: - Formatting

    func testCameraValuesReadTheWayPhotographersWriteThem() {
        XCTAssertEqual(Format.shutterSpeed(1.0 / 250), "1/250")
        XCTAssertEqual(Format.shutterSpeed(2), "2s")
        XCTAssertEqual(Format.shutterSpeed(0), "")
        XCTAssertEqual(Format.fNumber(2.8), "f/2.8")
        XCTAssertEqual(Format.fNumber(4), "f/4")
        XCTAssertEqual(Format.millimetres(35), "35mm")
        XCTAssertEqual(Format.stops(0), "0 EV")
        XCTAssertEqual(Format.stops(-0.33), "-0.33 EV")
    }

    func testDurationsAreReadableAndSafeInAFileName() {
        XCTAssertEqual(Format.duration(5), "5s")
        XCTAssertEqual(Format.duration(150), "2m30s")
        XCTAssertEqual(Format.duration(3930), "1h05m30s")
        XCTAssertEqual(Format.duration(0), "")
        XCTAssertEqual(Format.duration(.infinity), "")
    }

    /// Real footage is rarely the round number the name suggests.
    func testResolutionLabelsAreBands() {
        XCTAssertEqual(Format.resolutionLabel(shortEdge: 1080), "1080p")
        XCTAssertEqual(Format.resolutionLabel(shortEdge: 1038), "1080p")
        XCTAssertEqual(Format.resolutionLabel(shortEdge: 2160), "4K")
        XCTAssertEqual(Format.resolutionLabel(shortEdge: 240), "SD")
        XCTAssertEqual(Format.resolutionLabel(shortEdge: 0), "")
    }

    /// A phone clip at 1080x1920 is 1080p vertical to everyone who handles it.
    /// Reading the height instead of the short edge calls it 1440p, which
    /// describes a frame nobody shot.
    func testPortraitVideoIsLabelledByItsShortEdge() {
        XCTAssertEqual(Format.resolutionLabel(width: 1080, height: 1920), "1080p")
        XCTAssertEqual(Format.resolutionLabel(width: 1920, height: 1080), "1080p")
        XCTAssertEqual(Format.resolutionLabel(width: 1080, height: 1350), "1080p")
        XCTAssertEqual(Format.resolutionLabel(width: 3840, height: 2160), "4K")
        XCTAssertEqual(Format.resolutionLabel(width: 2160, height: 3840), "4K", "vertical 4K is still 4K")
    }

    func testEXIFEnumerationsResolveToWords() {
        XCTAssertEqual(Lookup.meteringMode(5), "Pattern")
        XCTAssertEqual(Lookup.exposureProgram(3), "Aperture priority")
        XCTAssertEqual(Lookup.lightSource(4), "Flash")
        XCTAssertEqual(Lookup.colorSpace(1), "sRGB")
        XCTAssertEqual(Lookup.normalLowHigh(2), "High")
        XCTAssertNil(Lookup.meteringMode(99), "an unknown code says nothing rather than something wrong")
    }
}
