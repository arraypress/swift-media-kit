//
//  StereoTests.swift
//  AudioTimbreTests
//
//  Correlation and Side/Mid, against channel pairs whose relationship is constructed.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class StereoTests: XCTestCase {

    func testIdenticalChannelsAreFullyCorrelatedAndHaveNoSide() {
        let mono = TestSignals.sine(hz: 440, seconds: 0.5)
        let image = StereoAnalysis.measure(left: mono, right: mono)!
        XCTAssertEqual(image.correlation, 1.0, accuracy: 1e-6)
        XCTAssertEqual(image.sideMidDb, Loudness.silenceFloorDbfs,
                       "dual mono has no Side signal at all")
        XCTAssertTrue(image.survivesMonoSum)
    }

    func testInvertedChannelsCancelOnSum() {
        let left = TestSignals.sine(hz: 440, seconds: 0.5)
        let right = left.map { -$0 }
        let image = StereoAnalysis.measure(left: left, right: right)!
        XCTAssertEqual(image.correlation, -1.0, accuracy: 1e-6)
        XCTAssertFalse(image.survivesMonoSum, "this file disappears when summed to mono")
    }

    func testIndependentChannelsAreUncorrelated() {
        let left = TestSignals.whiteNoise(seconds: 1, seed: 1)
        let right = TestSignals.whiteNoise(seconds: 1, seed: 2)
        let image = StereoAnalysis.measure(left: left, right: right)!
        XCTAssertEqual(image.correlation, 0, accuracy: 0.05)
        XCTAssertEqual(image.sideMidDb, 0, accuracy: 1.0,
                       "with nothing shared, Side and Mid carry the same energy")
    }

    func testPartialWidthSitsBetweenTheTwoExtremes() {
        let common = TestSignals.sine(hz: 440, seconds: 1)
        let difference = TestSignals.whiteNoise(seconds: 1, amplitude: 0.2, seed: 7)
        let left = zip(common, difference).map { $0 + $1 }
        let right = zip(common, difference).map { $0 - $1 }

        let image = StereoAnalysis.measure(left: left, right: right)!
        XCTAssertGreaterThan(image.correlation, 0.5)
        XCTAssertLessThan(image.correlation, 1.0)
        XCTAssertLessThan(image.sideMidDb, 0, "less Side than Mid")
        XCTAssertGreaterThan(image.sideMidDb, Loudness.silenceFloorDbfs)
    }

    func testMismatchedOrEmptyChannelsAreRefused() {
        XCTAssertNil(StereoAnalysis.measure(left: [1, 2, 3], right: [1, 2]))
        XCTAssertNil(StereoAnalysis.measure(left: [], right: []))
    }
}
