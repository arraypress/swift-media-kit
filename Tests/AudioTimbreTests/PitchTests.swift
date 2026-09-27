//
//  PitchTests.swift
//  AudioTimbreTests
//
//  The estimator, and the two gates that are the only reason to trust it.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class PitchTests: XCTestCase {

    private func estimate(_ samples: [Float], centroidHz: Double) -> PitchEstimator.Estimate {
        PitchEstimator.estimate(samples, sampleRate: TestSignals.sampleRate, centroidHz: centroidHz)
    }

    func testFindsTheFundamentalOfASine() {
        let result = estimate(TestSignals.sine(hz: 440, seconds: 1), centroidHz: 440)
        XCTAssertEqual(result.pitch?.name, "A4")
        XCTAssertEqual(result.pitch?.midi, 69)
        XCTAssertEqual(result.pitch?.frequencyHz ?? 0, 440, accuracy: 3)
        XCTAssertGreaterThan(result.confidence, 0.95)
        XCTAssertNil(result.rejection)
    }

    func testNamesNotesAcrossTheRange() {
        // Lag quantisation is coarser at high frequencies — 44,100 / 1,000 Hz is 44.1
        // samples — so the named note matters more than the exact Hz.
        let cases: [(Double, String)] = [(110, "A2"), (220, "A3"), (523.25, "C5"), (880, "A5")]
        for (hz, name) in cases {
            let result = estimate(TestSignals.sine(hz: hz, seconds: 1), centroidHz: hz)
            XCTAssertEqual(result.pitch?.name, name, "a \(hz) Hz sine is \(name)")
        }
    }

    func testRejectsNoiseButStillReportsHowConfidentItWas() {
        let result = estimate(TestSignals.whiteNoise(seconds: 1), centroidHz: 11_000)
        XCTAssertNil(result.pitch)
        XCTAssertEqual(result.rejection, .lowConfidence)
        XCTAssertLessThan(result.confidence, PitchEstimator.minimumConfidence)
        XCTAssertGreaterThanOrEqual(result.confidence, 0,
                                    "the confidence is a fact whether or not the estimate survived")
    }

    func testTheCentroidGateRejectsATransientArtifact() {
        // The documented kick failure: a strong periodic peak far above where the energy
        // actually sits. The signal is unambiguously periodic at 440 Hz and would pass
        // every other test; only the gate can catch it.
        let result = estimate(TestSignals.sine(hz: 440, seconds: 1), centroidHz: 100)
        XCTAssertNil(result.pitch, "440 Hz is 4.4x a 100 Hz centroid and cannot be the fundamental")
        XCTAssertEqual(result.rejection, .aboveCentroid)
        XCTAssertGreaterThan(result.confidence, 0.95,
                             "it was confident and still wrong — that is the point of the gate")
    }

    func testTheGateAllowsAFundamentalBelowTheCentroid() {
        // The other side of the same gate: harmonic content puts the centroid above the
        // fundamental, which must not be treated as suspicious.
        let result = estimate(TestSignals.sine(hz: 220, seconds: 1), centroidHz: 900)
        XCTAssertEqual(result.pitch?.name, "A3")
        XCTAssertNil(result.rejection)
    }

    func testAShortSignalNarrowsTheSearchRatherThanRefusing() {
        // 500 samples is 11 ms — too short to hold two periods of 20 Hz, but eleven
        // periods of 440 Hz. The lowest detectable pitch rises; the answer does not
        // disappear. Refusing here would throw away every short one-shot.
        let result = estimate(TestSignals.sine(hz: 440, seconds: 500 / TestSignals.sampleRate),
                              centroidHz: 440)
        XCTAssertEqual(result.pitch?.name, "A4")
    }

    func testRefusesASignalTooShortToSearchAnythingAtAll() {
        // 40 samples cannot hold two periods of even the highest pitch searched.
        let result = estimate(TestSignals.sine(hz: 1000, seconds: 40 / TestSignals.sampleRate),
                              centroidHz: 1000)
        XCTAssertEqual(result.rejection, .tooShortForLowestPitch)
    }

    func testFindsASubBassFundamentalBelowTheOldFloor() {
        // The real-audio regression: a 32.7 Hz sub (C1) sat outside the inherited 50 Hz
        // search range, so its correlation curve had no peak in range at all and the
        // sample read as unpitched.
        let result = estimate(TestSignals.sine(hz: 32.7, seconds: 1), centroidHz: 60)
        XCTAssertEqual(result.pitch?.name, "C1")
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testTheShortWindowReportsTheAttackPitchOfAGlidingDrum() {
        // A kick's pitch falls as it decays, so the window length decides which part of
        // the glide is reported. Measured on this signal: the 50 ms rung reads 151.5 Hz,
        // close to where the attack actually sits, while 150 ms alone drifts to 139.6 as
        // it averages further down the slide. Taking the shortest window that answers is
        // what keeps the figure attached to the part of the sound a listener pitches.
        let kick = TestSignals.pitchGlide(from: 160, to: 40, tau: 0.30, seconds: 0.35)
        let result = estimate(kick, centroidHz: 200)
        XCTAssertNotNil(result.pitch)
        XCTAssertEqual(result.pitch?.frequencyHz ?? 0, 151.5, accuracy: 5,
                       "the long window alone lands near 139.6 Hz")
    }

    func testNoPeakReportsNoConfidenceRatherThanTheBoundaryCorrelation() {
        // With no interior maximum the tallest correlation sits at the shortest lag
        // searched, which says nothing about any period. Reporting it as confidence would
        // be a number that looks like evidence and is not.
        let sweep = TestSignals.pitchGlide(from: 1200, to: 60, tau: 5, seconds: 1)
        let result = estimate(sweep, centroidHz: 10)
        if result.rejection == .noPeak {
            XCTAssertEqual(result.confidence, 0)
        }
    }

    func testPitchNamesAndMidiNumbers() {
        XCTAssertEqual(Pitch(frequencyHz: 440)?.name, "A4")
        XCTAssertEqual(Pitch(frequencyHz: 440)?.midi, 69)
        XCTAssertEqual(Pitch(frequencyHz: 261.6256)?.name, "C4")
        XCTAssertEqual(Pitch(frequencyHz: 261.6256)?.midi, 60)
        XCTAssertEqual(Pitch(frequencyHz: 27.5)?.name, "A0")
        XCTAssertNil(Pitch(frequencyHz: 0))
        XCTAssertNil(Pitch(frequencyHz: -100))
    }

    func testCentsReportHowFarOffTheNoteTheMeasurementSat() {
        XCTAssertEqual(Pitch(frequencyHz: 440)?.centsFromNote ?? 99, 0, accuracy: 0.01)
        // A quarter of a semitone sharp of A4.
        let sharp = Pitch(frequencyHz: 440 * pow(2, 0.25 / 12))
        XCTAssertEqual(sharp?.midi, 69)
        XCTAssertEqual(sharp?.centsFromNote ?? 0, 25, accuracy: 0.5)
    }
}
