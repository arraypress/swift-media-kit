//
//  MediaFileTests.swift
//  MediaMetadataTests
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import XCTest
@testable import MediaMetadata

final class MediaFileTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.directory("media")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Tags

    func testCommonTagsRoundTrip() async throws {
        let url = directory.appendingPathComponent("song.m4a")
        try await Fixtures.writeAudio(to: url)

        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.kind, .audio)
        XCTAssertEqual(facts.string(for: .title), Fixtures.Song.title)
        XCTAssertEqual(facts.string(for: .artist), Fixtures.Song.artist)
        XCTAssertEqual(facts.string(for: .album), Fixtures.Song.album)
    }

    func testStreamFactsAreRead() async throws {
        let url = directory.appendingPathComponent("song.m4a")
        try await Fixtures.writeAudio(to: url)

        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.values[.sampleRate], .integer(Int(Fixtures.Song.sampleRate)))
        XCTAssertEqual(facts.values[.channels], .integer(Fixtures.Song.channels))
        XCTAssertEqual(facts.values[.audioCodec], .text("AAC"))
        XCTAssertEqual(facts.values[.hasAudio], .boolean(true))

        guard case .duration(let seconds)? = facts.values[.duration] else {
            return XCTFail("no duration")
        }
        XCTAssertEqual(seconds, Fixtures.Song.seconds, accuracy: 0.2)
    }

    /// Genre, track and tempo are not common keys and never resolve as one.
    /// Asked for that way they come back empty from every file that has them,
    /// which is the quietest possible bug — the column is there, the data is
    /// there, and every cell is blank.
    func testGenreIsNotLookedUpAsACommonKey() async throws {
        let url = directory.appendingPathComponent("song.m4a")
        try await Fixtures.writeAudio(to: url)

        let asset = AVURLAsset(url: url)
        let common = try await asset.load(.commonMetadata)
        XCTAssertNil(
            common.first { $0.commonKey?.rawValue == "genre" },
            "if AVFoundation ever adds a common genre key, this reader can be simplified"
        )
    }

    // MARK: - Codecs

    /// `avc1` is technically right and "H.264" is what anyone reading a file
    /// list is looking for.
    func testCodecCodesResolveToNames() {
        XCTAssertEqual(Lookup.codecName("avc1"), "H.264")
        XCTAssertEqual(Lookup.codecName("hvc1"), "HEVC")
        XCTAssertEqual(Lookup.codecName("mp4a"), "AAC")
        XCTAssertEqual(Lookup.codecName("apcn"), "ProRes")
        XCTAssertEqual(Lookup.codecName("zzzz"), "zzzz", "an unknown code is reported, not hidden")
    }

    func testChannelCountsResolveToLayouts() {
        XCTAssertEqual(Lookup.channelLayout(1), "Mono")
        XCTAssertEqual(Lookup.channelLayout(2), "Stereo")
        XCTAssertEqual(Lookup.channelLayout(6), "5.1")
        XCTAssertEqual(Lookup.channelLayout(3), "3ch")
    }

    // MARK: - Raw

    /// The raw reader asks the asset which formats it carries rather than
    /// asking for a list of identifiers, so a key outside the SDK's 294 still
    /// comes through.
    func testRawCarriesEveryFormatTheFileHas() async throws {
        let url = directory.appendingPathComponent("song.m4a")
        try await Fixtures.writeAudio(to: url)

        let facts = try await MetadataReader.readEverything(url)
        let asset = AVURLAsset(url: url)
        let formats = try await asset.load(.availableMetadataFormats)

        XCTAssertFalse(formats.isEmpty, "fixture should advertise at least one format")

        var expected = 0
        for format in formats {
            let items = try await asset.loadMetadata(for: format)
            for item in items where await MediaRaw.value(of: item) != nil {
                guard let path = MediaRaw.path(for: item) else { continue }
                expected += 1
                XCTAssertNotNil(facts.raw[path], "raw passthrough dropped \(path)")
            }
        }
        XCTAssertGreaterThan(expected, 0)
        XCTAssertNotNil(facts.raw["track0.codec"])
        XCTAssertNotNil(facts.raw["asset.duration"])
    }

    /// iTunes keys begin with a copyright sign and arrive percent-encoded, so
    /// they have to be made typable before they can be a column name.
    func testIdentifiersAreMadeSafeForACommandLine() {
        XCTAssertEqual(MediaRaw.sanitise("itsk"), "itsk")
        XCTAssertEqual(MediaRaw.sanitise("%A9nam"), "nam")
        XCTAssertEqual(MediaRaw.sanitise("com.apple.quicktime.model"), "com.apple.quicktime.model")
    }

    // MARK: - Location

    /// A phone records a video's position as ISO 6709 text rather than as the
    /// GPS dictionary a photograph gets.
    func testISO6709Parsing() {
        let plain = ISO6709.parse("+37.7749-122.4194/")
        XCTAssertEqual(plain?.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(plain?.longitude ?? 0, -122.4194, accuracy: 0.0001)
        XCTAssertNil(plain?.altitude)

        let withAltitude = ISO6709.parse("+37.7749-122.4194+018.000/")
        XCTAssertEqual(withAltitude?.altitude ?? 0, 18, accuracy: 0.001)

        XCTAssertNil(ISO6709.parse(""), "nothing usable")
        XCTAssertNil(ISO6709.parse("+37.7749/"), "a latitude with no longitude is not a position")
        XCTAssertNil(ISO6709.parse("+00.0000+000.0000/"), "a camera with no fix writes zeroes")
    }
}
