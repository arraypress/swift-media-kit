//
//  LoudnessTests.swift
//  AudioTimbreTests
//
//  Level, against values that can be worked out on paper.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class LoudnessTests: XCTestCase {

    func testPeakAndRmsOfAKnownSine() {
        // A sine of amplitude 0.5 peaks at -6.02 dBFS and has an RMS of 0.5/sqrt(2),
        // which is -9.03 dBFS. Both are arithmetic, not conventions.
        let (peak, rms) = Loudness.measure(TestSignals.sine(hz: 1000, seconds: 1, amplitude: 0.5))
        XCTAssertEqual(peak, -6.02, accuracy: 0.05)
        XCTAssertEqual(rms, -9.03, accuracy: 0.05)
    }

    func testFullScaleSquareReadsZeroOnBoth() {
        let square = [Float](repeating: 1.0, count: 1000)
        let (peak, rms) = Loudness.measure(square)
        XCTAssertEqual(peak, 0, accuracy: 0.001)
        XCTAssertEqual(rms, 0, accuracy: 0.001)
    }

    func testSilenceFloorsRatherThanReturningNegativeInfinity() {
        let (peak, rms) = Loudness.measure(TestSignals.silence(seconds: 0.1))
        XCTAssertEqual(peak, Loudness.silenceFloorDbfs)
        XCTAssertEqual(rms, Loudness.silenceFloorDbfs)
        XCTAssertTrue(peak.isFinite, "an infinite level cannot be encoded or displayed")
    }

    func testEmptyInputDoesNotCrash() {
        let (peak, rms) = Loudness.measure([])
        XCTAssertEqual(peak, Loudness.silenceFloorDbfs)
        XCTAssertEqual(rms, Loudness.silenceFloorDbfs)
    }
}
