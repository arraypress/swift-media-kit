//
//  HarmonicTests.swift
//  AudioTimbreTests
//
//  Chroma and chord naming, against chords built from known notes.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class ChromaTests: XCTestCase {

    private func chroma(_ samples: [Float]) -> PitchClassProfile {
        ChromaAnalysis.measure(samples, sampleRate: TestSignals.sampleRate)!
    }

    func testASingleNoteLightsItsOwnPitchClass() {
        // A440 is pitch class A, whatever octave it is played in.
        let profile = chroma(TestSignals.sine(hz: 440, seconds: 2))
        XCTAssertEqual(profile.ranked.first, "A")
        XCTAssertEqual(profile.strength(of: 9), 1.0, accuracy: 0.001)
    }

    func testTheSameNoteInThreeOctavesIsOneClass() {
        // The whole point of folding: register is discarded, pitch class is not.
        let low = chroma(TestSignals.sine(hz: 220, seconds: 2))
        let mid = chroma(TestSignals.sine(hz: 440, seconds: 2))
        let high = chroma(TestSignals.sine(hz: 880, seconds: 2))
        XCTAssertEqual(low.ranked.first, "A")
        XCTAssertEqual(mid.ranked.first, "A")
        XCTAssertEqual(high.ranked.first, "A")
    }

    func testAMajorTriadLightsItsThreeNotes() {
        // C major from middle C: C, E, G.
        let profile = chroma(TestSignals.chord(root: 60, intervals: [0, 4, 7]))
        XCTAssertEqual(Set(profile.dominant().prefix(3)), ["C", "E", "G"])
    }

    func testNoiseSpreadsAcrossEveryClassAndHasLowSalience() {
        let profile = chroma(TestSignals.whiteNoise(seconds: 2))
        // Noise puts energy in every class, so its strongest barely stands above its
        // middle. A chord's does — see the next case.
        XCTAssertLessThan(profile.salience, 6)
    }

    func testAChordStandsWellAboveItsOwnFloor() {
        let profile = chroma(TestSignals.chord(root: 60, intervals: [0, 4, 7]))
        XCTAssertGreaterThan(profile.salience, 6)
    }

    func testSalienceStaysFiniteForAPureTone() {
        // A single tone drives the median class to zero. Both the unbounded ratio and a
        // lower-percentile floor were tried and are unusable: the first is not encodable,
        // and the second measured past two million on real kicks, putting drums above
        // every pitched sound in the corpus.
        let kick = TestSignals.pitchGlide(from: 90, to: 45, tau: 0.1, seconds: 0.4)
        let salience = chroma(kick).salience
        XCTAssertTrue(salience.isFinite)
        XCTAssertLessThanOrEqual(salience, 10_000)
        XCTAssertNoThrow(try JSONEncoder().encode(chroma(kick)))
    }

    func testAChordSurvivesBroadbandNoiseUnderIt() {
        // What peak-picking is FOR, and the reason a clean synthetic chord cannot test it.
        // Each pitch class gathers bins from seven octaves, so a noise floor that is
        // negligible in any single bin is enormous once summed. Counting only local
        // maxima removes it; summing every bin lets it bury the chord.
        let chord = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let noisy = zip(chord, TestSignals.whiteNoise(seconds: 2, amplitude: 0.10, seed: 11))
            .map { $0 + $1 }
        let profile = chroma(noisy)
        XCTAssertEqual(Set(profile.dominant().prefix(3)), ["C", "E", "G"],
                       "the chord must still be the top three classes under noise")
        XCTAssertGreaterThan(profile.salience, 50, "and still stand well clear of its floor")
    }

    func testTheChordStillLeadsEvenWhenTheNoiseIsLouderThanIsReasonable() {
        // Salience does fall — measured 10,000 clean, 99 at 0.10, 4.9 at 0.25 — but the
        // ranking survives, which is the part a caller reads.
        let chord = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let noisy = zip(chord, TestSignals.whiteNoise(seconds: 2, amplitude: 0.25, seed: 11))
            .map { $0 + $1 }
        XCTAssertEqual(Set(chroma(noisy).dominant().prefix(3)), ["C", "E", "G"])
    }

    func testATonePreciselyBetweenTwoSemitonesIsIgnoredEntirely() {
        // What the raised-cosine weighting is for. A tone exactly halfway between A and A#
        // belongs to neither, and the weighting reaches zero there — measured, the profile
        // comes back identical to the chord alone even with the interloper at 0.8. Without
        // the weighting it votes at full strength for whichever class it is nearer and
        // takes the top slot.
        let chord = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let halfway = TestSignals.sine(hz: 440 * pow(2, 0.5 / 12), seconds: 2, amplitude: 0.8)

        let clean = chroma(chord)
        let muddied = chroma(zip(chord, halfway).map { $0 + $1 })
        XCTAssertEqual(Set(muddied.dominant().prefix(3)), ["C", "E", "G"])
        for i in 0..<12 {
            XCTAssertEqual(muddied.bins[i], clean.bins[i], accuracy: 0.02,
                           "\(PitchClassProfile.names[i]) should be untouched by it")
        }
    }

    func testATonePartwayBetweenSemitonesStillCountsForTheNearer() {
        // The other side of the same weighting: 25 cents sharp is a detuned A, not a
        // non-note, and it votes at half strength rather than nothing.
        let chord = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let sharp = TestSignals.sine(hz: 440 * pow(2, 0.25 / 12), seconds: 2, amplitude: 0.8)
        XCTAssertEqual(chroma(zip(chord, sharp).map { $0 + $1 }).ranked.first, "A")
    }

    func testALoudBriefChordOutweighsAQuietLongOne() {
        // Why frames are NOT normalised individually. One second of a loud C against three
        // of a barely-audible F: the C is what the passage sounds like. Normalising each
        // frame to its own peak first gives every frame one equal vote, so the quiet F
        // wins on duration — which is how a real four-bar loop came back with all twelve
        // classes lit and nothing findable in it.
        let loud = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 1)
        let quiet = TestSignals.chord(root: 65, intervals: [0, 4, 7], seconds: 3).map { $0 * 0.02 }

        // Measured both ways on this signal: raw magnitudes put F at 0.064 against C's
        // 1.000, per-frame normalisation puts it at 0.720. C ranks first either way — it
        // is the STRENGTH that carries the difference, and 0.720 would report the quiet
        // chord as a present, dominant pitch class when it is all but inaudible.
        let profile = chroma(loud + quiet)
        XCTAssertEqual(profile.ranked.first, "C")
        XCTAssertLessThan(profile.strength(of: 5), 0.3, "F is barely audible and must read so")
        XCTAssertFalse(profile.dominant().contains("F"),
                       "a chord at 2% amplitude is not a dominant pitch class")
    }

    func testSilenceIsRefusedRatherThanReturningAFlatProfile() {
        XCTAssertNil(ChromaAnalysis.measure(TestSignals.silence(seconds: 1),
                                            sampleRate: TestSignals.sampleRate))
    }

    func testTheProfileIsScaledSoTheStrongestClassIsOne() {
        let profile = chroma(TestSignals.chord(root: 60, intervals: [0, 4, 7]))
        XCTAssertEqual(profile.bins.max() ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(profile.bins.count, 12)
        XCTAssertTrue(profile.bins.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

final class HarmonyTests: XCTestCase {

    func testAnalysesAChordsPitchClassesEndToEnd() throws {
        let samples = TestSignals.chord(root: 62, intervals: [0, 3, 7])   // D minor
        let harmony = try HarmonicAnalyzer.analyze(channels: [samples],
                                                   sampleRate: TestSignals.sampleRate)
        XCTAssertEqual(Set(harmony.dominantPitchClasses.prefix(3)), ["D", "F", "A"])
        XCTAssertTrue(harmony.summary.contains("pitch classes"))
        XCTAssertTrue(harmony.summary.contains("salience"))
    }

    func testAKickIsReportedAsItsFundamentalAndNothingMore() throws {
        // The measurement that removed the chord namer. A kick is one strong low
        // fundamental, so it is the MOST salient thing in a sample library — nine of
        // twenty real kicks were confidently named "F" by a chord matcher. Reporting the
        // pitch class is true and useful; calling it a chord was not.
        let kick = TestSignals.pitchGlide(from: 90, to: 45, tau: 0.1, seconds: 0.4)
        let harmony = try HarmonicAnalyzer.analyze(channels: [kick],
                                                   sampleRate: TestSignals.sampleRate)
        XCTAssertFalse(harmony.dominantPitchClasses.isEmpty)
        XCTAssertTrue(harmony.summary.contains("pitch classes"))
        XCTAssertFalse(harmony.summary.lowercased().contains("chord"),
                       "nothing here may claim to have identified a chord")
    }

    func testSegmentsAreAnalysedIndependently() throws {
        // Two chords back to back: analysed whole they blur, analysed per segment they are
        // each themselves. This is the path a bar-by-bar chart would take, with the bar
        // boundaries coming from a beat tracker outside this library.
        let c = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let f = TestSignals.chord(root: 65, intervals: [0, 4, 7], seconds: 2)

        let bars = try HarmonicAnalyzer.analyze(channels: [c + f],
                                                sampleRate: TestSignals.sampleRate,
                                                segments: [0...2, 2...4])
        // The SET, not the order. F major is F A C, and C is both its fifth and F's own
        // third harmonic, so C can outrank the root — which is one concrete reason a
        // chroma cannot be read as a chord name without more information.
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(Set(bars[0].dominantPitchClasses.prefix(3)), ["C", "E", "G"])
        XCTAssertEqual(Set(bars[1].dominantPitchClasses.prefix(3)), ["F", "A", "C"])
    }

    func testSegmentsPastTheEndAreSkippedRatherThanCrashing() throws {
        // An INVERTED span cannot be passed at all — `5...4` traps inside ClosedRange
        // before this library sees it, so the parameter type does that validation.
        let samples = TestSignals.chord(root: 60, intervals: [0, 4, 7], seconds: 2)
        let bars = try HarmonicAnalyzer.analyze(channels: [samples],
                                                sampleRate: TestSignals.sampleRate,
                                                segments: [0...2, 10...12, 1.9...1.9])
        XCTAssertEqual(bars.count, 1, "one valid span, one past the end, one of zero length")
    }

    func testRoundTripsThroughJSON() throws {
        let samples = TestSignals.chord(root: 60, intervals: [0, 4, 7])
        let harmony = try HarmonicAnalyzer.analyze(channels: [samples],
                                                   sampleRate: TestSignals.sampleRate)
        let data = try JSONEncoder().encode(harmony)
        XCTAssertEqual(try JSONDecoder().decode(Harmony.self, from: data), harmony)
    }

    func testRefusesSilenceAndMalformedInput() {
        XCTAssertThrowsError(try HarmonicAnalyzer.analyze(
            channels: [TestSignals.silence(seconds: 1)], sampleRate: TestSignals.sampleRate))
        XCTAssertThrowsError(try HarmonicAnalyzer.analyze(channels: [], sampleRate: 44100))
        XCTAssertThrowsError(try HarmonicAnalyzer.analyze(channels: [[1, 2, 3]], sampleRate: 0))
    }
}
