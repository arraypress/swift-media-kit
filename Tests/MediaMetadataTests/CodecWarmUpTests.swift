//
//  CodecWarmUpTests.swift
//  MediaMetadataTests
//
//  The embedded HEIC decodes, so the warm-up actually exercises the decoder.
//
//  Created by David Sherlock on 10/3/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import ImageIO
import XCTest
@testable import MediaMetadata

final class CodecWarmUpTests: XCTestCase {
    func testTheEmbeddedHEICDecodes() throws {
        let data = try XCTUnwrap(Data(base64Encoded: CodecWarmUp.tinyHEIC))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.heic")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 16)
        CodecWarmUp.warmUp()
    }
}
