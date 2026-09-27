//
//  Envelope.swift
//  AudioTimbre
//
//  How a sound moves over time: how fast it arrives, how long it takes to leave.
//
//  TIME-TO-PEAK IS NOT ALWAYS AN ATTACK, and this is the only place that can tell. On a
//  one-shot the loudest moment is the transient at the front, so the two are the same
//  thing. On a loop the loudest moment is wherever the arrangement peaked — a real
//  5.65-second pad measured "attack 3040 ms", which is true as a time-to-peak and
//  nonsense as an attack. So the raw figure is always reported under its own name and the
//  word is gated: a signal earns it by rising to its peak from below, and by not being
//  struck again afterwards. See ``AttackRejection``.
//
//  THE WINDOW AND THE HOP ARE DIFFERENT SIZES, and that is the whole design. A short
//  window gives fine timing but a useless reading on bass material — 10 ms is 0.4 of a
//  cycle at 40 Hz, so the "envelope" of a sub oscillates with the waveform itself. A long
//  window is stable and smears a 4 ms transient into nothing. So the window is 20 ms
//  (one full cycle at 50 Hz) and it advances 1 ms at a time, giving millisecond attack
//  resolution off a level reading that is actually steady.
//
//  The overlap costs nothing: a prefix sum of squares makes any window's energy a single
//  subtraction, so the whole envelope is one pass over the signal regardless of how far
//  the windows overlap.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Attack, decay and sustain measurement.
public enum Envelope {

    /// The RMS window, in seconds. One cycle of 50 Hz.
    public static let windowSeconds = 0.020

    /// How far the window advances between readings, in seconds.
    public static let hopSeconds = 0.001

    /// How far below the peak still counts as "sustaining", in dB.
    public static let sustainThresholdDb = -12.0

    /// How far below its peak a signal must begin for the climb to that peak to count as
    /// an attack. Starting above this means the sound is already under way and there is
    /// no rise to time.
    public static let riseThresholdDb = -12.0

    /// How far into a file an onset may sit and still be called one, as a fraction of the
    /// file's length.
    ///
    /// A judgement, like ``Brightness``'s boundaries; ``Shape/timeToPeakMs`` always ships beside
    /// it. Real one-shots peak within 10% (kick, clap, hat, pluck, snare); pads, lead loops and
    /// swells peak at 25% or later.
    public static let onsetHorizon = 0.25

    /// How close to its peak a signal may return, after having decayed away from it,
    /// before it is treated as having been struck again.
    ///
    /// Looser than ``riseThresholdDb`` on purpose: a decaying one-shot with noise in its
    /// tail must not read as re-articulating, while a second real hit lands far nearer
    /// the peak than this.
    public static let reArticulationThresholdDb = -6.0

    /// How far below the peak counts as decayed, in dB. The usual T60 convention.
    public static let decayThresholdDb = -60.0

    /// The measured shape of one signal.
    public struct Shape: Hashable, Sendable {
        /// Milliseconds from the start of the signal to its loudest window.
        ///
        /// Always measured, and always means exactly this. Whether it is an *attack* is a
        /// separate question — see ``attackMs``.
        public let timeToPeakMs: Double
        /// ``timeToPeakMs``, but only when the signal rose to a single peak and was not
        /// struck again. `nil` otherwise.
        public let attackMs: Double?
        /// Why ``attackMs`` is absent, or `nil` when it is present.
        public let attackRejection: AttackRejection?
        /// Milliseconds from the loudest window until the level drops 60 dB, or `nil`
        /// when the signal ends while still above that.
        public let decayMs: Double?
        /// Fraction of windows within 12 dB of the peak, 0…1.
        public let sustainRatio: Double
    }

    /// Measure a signal's envelope.
    ///
    /// - Parameters:
    ///   - samples: mono samples.
    ///   - sampleRate: samples per second; must be positive.
    /// - Returns: a zeroed shape when the signal is too short to hold two windows.
    public static func measure(_ samples: [Float], sampleRate: Double) -> Shape {
        guard sampleRate > 0, !samples.isEmpty else {
            return Shape(
                timeToPeakMs: 0, attackMs: nil, attackRejection: .peaksLate,
                decayMs: nil, sustainRatio: 0)
        }

        let window = max(1, min(samples.count, Int(windowSeconds * sampleRate)))
        let hop = max(1, Int(hopSeconds * sampleRate))
        let readings = (samples.count - window) / hop + 1
        guard readings >= 2 else {
            return Shape(
                timeToPeakMs: 0, attackMs: nil, attackRejection: .peaksLate,
                decayMs: nil, sustainRatio: 0)
        }

        // Prefix sums of squares: energy over any span is one subtraction.
        var prefix = [Double](repeating: 0, count: samples.count + 1)
        for i in 0..<samples.count {
            let value = Double(samples[i])
            prefix[i + 1] = prefix[i] + value * value
        }

        var levels = [Double](repeating: 0, count: readings)
        for r in 0..<readings {
            let start = r * hop
            levels[r] = ((prefix[start + window] - prefix[start]) / Double(window)).squareRoot()
        }

        guard let peak = levels.max(), peak > 0 else {
            return Shape(
                timeToPeakMs: 0, attackMs: nil, attackRejection: .peaksLate,
                decayMs: nil, sustainRatio: 0)
        }
        let peakIndex = levels.firstIndex(of: peak) ?? 0

        let hopMs = hopSeconds * 1000
        let timeToPeakMs = Double(peakIndex) * hopMs
        // An onset sits at the start. The floor of one window is there because a peak
        // inside the first window cannot have its rise resolved at all — the window is
        // wider than the onset — and without it a pluck starting 5 ms into a two-second
        // file fails purely because a 20 ms window smeared silence and transient together.
        let horizon = max(Double(window), Double(samples.count) * onsetHorizon)
        let peakIsAnOnset = Double(peakIndex * hop) <= horizon
        let rejection = attackRejection(
            levels, peak: peak, peakIndex: peakIndex,
            peakIsAnOnset: peakIsAnOnset)

        let decayFloor = peak * pow(10, decayThresholdDb / 20)
        var decayMs: Double?
        if peakIndex < readings {
            for r in peakIndex..<readings where levels[r] <= decayFloor {
                decayMs = Double(r - peakIndex) * hopMs
                break
            }
        }

        let sustainFloor = peak * pow(10, sustainThresholdDb / 20)
        let sustaining = levels.reduce(into: 0) { count, level in
            if level > sustainFloor { count += 1 }
        }
        let sustainRatio = Double(sustaining) / Double(readings)

        return Shape(
            timeToPeakMs: timeToPeakMs,
            attackMs: rejection == nil ? timeToPeakMs : nil,
            attackRejection: rejection,
            decayMs: decayMs,
            sustainRatio: sustainRatio)
    }

    /// Whether this level series has an attack worth naming, and if not, why not.
    ///
    /// - Parameters:
    ///   - levels: RMS per hop, as ``measure(_:sampleRate:)`` computed them.
    ///   - peak: the loudest level in the series.
    ///   - peakIndex: where that level sits.
    /// - Returns: `nil` when the time-to-peak IS an attack.
    static func attackRejection(
        _ levels: [Double], peak: Double, peakIndex: Int,
        peakIsAnOnset: Bool
    ) -> AttackRejection? {
        guard levels.first != nil else { return .peaksLate }

        // The loudest moment is somewhere in the middle, so it is not an onset — it is
        // wherever the arrangement peaked, or where a swell happened to be cut off.
        guard peakIsAnOnset else { return .peaksLate }

        // Struck again: after falling well away from the peak, it comes back near it.
        // Each hit of a loop has an attack; the file does not have one.
        let decayed = peak * pow(10, riseThresholdDb / 20)
        let returned = peak * pow(10, reArticulationThresholdDb / 20)
        var hasDecayed = false
        for level in levels[peakIndex...] {
            if level < decayed {
                hasDecayed = true
            } else if hasDecayed, level > returned {
                return .reArticulates
            }
        }
        return nil
    }
}
