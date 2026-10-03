//
//  FontSpecimenTests.swift
//  FontSpecimenTests
//
//  A real font file read without installing it, and the specimen's lines.
//
//  Created by David Sherlock on 10/3/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreText
import Foundation
import XCTest
@testable import FontSpecimen

final class FontSpecimenTests: XCTestCase {

    /// A font file every Mac has, copied so the test reads bytes from a path no font is
    /// registered at.
    private func copiedSystemFont() throws -> URL {
        let candidates = ["/System/Library/Fonts/Supplemental/Courier New.ttf", "/System/Library/Fonts/Monaco.ttf"]
        guard let source = candidates.first(where: FileManager.default.fileExists(atPath:)) else {
            throw XCTSkip("no known system font file on this machine")
        }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("specimen-\(UUID().uuidString).ttf")
        try FileManager.default.copyItem(atPath: source, toPath: copy.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: copy) }
        return copy
    }

    func testAFontFileGivesItsFaceAndLines() throws {
        let specimen = try XCTUnwrap(FontSpecimen(fileAt: try copiedSystemFont(), title: "Mono.ttf"))
        XCTAssertFalse(specimen.fullName.isEmpty)
        XCTAssertEqual(specimen.lines.first, FontSpecimen.Line(text: "Mono.ttf", size: 22, role: .title))
        XCTAssertEqual(specimen.lines.filter { $0.role == .glyphs }.count, 3)
        XCTAssertEqual(specimen.lines.filter { $0.role == .sample }.map(\.size), FontSpecimen.sampleSizes)
        XCTAssertEqual(specimen.lines.filter { $0.role == .label }.first?.text, "72 pt")
        XCTAssertEqual(CTFontGetSize(specimen.font(size: 30)), 30)
        XCTAssertEqual(CTFontCopyFullName(specimen.font(size: 12)) as String, specimen.fullName)
    }

    func testBytesThatAreNotAFontGiveNothing() throws {
        XCTAssertNil(FontSpecimen(data: Data("not a font".utf8), title: "x.ttf"))
        XCTAssertNil(FontSpecimen(fileAt: URL(fileURLWithPath: "/nonexistent/x.ttf")))
    }
}
