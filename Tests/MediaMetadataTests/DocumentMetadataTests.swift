//
//  DocumentMetadataTests.swift
//  MediaMetadataTests
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import MediaMetadata

#if canImport(PDFKit)
import PDFKit

final class DocumentMetadataTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.directory("document")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDocumentPropertiesRoundTrip() async throws {
        let url = directory.appendingPathComponent("manifest.pdf")
        try Fixtures.writePDF(to: url)

        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.kind, .document)
        XCTAssertEqual(facts.values[.pageCount], .integer(Fixtures.Document.pages))
        XCTAssertEqual(facts.string(for: .docTitle), Fixtures.Document.title)
        XCTAssertEqual(facts.string(for: .docAuthor), Fixtures.Document.author)
        XCTAssertEqual(facts.string(for: .docSubject), Fixtures.Document.subject)
        XCTAssertEqual(facts.values[.isEncrypted], .boolean(false))
    }

    /// A word processor writes A4 as 595.276 x 841.89, so an exact comparison
    /// names no paper at all.
    func testPageSizeIsNamedWithinTolerance() async throws {
        let url = directory.appendingPathComponent("manifest.pdf")
        try Fixtures.writePDF(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.string(for: .pageSize), "595x842 pt (A4)")
        XCTAssertEqual(PaperSize.describe(CGSize(width: 595.276, height: 841.89)), "595x842 pt (A4)")
        XCTAssertEqual(PaperSize.describe(CGSize(width: 612, height: 792)), "612x792 pt (US Letter)")
        XCTAssertEqual(PaperSize.describe(CGSize(width: 842, height: 595)), "842x595 pt (A4 landscape)")
        XCTAssertEqual(PaperSize.describe(CGSize(width: 300, height: 400)), "300x400 pt")
    }

    /// The info dictionary is not closed — a producer may write its own keys —
    /// so the raw reader takes whatever is there.
    func testRawCarriesTheWholeInfoDictionary() async throws {
        let url = directory.appendingPathComponent("manifest.pdf")
        try Fixtures.writePDF(to: url)
        let facts = try await MetadataReader.readEverything(url)

        XCTAssertEqual(facts.raw["pdf.pageCount"], .integer(Fixtures.Document.pages))
        XCTAssertEqual(facts.raw["pdf.Title"], .text(Fixtures.Document.title))
        XCTAssertNotNil(facts.raw["pdf.majorVersion"])
        XCTAssertEqual(facts.raw["pdf.allowsPrinting"], .boolean(true))
        XCTAssertEqual(facts.raw["pdf.pageSize"], .text("595x842 pt (A4)"))
    }

    /// A PDF is not an image, whatever `CGImageDestination` will write.
    func testPDFIsADocumentNotAnImage() async throws {
        let url = directory.appendingPathComponent("manifest.pdf")
        try Fixtures.writePDF(to: url)
        let facts = try await MetadataReader.readAll(url)

        XCTAssertEqual(facts.kind, .document)
        XCTAssertNil(facts.values[.camera])
        XCTAssertNil(facts.values[.duration])
    }
}

#endif
