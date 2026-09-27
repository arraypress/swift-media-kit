//
//  CorpusTests.swift
//  MediaMetadataTests
//
//  Pointed at every format this machine can produce, rather than at the two or
//  three a developer thinks of.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import UniformTypeIdentifiers
import XCTest
@testable import MediaMetadata

final class CorpusTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.directory("corpus")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Images

    /// Every image format ImageIO will write, read back.
    ///
    /// The list comes from `CGImageDestinationCopyTypeIdentifiers`, so this
    /// covers whatever the OS supports today and will cover whatever it
    /// supports after an update without anyone editing this file.
    func testEveryWritableImageFormatIsRead() async throws {
        let samples = Corpus.writeImages(into: directory)
        XCTAssertGreaterThan(samples.count, 8, "ImageIO should write a good many types")

        var unread: [String] = []
        for sample in samples {
            let facts = try await MetadataReader.readAll(sample.url)
            XCTAssertEqual(facts.kind, .image, "\(sample.type.identifier) should classify as an image")

            // Dimensions are the one thing every raster format ought to answer.
            if facts.values[.width] == nil {
                unread.append(sample.type.identifier)
            }
        }

        // Measured: ImageIO will *write* a DDS and then decline to report the
        // dimensions of what it wrote. Asserted rather than tolerated, so the
        // day it changes this test says so.
        XCTAssertEqual(unread, ["com.microsoft.dds"], "the set of write-only formats has changed")
    }

    /// Which image formats actually preserve EXIF, measured rather than assumed.
    ///
    /// Most do not. A PNG has no EXIF section in the sense a JPEG does, and a
    /// reader that treats an empty camera column as a failure would be wrong
    /// about half the corpus.
    func testEXIFSurvivalIsFormatDependent() async throws {
        let samples = Corpus.writeImages(into: directory)

        var kept: [String] = []
        var lost: [String] = []
        for sample in samples {
            let facts = try await MetadataReader.readAll(sample.url)
            let extension_ = sample.url.pathExtension
            if facts.values[.camera] != nil { kept.append(extension_) } else { lost.append(extension_) }
        }

        XCTAssertTrue(kept.contains("jpeg") || kept.contains("jpg"), "JPEG must keep its camera model")
        XCTAssertFalse(kept.isEmpty)
        print("EXIF kept by: \(kept.sorted().joined(separator: ", "))")
        print("EXIF absent in: \(lost.sorted().joined(separator: ", "))")
    }

    // MARK: - Audio and video

    /// Every container ffmpeg can build, handed to AVFoundation.
    ///
    /// Classification comes from the type identifier and must always be right.
    /// Whether the file can be *opened* is AVFoundation's business, and the
    /// point of the test is that an unopenable file yields an empty row rather
    /// than a wrong one or a crash.
    func testEveryGeneratedContainerIsHandled() async throws {
        let samples = try Corpus.writeMedia(into: directory)
        try XCTSkipIf(samples.isEmpty, "ffmpeg not installed")

        var opened: [String] = []
        var refused: [String] = []

        for sample in samples {
            let facts = try await MetadataReader.readAll(sample.url)
            XCTAssertEqual(facts.kind, sample.expectedKind, "\(sample.name) classified wrongly")

            if facts.values[.duration] != nil {
                opened.append(sample.name)
                // Anything AVFoundation opened must give a sane duration.
                guard case .duration(let seconds)? = facts.values[.duration] else {
                    XCTFail("\(sample.name) duration is not a duration")
                    continue
                }
                XCTAssertEqual(seconds, Double(Corpus.seconds), accuracy: 0.35, "\(sample.name)")
            } else {
                refused.append(sample.name)
                XCTAssertNil(facts.values[.audioCodec], "\(sample.name) reported a codec it could not read")
            }
        }

        print("AVFoundation opened: \(opened.sorted().joined(separator: ", "))")
        print("AVFoundation refused: \(refused.sorted().joined(separator: ", "))")
        XCTAssertFalse(opened.isEmpty, "at least Apple's own containers must open")
    }

    /// Tags written by ffmpeg, read back through AVFoundation.
    func testTagsRoundTripThroughTheContainersThatCarryThem() async throws {
        let samples = try Corpus.writeMedia(into: directory)
        try XCTSkipIf(samples.isEmpty, "ffmpeg not installed")

        var carried: [String] = []
        for sample in samples where sample.carriesTags {
            let facts = try await MetadataReader.readAll(sample.url)
            guard facts.values[.duration] != nil else { continue }
            if facts.string(for: .title) == Corpus.Tags.title {
                carried.append(sample.name)
                XCTAssertEqual(facts.string(for: .artist), Corpus.Tags.artist, "\(sample.name)")
                XCTAssertEqual(facts.string(for: .album), Corpus.Tags.album, "\(sample.name)")
            }
        }
        print("tags carried by: \(carried.sorted().joined(separator: ", "))")
        XCTAssertFalse(carried.isEmpty, "no container carried its tags — that cannot be right")
    }

    /// Genre and track are the two that a naive reader loses, because they are
    /// not common keys. If they come back from any container, the fallback
    /// chain is doing its job.
    func testGenreAndTrackSurviveWhereTheContainerCarriesThem() async throws {
        let samples = try Corpus.writeMedia(into: directory)
        try XCTSkipIf(samples.isEmpty, "ffmpeg not installed")

        var withGenre: [String] = []
        var withTrack: [String] = []
        for sample in samples {
            let facts = try await MetadataReader.readAll(sample.url)
            if facts.string(for: .genre) == Corpus.Tags.genre { withGenre.append(sample.name) }
            if facts.string(for: .track) == Corpus.Tags.track { withTrack.append(sample.name) }
        }

        print("genre read from: \(withGenre.sorted().joined(separator: ", "))")
        print("track read from: \(withTrack.sorted().joined(separator: ", "))")
        XCTAssertFalse(withGenre.isEmpty, "genre resolved from no container at all")
        XCTAssertFalse(withTrack.isEmpty, "track resolved from no container at all")
    }

    /// macOS declares no type for Matroska, so the SDK alone calls the second
    /// most common video container an unknown blob. The fallback fills that
    /// silence — and must never do more than that.
    func testUndeclaredContainersStillClassify() {
        XCTAssertFalse(
            UTType(filenameExtension: "mkv")?.isDeclared ?? false,
            "macOS now declares a type for mkv — the fallback row can go"
        )
        XCTAssertEqual(MediaKind(pathExtension: "mkv"), .video)
        XCTAssertEqual(MediaKind(pathExtension: "ape"), .audio)

        // A declared type always wins; the table is only ever a fallback.
        for (ext, _) in MediaKind.undeclared {
            if let type = UTType(filenameExtension: ext), type.isDeclared {
                XCTAssertEqual(
                    MediaKind(type: type, pathExtension: ext), MediaKind(type: type),
                    "\(ext) is declared now, so the fallback must not be reached"
                )
            }
        }
    }

    /// Video geometry, on a file whose dimensions are known because they were
    /// asked for on the command line.
    func testVideoGeometryMatchesWhatWasEncoded() async throws {
        let samples = try Corpus.writeMedia(into: directory)
        try XCTSkipIf(samples.isEmpty, "ffmpeg not installed")

        var checked = 0
        for sample in samples where sample.expectedKind == .video {
            let facts = try await MetadataReader.readAll(sample.url)
            guard facts.values[.videoWidth] != nil else { continue }
            XCTAssertEqual(facts.values[.videoWidth], .integer(Corpus.videoSize.width), "\(sample.name)")
            XCTAssertEqual(facts.values[.videoHeight], .integer(Corpus.videoSize.height), "\(sample.name)")
            XCTAssertEqual(facts.string(for: .resolution), "SD", "\(sample.name)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0, "no video file reported its dimensions")
    }

    /// Nothing in the corpus may throw, hang or return a wrong type, whatever
    /// the format.
    func testReadingTheWholeCorpusIsSafe() async throws {
        _ = Corpus.writeImages(into: directory)
        _ = try Corpus.writeMedia(into: directory)
        try Fixtures.writeText("plain", to: directory.appendingPathComponent("notes.txt"))
        #if canImport(PDFKit)
            try Fixtures.writePDF(to: directory.appendingPathComponent("manifest.pdf"))
        #endif

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )
        XCTAssertGreaterThan(urls.count, 10)

        let facts = await MetadataReader.read(urls, fields: Set(MetadataField.allCases))
        XCTAssertEqual(facts.count, urls.count)

        for result in facts {
            // Whatever the file, the name and size always answer.
            XCTAssertNotNil(result.values[.name], "\(result.url.lastPathComponent) has no name")
            XCTAssertNotNil(result.values[.size], "\(result.url.lastPathComponent) has no size")

            // And every value must match the type its field declares.
            for (field, value) in result.values {
                XCTAssertEqual(
                    value.kind, field.kind,
                    "\(result.url.lastPathComponent): \(field.key) is \(value.kind), declared \(field.kind)"
                )
            }
        }
    }
}
