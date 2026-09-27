//
//  TestSignals.swift
//  AudioTimbreTests
//
//  Signals whose answers are known before they are measured.
//
//  This is the whole reason the measurements take `[[Float]]` rather than a file URL. A
//  440 Hz sine has a spectral centroid of 440 Hz, a flatness of nearly zero and a pitch of
//  A4 — not approximately, by construction. An exponential with a 100 ms time constant
//  reaches −60 dB after 6.908 time constants, which is arithmetic rather than opinion. A
//  test suite built on real audio files can only ever assert that today's numbers match
//  yesterday's; these assert that the numbers are RIGHT.
//
//  The reference implementation this library borrows its bucket boundaries from was
//  validated, in its author's own words, as "a sanity check, not a rigorous evaluation"
//  against five one-shots. This is the part that can be done better.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

enum TestSignals {

    static let sampleRate = 44_100.0

    /// A pure sine.
    static func sine(hz: Double, seconds: Double, amplitude: Float = 1.0,
                     sampleRate: Double = sampleRate) -> [Float] {
        let count = Int(seconds * sampleRate)
        let step = 2 * Double.pi * hz / sampleRate
        return (0..<count).map { amplitude * Float(sin(step * Double($0))) }
    }

    /// Uniform white noise from a fixed seed, so a run is reproducible.
    static func whiteNoise(seconds: Double, amplitude: Float = 1.0, seed: UInt64 = 42,
                           sampleRate: Double = sampleRate) -> [Float] {
        var generator = SeededGenerator(seed: seed)
        let count = Int(seconds * sampleRate)
        return (0..<count).map { _ in Float.random(in: -amplitude...amplitude, using: &generator) }
    }

    /// Digital silence.
    static func silence(seconds: Double, sampleRate: Double = sampleRate) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * sampleRate))
    }

    /// Silence, then a sine decaying as `e^(-t/tau)`.
    ///
    /// Its envelope is known exactly: the peak sits at `onset`, and the level falls 60 dB
    /// after `6.908 * tau` seconds — `60 * ln(10) / 20` time constants.
    static func decayingSine(hz: Double, tau: Double, onset: Double, seconds: Double,
                             amplitude: Float = 1.0, sampleRate: Double = sampleRate) -> [Float] {
        let count = Int(seconds * sampleRate)
        let onsetSample = Int(onset * sampleRate)
        let step = 2 * Double.pi * hz / sampleRate
        return (0..<count).map { i in
            guard i >= onsetSample else { return 0 }
            let t = Double(i - onsetSample) / sampleRate
            return amplitude * Float(exp(-t / tau) * sin(step * Double(i - onsetSample)))
        }
    }

    /// A decaying tone with harmonics, as a plucked string or a synth patch has.
    ///
    /// Amplitudes follow `1/n`, so the spectral centroid lands ABOVE the fundamental —
    /// which is the normal arrangement for pitched material and the one the pitch gate is
    /// built around. A bare sine is the unusual case: its centroid IS its fundamental.
    static func harmonicDecay(fundamental: Double, harmonics: Int = 4, tau: Double,
                              onset: Double, seconds: Double,
                              sampleRate: Double = sampleRate) -> [Float] {
        let count = Int(seconds * sampleRate)
        let onsetSample = Int(onset * sampleRate)
        return (0..<count).map { i in
            guard i >= onsetSample else { return 0 }
            let t = Double(i - onsetSample) / sampleRate
            var value = 0.0
            for n in 1...harmonics {
                value += sin(2 * .pi * fundamental * Double(n) * t) / Double(n)
            }
            return Float(value * exp(-t / tau) / 2)
        }
    }

    /// A decaying tone whose pitch falls as it goes — the shape of a kick drum.
    ///
    /// Its period is never constant, so a long analysis window contains no single one.
    static func pitchGlide(from startHz: Double, to endHz: Double, tau: Double,
                           seconds: Double, sampleRate: Double = sampleRate) -> [Float] {
        let count = Int(seconds * sampleRate)
        var phase = 0.0
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let progress = min(1.0, t / seconds)
            let hz = startHz + (endHz - startHz) * progress
            phase += 2 * .pi * hz / sampleRate
            return Float(sin(phase) * exp(-t / tau))
        }
    }

    /// A sustained chord: one sine per note, each with a couple of harmonics so it looks
    /// like an instrument rather than a test tone.
    ///
    /// - Parameters:
    ///   - root: MIDI note number of the root, 60 = middle C.
    ///   - intervals: semitones above the root.
    static func chord(root: Int, intervals: [Int], seconds: Double = 2,
                      sampleRate: Double = sampleRate) -> [Float] {
        let count = Int(seconds * sampleRate)
        var out = [Float](repeating: 0, count: count)
        for interval in intervals {
            let hz = 440.0 * pow(2.0, (Double(root + interval) - 69.0) / 12.0)
            // 1/n harmonics, as a real voice has — and the reason a chroma of a real chord
            // is never as clean as its template.
            for harmonic in 1...3 {
                let frequency = hz * Double(harmonic)
                guard frequency < sampleRate / 2 else { continue }
                let step = 2 * Double.pi * frequency / sampleRate
                let amplitude = Float(1.0 / Double(harmonic)) / Float(intervals.count)
                for i in 0..<count { out[i] += amplitude * Float(sin(step * Double(i))) }
            }
        }
        let peak = out.map(abs).max() ?? 1
        return peak > 0 ? out.map { $0 / peak } : out
    }

    /// How long a decay of this time constant takes to fall 60 dB, in milliseconds.
    static func decayMs(tau: Double) -> Double { 60 * log(10.0) / 20 * tau * 1000 }

    /// Add a constant offset to every sample.
    static func offset(_ samples: [Float], by dc: Float) -> [Float] {
        samples.map { $0 + dc }
    }
}

/// SplitMix64 — a small, fast, well-distributed generator, here only so that noise is the
/// same noise on every run. A flaky test that fails one run in twenty teaches nothing.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
