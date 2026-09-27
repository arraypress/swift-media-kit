//
//  TimbreTests.swift
//  AudioTimbreTests
//
//  The whole analysis end to end, and the contracts a caller depends on.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class TimbreTests: XCTestCase {

    private func analyze(_ channels: [[Float]]) throws -> Timbre {
        try TimbreAnalyzer.analyze(channels: channels, sampleRate: TestSignals.sampleRate)
    }

    func testAnalysesAPluckLikeOneShotCorrectly() throws {
        let pluck = TestSignals.harmonicDecay(fundamental: 440, tau: 0.15, onset: 0.005, seconds: 2)
        let timbre = try analyze([pluck])

        XCTAssertEqual(timbre.duration, 2.0, accuracy: 0.01)
        XCTAssertEqual(timbre.channels, 1)
        XCTAssertNil(timbre.stereo, "a mono file has no stereo image to report")

        // 1/n harmonics at 440, 880, 1320, 1760 put the centroid near 845 Hz — above the
        // fundamental, which is where a real pitched sound's centroid sits.
        XCTAssertEqual(timbre.brightness, .warm)
        XCTAssertEqual(timbre.spectralCentroidHz, 845, accuracy: 120)
        XCTAssertEqual(timbre.texture, .tonal)
        XCTAssertEqual(
            timbre.pitch?.name, "A4",
            "the fundamental, not the centroid it sits below")

        XCTAssertLessThan(timbre.attackMs ?? 999, 20)
        XCTAssertEqual(timbre.decayMs ?? 0, TestSignals.decayMs(tau: 0.15), accuracy: 60)
    }

    func testAnalysesAHatLikeOneShotAsAiryNoisyAndUnpitched() throws {
        let hat = zip(
            TestSignals.whiteNoise(seconds: 0.12, seed: 9),
            0..<Int(0.12 * TestSignals.sampleRate)
        ).map { sample, i -> Float in
            sample * Float(exp(-Double(i) / (0.01 * TestSignals.sampleRate)))
        }
        let timbre = try analyze([hat])

        XCTAssertEqual(timbre.texture, .noisy)
        XCTAssertEqual(timbre.brightness, .airy)
        XCTAssertNil(timbre.pitch)
        XCTAssertNotNil(timbre.pitchRejection)
    }

    func testStereoFilesCarryAnImageAndMonoFilesDoNot() throws {
        let left = TestSignals.sine(hz: 440, seconds: 0.5)
        let right = TestSignals.sine(hz: 440, seconds: 0.5)
        XCTAssertNotNil(try analyze([left, right]).stereo)
        XCTAssertNil(try analyze([left]).stereo)
    }

    func testASubFrameOneShotIsAnalysedRatherThanRefused() throws {
        // 40 ms — under Apple's classifier window, under one preferred FFT frame, and the
        // exact case this library exists for.
        let short = TestSignals.decayingSine(hz: 1000, tau: 0.01, onset: 0, seconds: 0.04)
        let timbre = try analyze([short])
        XCTAssertEqual(timbre.duration, 0.04, accuracy: 0.005)
        XCTAssertGreaterThan(timbre.spectralCentroidHz, 0)
        XCTAssertGreaterThan(timbre.peakDbfs, -20)
    }

    func testALoopReportsItsPeakWithoutCallingItAnAttack() throws {
        // The finding that moved this: a real 5.65 s pad loop measured
        // "attack 3040 ms", describing one bar being marginally louder.
        let hit = TestSignals.decayingSine(hz: 440, tau: 0.05, onset: 0.05, seconds: 0.5)
        let timbre = try analyze([hit + hit + hit + hit])
        XCTAssertNil(timbre.attackMs)
        XCTAssertEqual(timbre.attackRejection, .reArticulates)
        XCTAssertGreaterThan(timbre.timeToPeakMs, 0)
        XCTAssertTrue(timbre.summary.contains("not an attack"))
        XCTAssertTrue(timbre.summary.contains("reArticulates"))
    }

    func testEveryWordShipsBesideItsNumber() throws {
        let timbre = try analyze([TestSignals.sine(hz: 1000, seconds: 1)])
        XCTAssertEqual(
            timbre.brightness, Brightness.of(centroidHz: timbre.spectralCentroidHz),
            "the word must be derivable from the number it travels with")
        XCTAssertEqual(timbre.texture, Texture.of(flatness: timbre.spectralFlatness))
    }

    func testPitchAndItsRejectionAreMutuallyExclusive() throws {
        let pitched = try analyze([TestSignals.sine(hz: 440, seconds: 1)])
        XCTAssertNotNil(pitched.pitch)
        XCTAssertNil(pitched.pitchRejection)

        let unpitched = try analyze([TestSignals.whiteNoise(seconds: 1)])
        XCTAssertNil(unpitched.pitch)
        XCTAssertNotNil(unpitched.pitchRejection)
    }

    func testSummaryIsDeterministicAndCarriesTheFigures() throws {
        let timbre = try analyze([TestSignals.sine(hz: 1000, seconds: 1)])
        let summary = timbre.summary

        XCTAssertEqual(summary, timbre.summary, "the same analysis must read the same way twice")
        XCTAssertTrue(summary.contains("warm"))
        XCTAssertTrue(summary.contains("centroid"))
        XCTAssertTrue(summary.contains("flatness"))
        XCTAssertTrue(summary.contains("peak"))
        XCTAssertTrue(summary.contains("RMS"))
        // Commas separate clauses here; what must never appear is a comma INSIDE a number,
        // which is what a locale-formatted float would produce and what would break any
        // caller parsing the line back.
        XCTAssertNil(
            summary.range(of: #"\d,\d"#, options: .regularExpression),
            "numbers must not be locale-formatted")
    }

    func testSummaryExplainsAnAbsenceRatherThanOmittingIt() throws {
        let held = try analyze([TestSignals.sine(hz: 440, seconds: 2)])
        XCTAssertNil(held.decayMs)
        XCTAssertTrue(held.summary.contains("no decay to -60 dB"))

        let noise = try analyze([TestSignals.whiteNoise(seconds: 1)])
        XCTAssertTrue(noise.summary.contains("no pitch"))
        XCTAssertTrue(noise.summary.contains(PitchRejection.lowConfidence.rawValue))
    }

    func testRoundTripsThroughJSON() throws {
        let original = try analyze([
            TestSignals.sine(hz: 440, seconds: 0.5),
            TestSignals.sine(hz: 440, seconds: 0.5),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Timbre.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.summary, decoded.summary)
    }

    func testRefusesMalformedInput() {
        XCTAssertThrowsError(try TimbreAnalyzer.analyze(channels: [], sampleRate: 44100))
        XCTAssertThrowsError(try TimbreAnalyzer.analyze(channels: [[]], sampleRate: 44100))
        XCTAssertThrowsError(try TimbreAnalyzer.analyze(channels: [[1, 2, 3], [1, 2]], sampleRate: 44100))
        XCTAssertThrowsError(try TimbreAnalyzer.analyze(channels: [[1, 2, 3]], sampleRate: 0))
        XCTAssertThrowsError(try analyze([TestSignals.silence(seconds: 0.5)])) { error in
            XCTAssertEqual(error as? AudioTimbreError, .silent)
        }
    }

    func testMissingFileNamesItself() {
        let url = URL(fileURLWithPath: "/nonexistent/nothing.wav")
        XCTAssertThrowsError(try TimbreAnalyzer.analyze(fileAt: url)) { error in
            XCTAssertEqual(error as? AudioTimbreError, .fileNotFound(url))
        }
    }
}
