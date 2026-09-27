//
//  EnvelopeTests.swift
//  AudioTimbreTests
//
//  Attack and decay, against a signal whose envelope is known in closed form.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class EnvelopeTests: XCTestCase {

    private func measure(_ samples: [Float]) -> Envelope.Shape {
        Envelope.measure(samples, sampleRate: TestSignals.sampleRate)
    }

    func testAttackLandsOnTheOnset() {
        let shape = measure(TestSignals.decayingSine(hz: 440, tau: 0.1, onset: 0.1, seconds: 1.5))
        XCTAssertEqual(shape.timeToPeakMs, 100, accuracy: 3)
        XCTAssertEqual(shape.attackMs ?? -1, 100, accuracy: 3, "a single hit's rise IS an attack")
        XCTAssertNil(shape.attackRejection)
    }

    func testASoundThatStartsAtFullLevelHasAnInstantAttack() {
        // Starting at the peak is an onset of about zero, not an absent one —
        // and it is distinguishable from a sound already under way, because
        // that one peaks somewhere in the middle instead.
        let shape = measure(TestSignals.decayingSine(hz: 440, tau: 0.1, onset: 0, seconds: 1.5))
        XCTAssertEqual(shape.timeToPeakMs, 0, accuracy: 3)
        XCTAssertEqual(shape.attackMs ?? -1, 0, accuracy: 3)
        XCTAssertNil(shape.attackRejection)
    }

    func testAPeakTooFarInIsNotAnOnset() {
        // Peaking three seconds into a four-second file: the loudest moment is
        // a fraction louder than the rest of a sound that was already playing.
        // That is the real pad-loop case.
        var flat = TestSignals.sine(hz: 440, seconds: 4, amplitude: 0.9)
        let rate = Int(TestSignals.sampleRate)
        for i in (3 * rate)..<(3 * rate + rate / 10) { flat[i] /= 0.9 }
        let shape = measure(flat)
        XCTAssertGreaterThan(shape.timeToPeakMs, 2500, "the raw figure is still reported")
        XCTAssertNil(shape.attackMs)
        XCTAssertEqual(shape.attackRejection, .peaksLate)
    }

    func testALoopThatIsStruckAgainHasNoSingleAttack() {
        // Four hits: each has an attack, the file does not. Reporting the first
        // one as "the attack" would describe a quarter of the sound.
        let hit = TestSignals.decayingSine(hz: 440, tau: 0.05, onset: 0.05, seconds: 0.5)
        let loop = hit + hit + hit + hit
        let shape = measure(loop)
        XCTAssertNil(shape.attackMs)
        XCTAssertEqual(shape.attackRejection, .reArticulates)
        XCTAssertEqual(shape.timeToPeakMs, 50, accuracy: 5, "the raw figure survives the refusal")
    }

    func testAnOnsetJustPastTheWindowIsStillAnAttack() {
        // A kick peaks around 27 ms, past a 20 ms window. Gating on the window
        // alone rejected it, and a kick's transient is the definition of an
        // attack — hence the horizon being a fraction of the file instead.
        let kick = TestSignals.decayingSine(hz: 60, tau: 0.08, onset: 0.025, seconds: 0.3)
        let shape = measure(kick)
        XCTAssertEqual(shape.attackMs ?? -1, 25, accuracy: 6)
        XCTAssertNil(shape.attackRejection)
    }

    func testAQuietTailDoesNotReadAsBeingStruckAgain() {
        // A one-shot whose decay wobbles must not trip the re-articulation test;
        // the threshold is 6 dB below the peak, and a tail is far under that.
        let shape = measure(TestSignals.decayingSine(hz: 440, tau: 0.08, onset: 0.05, seconds: 2))
        XCTAssertNotNil(shape.attackMs)
        XCTAssertNil(shape.attackRejection)
    }

    func testDecayMatchesTheTimeConstant() {
        // A level of e^(-t/tau) falls 60 dB after 60*ln(10)/20 = 6.908 time constants.
        for tau in [0.05, 0.1, 0.2] {
            let shape = measure(TestSignals.decayingSine(hz: 440, tau: tau, onset: 0.05, seconds: 3))
            let expected = TestSignals.decayMs(tau: tau)
            XCTAssertNotNil(shape.decayMs, "tau \(tau) must reach -60 dB inside 3 s")
            XCTAssertEqual(
                shape.decayMs!, expected, accuracy: expected * 0.05,
                "tau \(tau) should decay in \(expected) ms")
        }
    }

    func testASustainedToneReportsNoDecayRatherThanTheFileLength() {
        let shape = measure(TestSignals.sine(hz: 440, seconds: 2))
        XCTAssertNil(shape.decayMs, "it never fell 60 dB, and saying otherwise would invent a number")
        XCTAssertEqual(shape.attackMs ?? -1, 0, accuracy: 3, "an instant onset, not an absent one")
        XCTAssertEqual(shape.sustainRatio, 1.0, accuracy: 0.02)
    }

    func testSustainRatioSeparatesAPercussiveHitFromAHeldNote() {
        let held = measure(TestSignals.sine(hz: 440, seconds: 1.5))
        let hit = measure(TestSignals.decayingSine(hz: 440, tau: 0.02, onset: 0.05, seconds: 1.5))
        XCTAssertGreaterThan(held.sustainRatio, 0.95)
        XCTAssertLessThan(hit.sustainRatio, 0.10)
    }

    func testSignalsTooShortForTwoWindowsReturnZeroesRatherThanGuessing() {
        let shape = measure(TestSignals.sine(hz: 440, seconds: 0.005))
        XCTAssertEqual(shape.timeToPeakMs, 0)
        XCTAssertNil(shape.attackMs)
        XCTAssertNil(shape.decayMs)
        XCTAssertEqual(shape.sustainRatio, 0)
    }

    func testSilenceDoesNotDivideByZero() {
        let shape = measure(TestSignals.silence(seconds: 0.5))
        XCTAssertEqual(shape.timeToPeakMs, 0)
        XCTAssertNil(shape.attackMs)
        XCTAssertNil(shape.decayMs)
    }
}
