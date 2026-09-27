//
//  ImageMetadataTests.swift
//  MediaMetadataTests
//
//  Written with known values, read back, compared. Anything that disagrees is
//  a bug in the reader rather than a surprise in somebody's photograph.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import ImageIO
import XCTest
@testable import MediaMetadata

final class ImageMetadataTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.directory("image")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Curated fields

    /// ImageIO does not open an SVG, so its size is read from the file's own words: the
    /// root's width and height first, the viewBox when those are missing, and nothing when
    /// the width is in a unit that is not pixels.
    func testSVGSizeComesFromAttributesOrViewBox() async throws {
        let attrs = directory.appendingPathComponent("attrs.svg")
        try #"<svg xmlns="http://www.w3.org/2000/svg" width="640px" height="360" viewBox="0 0 16 9"></svg>"#.write(to: attrs, atomically: true, encoding: .utf8)
        let attrFacts = try await MetadataReader.read(attrs, fields: [.width, .height, .dimensions, .orientation])
        XCTAssertEqual(attrFacts.kind, .image)
        XCTAssertEqual(attrFacts.values[.width], .integer(640))
        XCTAssertEqual(attrFacts.values[.height], .integer(360))
        XCTAssertEqual(attrFacts.string(for: .dimensions), "640x360")
        XCTAssertEqual(attrFacts.string(for: .orientation), "Landscape")

        let box = directory.appendingPathComponent("box.svg")
        try #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0, 0, 24, 48"><rect/></svg>"#.write(to: box, atomically: true, encoding: .utf8)
        let boxFacts = try await MetadataReader.read(box, fields: [.width, .height])
        XCTAssertEqual(boxFacts.values[.width], .integer(24))
        XCTAssertEqual(boxFacts.values[.height], .integer(48))

        let units = directory.appendingPathComponent("units.svg")
        try #"<svg xmlns="http://www.w3.org/2000/svg" width="10cm" height="5cm"></svg>"#.write(to: units, atomically: true, encoding: .utf8)
        let unitFacts = try await MetadataReader.read(units, fields: [.width, .height])
        XCTAssertNil(unitFacts.values[.width], "a width in centimetres is not a pixel count")
    }

    func testEveryCameraFieldRoundTrips() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)

        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.kind, .image)
        XCTAssertEqual(facts.string(for: .make), Fixtures.Photo.make)
        XCTAssertEqual(facts.string(for: .camera), Fixtures.Photo.model)
        XCTAssertEqual(facts.string(for: .lens), Fixtures.Photo.lens)
        XCTAssertEqual(facts.string(for: .software), Fixtures.Photo.software)
        XCTAssertEqual(facts.values[.iso], .integer(Fixtures.Photo.iso))
        XCTAssertEqual(facts.string(for: .aperture), "f/4")
        XCTAssertEqual(facts.string(for: .focalLength), "35mm")
        XCTAssertEqual(facts.string(for: .exposureBias), "+0.5 EV")
        XCTAssertEqual(facts.string(for: .meteringMode), "Pattern")
        XCTAssertEqual(facts.string(for: .whiteBalance), "Auto")
    }

    /// EXIF stores some numbers as rationals and others as shorts, and
    /// ImageIO hands each back as whatever type it was stored as. Measured on
    /// this fixture: `FNumber` and `FocalLength` both come back as `Int`
    /// despite being rationals in the file. Reading them as `Double` returns
    /// nil, silently, and the column looks like a camera that recorded
    /// nothing — so every numeric tag goes through `Numbers`.
    func testNumericTagsSurviveEitherStorageType() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readEverything(url)

        XCTAssertEqual(facts.raw["exif.FNumber"], .integer(4), "fixture should store this as an integer")
        XCTAssertEqual(facts.string(for: .aperture), "f/4", "and the column must read it anyway")

        XCTAssertEqual(Numbers.double(Int(4)), 4.0)
        XCTAssertEqual(Numbers.double(Double(4.5)), 4.5)
        XCTAssertEqual(Numbers.double(NSNumber(value: 4)), 4.0)
        XCTAssertEqual(Numbers.double("4.5"), 4.5)
        XCTAssertNil(Numbers.double(true), "a boolean is not the number one")
        XCTAssertEqual(Numbers.firstInt([320, 400]), 320)
        XCTAssertEqual(Numbers.firstInt(320), 320)
    }

    /// `CGImageDestination` does not persist every tag it is handed —
    /// measured: `FocalLenIn35mmFilm` written into the properties dictionary
    /// is absent from the file that comes out. Worth knowing before trusting a
    /// fixture, and the reason this suite asserts against what the file
    /// actually holds rather than against what was passed to the writer.
    func testWriterDropsSomeTagsItIsGiven() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readEverything(url)

        XCTAssertNil(facts.raw["exif.FocalLenIn35mmFilm"])
        XCTAssertNil(facts.values[.focalLength35])
        XCTAssertNotNil(facts.raw["exif.FocalLength"], "the ordinary focal length does survive")
    }

    /// A photographer reads `1/250`, not `0.004`.
    func testShutterSpeedIsWrittenAsAFraction() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)
        XCTAssertEqual(facts.string(for: .shutterSpeed), "1/250")
    }

    /// EXIF packs the mode and red-eye reduction into the same integer as
    /// "did it fire", so the unpacking is asserted against the specification
    /// directly.
    func testFlashUnpacksItsBits() {
        XCTAssertEqual(Lookup.flash(0x00), "Did not fire")
        XCTAssertEqual(Lookup.flash(0x01), "Fired")
        XCTAssertEqual(Lookup.flash(0x09), "Fired, compulsory")
        XCTAssertEqual(Lookup.flash(0x18), "Did not fire, auto")
        XCTAssertEqual(Lookup.flash(0x19), "Fired, auto")
        XCTAssertEqual(Lookup.flash(0x20), "No flash function")
        XCTAssertEqual(Lookup.flash(0x41), "Fired, red-eye reduction")
    }

    /// Whatever ImageIO normalises the stored integer to, the curated column
    /// must say the same thing the raw value does.
    func testFlashColumnAgreesWithTheRawValue() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readEverything(url)

        let raw = try XCTUnwrap(facts.raw["exif.Flash"])
        guard case .integer(let stored) = raw else { return XCTFail("flash is not an integer") }
        XCTAssertEqual(facts.string(for: .flash), Lookup.flash(stored))
    }

    func testShootingDateIsReadWithoutConversion() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        guard case .date(let shot)? = facts.values[.shotDate] else {
            return XCTFail("no shooting date")
        }
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: shot)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 6)
        XCTAssertEqual(parts.day, 27)
        XCTAssertEqual(parts.hour, 13)
        XCTAssertEqual(parts.minute, 42)
        XCTAssertEqual(parts.second, 11)
    }

    /// The capture time beats the file's own creation date, which is the date
    /// a copy to a delivery drive would have rewritten.
    func testCapturedPrefersTheShutterOverTheFileSystem() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.string(for: .year), "2026")
        XCTAssertEqual(facts.string(for: .month), "06")
        XCTAssertEqual(facts.string(for: .day), "27")
        XCTAssertEqual(facts.string(for: .time), "13:42:11")
        XCTAssertEqual(facts.capturedDate, facts.values[.shotDate].flatMap {
            if case .date(let date) = $0 { return date } else { return nil }
        })
    }

    // MARK: - IPTC

    func testIPTCFieldsRoundTrip() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.string(for: .headline), Fixtures.Photo.headline)
        XCTAssertEqual(facts.string(for: .caption), Fixtures.Photo.caption)
        XCTAssertEqual(facts.values[.keywords], .list(Fixtures.Photo.keywords))
        XCTAssertEqual(facts.string(for: .credit), Fixtures.Photo.credit)
        XCTAssertEqual(facts.string(for: .copyright), Fixtures.Photo.copyright)
        XCTAssertEqual(facts.string(for: .byline), Fixtures.Photo.byline)
        XCTAssertEqual(facts.string(for: .iptcSource), Fixtures.Photo.source)
    }

    /// The offline answer to "where was this taken" — typed by a person, so it
    /// needs no geocoding service.
    func testIPTCPlaceNamesNeedNoNetwork() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.string(for: .iptcCity), Fixtures.Photo.city)
        XCTAssertEqual(facts.string(for: .iptcState), Fixtures.Photo.state)
        XCTAssertEqual(facts.string(for: .iptcCountry), Fixtures.Photo.country)
    }

    // MARK: - Location

    func testCoordinatesKeepTheirSign() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        let coordinate = try XCTUnwrap(facts.coordinate)
        XCTAssertEqual(coordinate.latitude, Fixtures.Photo.latitude, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, Fixtures.Photo.longitude, accuracy: 0.0001)
        XCTAssertEqual(coordinate.altitude ?? 0, Fixtures.Photo.altitude, accuracy: 0.5)
    }

    /// Degrees arrive unsigned with the hemisphere in a separate letter.
    /// Dropping it puts half the world in the wrong one.
    func testSouthAndWestAreNegative() async throws {
        let url = directory.appendingPathComponent("south.jpg")
        try Fixtures.writeSouthWestImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        let coordinate = try XCTUnwrap(facts.coordinate)
        XCTAssertLessThan(coordinate.latitude, 0)
        XCTAssertLessThan(coordinate.longitude, 0)
    }

    /// A camera with no fix writes zeroes, and 0,0 is a real place at sea.
    func testNullIslandIsTreatedAsNoFix() {
        XCTAssertFalse(Coordinate(latitude: 0, longitude: 0).isPlausible)
        XCTAssertTrue(Coordinate(latitude: 0.001, longitude: 0).isPlausible)
        XCTAssertFalse(Coordinate(latitude: 91, longitude: 0).isPlausible)
    }

    // MARK: - Geometry

    func testDimensionsAreReadFromTheFile() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.values[.width], .integer(Fixtures.Photo.width))
        XCTAssertEqual(facts.values[.height], .integer(Fixtures.Photo.height))
        XCTAssertEqual(facts.string(for: .dimensions), "120x80")
        XCTAssertEqual(facts.string(for: .orientation), "Landscape")
    }

    /// A camera held sideways writes the sensor's dimensions plus a flag
    /// saying to turn them. Reporting the unrotated pair describes a picture
    /// nobody will ever see.
    func testRotationFlagSwapsTheReportedDimensions() async throws {
        let url = directory.appendingPathComponent("rotated.jpg")
        try Fixtures.writeImage(to: url, orientation: 6)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.values[.width], .integer(Fixtures.Photo.height))
        XCTAssertEqual(facts.values[.height], .integer(Fixtures.Photo.width))
        XCTAssertEqual(facts.string(for: .orientation), "Portrait")
    }

    // MARK: - Raw coverage

    /// The claim is that nothing ImageIO returns is dropped. This asserts it
    /// against the framework itself rather than against a list in this package.
    func testRawKeepsEveryKeyImageIOReturns() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)

        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]

        let facts = try await MetadataReader.readEverything(url)

        var expected = 0
        var missing: [String] = []
        for (dictionary, prefix) in ImageRaw.namespaces {
            guard let nested = properties[dictionary] as? [CFString: Any] else { continue }
            for (key, value) in nested {
                guard RawValue.convert(value) != nil else { continue }
                expected += 1
                if facts.raw["\(prefix).\(key as String)"] == nil {
                    missing.append("\(prefix).\(key as String)")
                }
            }
        }

        XCTAssertGreaterThan(expected, 25, "fixture should carry a substantial number of keys")
        XCTAssertEqual(missing, [], "raw passthrough dropped keys")
    }

    func testRawIsAddressableByNamespace() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readEverything(url)

        XCTAssertEqual(facts.raw["exif.LensModel"], .text(Fixtures.Photo.lens))
        XCTAssertEqual(facts.raw["tiff.Make"], .text(Fixtures.Photo.make))
        XCTAssertEqual(facts.raw["iptc.Headline"], .text(Fixtures.Photo.headline))
        XCTAssertFalse(facts.rawKeys(in: "gps").isEmpty)
        XCTAssertEqual(facts.raw["container.ImageCount"], .integer(1))
    }

    /// A caller should be able to name a curated field or a raw key and not
    /// have to know which sort it was.
    func testTokenLookupSpansBothLayers() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)
        let facts = try await MetadataReader.readEverything(url)

        XCTAssertEqual(facts.value(forToken: "lens"), .text(Fixtures.Photo.lens))
        XCTAssertEqual(facts.value(forToken: "exif.LensModel"), .text(Fixtures.Photo.lens))
        XCTAssertEqual(facts.value(forToken: "exif.lensmodel"), .text(Fixtures.Photo.lens))
        XCTAssertNil(facts.value(forToken: "nothing.at.all"))
    }

    // MARK: - Cost

    /// Asking for a name must not open the file.
    func testCheapFieldsDoNotTouchTheImage() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)

        let facts = try await MetadataReader.read(url, fields: [.name, .size, .ext])
        XCTAssertEqual(facts.values.count, 3)
        XCTAssertNil(facts.values[.camera])
        XCTAssertTrue(facts.raw.isEmpty)
    }

    /// Fields read only to settle a derived one must not appear in the answer.
    func testHelperFieldsAreNotLeakedIntoTheResult() async throws {
        let url = directory.appendingPathComponent("photo.jpg")
        try Fixtures.writeImage(to: url)

        let facts = try await MetadataReader.read(url, fields: [.year])
        XCTAssertEqual(Array(facts.values.keys), [.year])
    }
}
