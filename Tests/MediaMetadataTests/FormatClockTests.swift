//
//  FormatClockTests.swift
//  MediaMetadataTests
//
//  A player's clock: minutes and seconds, hours when there are some, a dash for nonsense.
//
//  Created by David Sherlock on 10/21/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import MediaMetadata

/// `Format.clock(_:)`.
final class FormatClockTests: XCTestCase {
    func testTheClockReadsAsAPlayerShowsIt() {
        XCTAssertEqual(Format.clock(0), "0:00")
        XCTAssertEqual(Format.clock(102.4), "1:42")
        XCTAssertEqual(Format.clock(59.6), "1:00", "rounded to the second")
        XCTAssertEqual(Format.clock(3723), "1:02:03")
    }

    func testAValueThatIsNotADurationIsADash() {
        for bad in [-1, .nan, .infinity] { XCTAssertEqual(Format.clock(bad), "–:––") }
    }
}
