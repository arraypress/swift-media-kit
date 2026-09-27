//
//  FileSystemMetadataTests.swift
//  MediaMetadataTests
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import MediaMetadata

final class FileSystemMetadataTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.directory("filesystem")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - The cheap fields

    func testNamesAndSizesAreRead() async throws {
        let url = directory.appendingPathComponent("delivery notes.txt")
        try Fixtures.writeText("0123456789", to: url)

        let facts = try await MetadataReader.readFree(url)

        XCTAssertEqual(facts.string(for: .name), "delivery notes.txt")
        XCTAssertEqual(facts.string(for: .baseName), "delivery notes")
        XCTAssertEqual(facts.string(for: .ext), "txt")
        XCTAssertEqual(facts.values[.size], .bytes(10))
        XCTAssertEqual(facts.byteCount, 10)
        XCTAssertNotNil(facts.values[.created])
        XCTAssertNotNil(facts.values[.modified])
        // The kind is the system's own description of the type, whose wording varies by macOS
        // release and language ("Plain Text Document", "text").
        let systemKind = try url.resourceValues(forKeys: [.localizedTypeDescriptionKey]).localizedTypeDescription
        XCTAssertNotNil(systemKind)
        XCTAssertEqual(facts.string(for: .kind), systemKind)
    }

    func testRelativePathIsBuiltFromTheScanRoot() async throws {
        let nested = directory.appendingPathComponent("2026/June")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let url = nested.appendingPathComponent("shot.txt")
        try Fixtures.writeText("x", to: url)

        let facts = try await MetadataReader.read(url, fields: [.relativePath, .folder, .parentFolder], root: directory)

        XCTAssertEqual(facts.string(for: .relativePath), "2026/June/shot.txt")
        XCTAssertEqual(facts.string(for: .folder), "June")
        XCTAssertEqual(facts.string(for: .parentFolder), "2026")
    }

    /// A file outside the root it was given still has to produce something.
    func testRelativePathFallsBackWhenOutsideTheRoot() {
        let file = URL(fileURLWithPath: "/tmp/elsewhere/report.pdf")
        let root = URL(fileURLWithPath: "/Users/someone/Delivery")
        XCTAssertEqual(RelativePath.of(file, from: root), "report.pdf")
    }

    // MARK: - Checksums

    /// Checked against the published digests of "abc" rather than against
    /// this package's own output.
    func testChecksumsMatchPublishedVectors() async throws {
        let url = directory.appendingPathComponent("abc.txt")
        try Fixtures.writeText("abc", to: url)

        let facts = try await MetadataReader.read(url, fields: [.md5, .sha1, .sha256, .crc32])

        XCTAssertEqual(facts.string(for: .md5), "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(facts.string(for: .sha1), "a9993e364706816aba3e25717850c26c9cd0d89d")
        XCTAssertEqual(
            facts.string(for: .sha256),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(facts.string(for: .crc32), "352441c2")
    }

    /// Hashing is the one thing here that reads every byte, so it must never
    /// happen unless a checksum column was asked for.
    func testChecksumsAreNotComputedUnlessAsked() async throws {
        let url = directory.appendingPathComponent("abc.txt")
        try Fixtures.writeText("abc", to: url)

        let facts = try await MetadataReader.readAll(url)
        for field in MetadataField.fields(in: .checksum) {
            XCTAssertNil(facts.values[field], "\(field.key) was computed without being asked for")
        }
    }

    // MARK: - Raw

    func testRawCarriesPOSIXFactsResourceValuesDoNot() async throws {
        let url = directory.appendingPathComponent("abc.txt")
        try Fixtures.writeText("abc", to: url)

        let facts = try await MetadataReader.readEverything(url)

        XCTAssertNotNil(facts.raw["fs.owner"])
        XCTAssertNotNil(facts.raw["fs.permissions"])
        XCTAssertNotNil(facts.raw["fs.inode"])
        XCTAssertEqual(facts.raw["fs.fileSize"], .bytes(3))
        XCTAssertEqual(facts.raw["fs.isDirectory"], .boolean(false))
    }

    /// Asking for `directoryEntryCount` alongside anything else returns a
    /// result where *everything* is nil — silently, with no error. It cost an
    /// afternoon once; this makes it cost a test failure instead.
    func testDirectoryEntryCountPoisonsARequestSet() throws {
        let url = directory.appendingPathComponent("abc.txt")
        try Fixtures.writeText("abc", to: url)

        let alone = try url.resourceValues(forKeys: [.fileSizeKey])
        XCTAssertEqual(alone.fileSize, 3)

        let together = try url.resourceValues(forKeys: [.fileSizeKey, .directoryEntryCountKey])
        XCTAssertNil(together.fileSize, "Foundation has been fixed — the workaround can go")

        // And the reader must not be caught by it.
        XCTAssertFalse(FileSystemRaw.keys.contains(.directoryEntryCountKey))
    }

    /// The count is still reported for the thing it applies to.
    func testDirectoryEntryCountIsStillReportedForFolders() async throws {
        for index in 0..<3 {
            try Fixtures.writeText("x", to: directory.appendingPathComponent("f\(index).txt"))
        }
        let facts = try await MetadataReader.readEverything(directory)
        XCTAssertEqual(facts.raw["fs.directoryEntryCount"], .integer(3))
        XCTAssertNotNil(facts.raw["fs.isDirectory"], "and the rest of the values survived")
    }

    // MARK: - Reading many

    func testManyFilesComeBackInTheOrderTheyWereGiven() async throws {
        var urls: [URL] = []
        for index in 0..<40 {
            let url = directory.appendingPathComponent("file-\(index).txt")
            try Fixtures.writeText(String(repeating: "x", count: index), to: url)
            urls.append(url)
        }

        // The progress callback is `@Sendable` because it is called from the
        // task group, so the counter it feeds has to be safe to touch from
        // more than one of them.
        let progress = Counter()
        let facts = await MetadataReader.read(urls, fields: [.name, .size]) { done in
            progress.record(done)
        }

        XCTAssertEqual(facts.count, urls.count)
        XCTAssertEqual(progress.highest, urls.count, "progress should reach the total")
        for (index, result) in facts.enumerated() {
            XCTAssertEqual(result.string(for: .name), "file-\(index).txt")
            XCTAssertEqual(result.values[.size], .bytes(Int64(index)))
        }
    }

    /// A folder among the files must not stop the batch.
    func testUnreadableEntriesDoNotStopABatch() async throws {
        let good = directory.appendingPathComponent("good.txt")
        try Fixtures.writeText("x", to: good)
        let missing = directory.appendingPathComponent("not-there.txt")

        let facts = await MetadataReader.read([good, missing], fields: [.name, .size])

        XCTAssertEqual(facts.count, 2)
        XCTAssertEqual(facts[0].string(for: .name), "good.txt")
        XCTAssertTrue(facts[1].isEmpty, "a missing file yields an empty row, not a wrong one")
    }

    func testMissingFileThrows() async {
        let missing = directory.appendingPathComponent("not-there.txt")
        do {
            _ = try await MetadataReader.read(missing, fields: [.name])
            XCTFail("expected a throw")
        } catch let error as MetadataError {
            XCTAssertEqual(error, .notFound(missing.path))
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testDirectoriesClassifyAsFolders() async throws {
        let facts = try await MetadataReader.readFree(directory)
        XCTAssertEqual(facts.kind, .folder)
        XCTAssertEqual(facts.kind.sources, [.fileSystem, .derived])
    }
}

/// A counter several tasks may report into.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func record(_ reached: Int) {
        lock.lock()
        value = max(value, reached)
        lock.unlock()
    }

    var highest: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
