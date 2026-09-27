//
//  PitchClassProfile.swift
//  AudioTimbre
//
//  How much of each of the twelve pitch classes a piece of audio contains.
//
//  Octave-folded on purpose: C2, C4 and C6 all land in the same bin. That is what makes a
//  chroma useful for harmony — a chord voiced anywhere on the keyboard produces the same
//  profile — and what makes it useless for anything where register matters. For register,
//  read ``Timbre/spectralCentroidHz``; this answers a different question.
//
//  A profile is a MEASUREMENT and is always reported in full. Naming a chord from it is an
//  interpretation, gated separately — see ``Chord``.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The twelve pitch classes' relative strengths, C first.
public struct PitchClassProfile: Codable, Hashable, Sendable {

    /// Pitch class names, index 0 = C.
    public static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Twelve values, C first, scaled so the strongest is 1.
    ///
    /// Scaled rather than summed to 1: the question a reader has is "how does this class
    /// compare with the strongest one", and a peak of 1 answers it without arithmetic.
    public let bins: [Double]

    /// How many analysis frames contributed.
    public let frames: Int

    /// - Parameter bins: twelve raw, unscaled magnitudes, C first.
    public init?(raw bins: [Double], frames: Int) {
        guard bins.count == 12 else { return nil }
        guard let peak = bins.max(), peak > 0 else { return nil }
        self.bins = bins.map { $0 / peak }
        self.frames = frames
    }

    /// The strength of one class, 0…1.
    ///
    /// - Parameter pitchClass: 0 = C, 11 = B. Values outside 0…11 wrap.
    public func strength(of pitchClass: Int) -> Double {
        bins[((pitchClass % 12) + 12) % 12]
    }

    /// Pitch class names in descending strength.
    public var ranked: [String] {
        bins.enumerated()
            .sorted { $0.element > $1.element }
            .map { Self.names[$0.offset] }
    }

    /// The classes carrying at least `threshold` of the strongest, in descending strength.
    ///
    /// The default keeps a major triad's three notes and drops the noise floor beneath
    /// them; raise it to be stricter about what counts as present.
    public func dominant(above threshold: Double = 0.5) -> [String] {
        bins.enumerated()
            .filter { $0.element >= threshold }
            .sorted { $0.element > $1.element }
            .map { Self.names[$0.offset] }
    }

    /// The strongest class divided by the median class.
    ///
    /// How far the top of a profile stands above its own middle, and the one feature that
    /// separates isolated pitched material from percussion — ``concentration`` does not,
    /// reading 0.02 for a clean A minor loop against 0.03 for a hi-hat.
    ///
    /// The MEDIAN is the floor on purpose. A lower percentile was tried and is unusable:
    /// a kick's three quietest classes are effectively zero, so the ratio ran to infinity
    /// and beyond two million, putting drums above every pitched sound measured.
    ///
    /// The cost of the median is that it falls as a chord gets richer. A four-note chord
    /// plus its harmonics lights eight of the twelve classes, which puts the median INSIDE
    /// the chord — so sevenths score lower than the triads they contain, and the gate in
    /// ``ChordEstimator`` admits triads far more readily than extended chords.
    public var salience: Double {
        let sorted = bins.sorted()
        let peak = bins.max() ?? 0
        guard peak > 0 else { return 0 }
        // The denominator is floored relative to the peak so the ratio stays finite and
        // encodable. A single pure tone drives the median to zero — a synthesised kick
        // does exactly that — and an infinite salience is a value no JSON encoder will
        // take and no caller can compare. Ten thousand is as high as this needs to say.
        let median = max((sorted[5] + sorted[6]) / 2, peak * 1e-4)
        return peak / median
    }

    /// How concentrated the profile is, 0…1 — 1 when a single class carries everything.
    ///
    /// Low values mean the energy is spread across all twelve, which is what percussion
    /// and noise look like and is the signal that no chord should be named from this.
    public var concentration: Double {
        let total = bins.reduce(0, +)
        guard total > 0 else { return 0 }
        let shares = bins.map { $0 / total }
        let entropy = shares.reduce(0.0) { $0 - ($1 > 0 ? $1 * log($1) : 0) }
        return 1 - entropy / log(12.0)
    }
}
