//
//  HarmonicAnalyzer.swift
//  AudioTimbre
//
//  The harmonic entry point: which of the twelve pitch classes are in this.
//
//  SEPARATE FROM ``TimbreAnalyzer`` rather than a field on ``Timbre``, and the reason is
//  cost. Chroma needs a 16,384-point frame where the timbre measurements need 2,048, so
//  folding it into every analysis would make a thousand-file pack sweep eight times slower
//  for an answer most callers browsing a drum library do not want.
//
//  THERE IS NO CHORD NAMER HERE, and that is a decision taken AFTER building one and
//  measuring it. A chord namer over these profiles — 108 templates, cosine matched, gated on
//  salience and on confidence — named **nine of twenty kick drums as F**, several with a
//  salience in the hundreds of thousands, because a kick is one strong fundamental and
//  nothing is more salient than that. Meanwhile the pitched one-shots it did name mostly
//  carried ONE pitch class: it was reading a single note's harmonic series, which is a root,
//  a fifth and a major third, as a major triad. So it was not identifying chords at all —
//  it was identifying fundamentals, which ``PitchEstimator`` already does and does better,
//  against a filename ground truth of 58 out of 60.
//
//  Recover it with `git log --all -- Sources/AudioTimbre/Core/ChordEstimator.swift` if a
//  future version has something the templates can stand on: beat-synchronous segmentation,
//  a bass-aware template set, or a trained model. What it needs is not a better threshold —
//  every threshold available over this feature was measured and none of them separate a
//  kick drum from a chord.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What a piece of audio contains harmonically.
public struct Harmony: Codable, Hashable, Sendable {

    /// How much of each pitch class is present.
    public let chroma: PitchClassProfile

    /// Pitch classes carrying at least half the strongest, in descending order.
    public var dominantPitchClasses: [String] { chroma.dominant() }

    /// A line a person or a model can read, every word beside its number.
    ///
    /// It reports what is present and stops there. A kick reading "F" is true and useful;
    /// the same kick reading "F major" would not be.
    public var summary: String {
        let classes = dominantPitchClasses.joined(separator: " ")
        return String(format: "pitch classes: %@ - salience %.1f over %d frames",
                      classes.isEmpty ? "none" : classes, chroma.salience, chroma.frames)
    }
}

/// Measures pitch class content.
public enum HarmonicAnalyzer {

    /// Analyse an audio file harmonically.
    ///
    /// - Parameter url: any file AVFoundation can decode.
    /// - Throws: ``AudioTimbreError`` if the file is missing, undecodable or silent.
    public static func analyze(fileAt url: URL) throws -> Harmony {
        let decoded = try AudioDecoder.decode(fileAt: url)
        return try analyze(channels: decoded.channels, sampleRate: decoded.sampleRate)
    }

    /// Analyse samples already in memory.
    ///
    /// - Parameters:
    ///   - channels: one array per channel, all the same length.
    ///   - sampleRate: samples per second.
    public static func analyze(channels: [[Float]], sampleRate: Double) throws -> Harmony {
        guard sampleRate > 0 else { throw AudioTimbreError.invalidSampleRate(sampleRate) }
        guard let first = channels.first, !first.isEmpty else {
            throw AudioTimbreError.malformedChannels("no channels, or the first is empty")
        }
        let mono = AudioDecoder.mono(channels)
        guard let chroma = ChromaAnalysis.measure(mono, sampleRate: sampleRate) else {
            throw AudioTimbreError.silent
        }
        return Harmony(chroma: chroma)
    }

    /// Analyse a run of segments — bars, beats, or anything else a caller has boundaries
    /// for — returning one reading each.
    ///
    /// The boundaries have to come from outside: this library measures spectra and does not
    /// track beats. `muse --full` reports every beat and bar position.
    ///
    /// - Parameters:
    ///   - channels: one array per channel.
    ///   - sampleRate: samples per second.
    ///   - segments: start and end times in seconds. Spans past the end of the audio, and
    ///     spans of zero length, are skipped. An inverted span cannot reach here —
    ///     `ClosedRange` traps on construction — so the type does that validation.
    public static func analyze(channels: [[Float]], sampleRate: Double,
                               segments: [ClosedRange<Double>]) throws -> [Harmony] {
        guard sampleRate > 0 else { throw AudioTimbreError.invalidSampleRate(sampleRate) }
        let mono = AudioDecoder.mono(channels)
        guard !mono.isEmpty else {
            throw AudioTimbreError.malformedChannels("no channels, or the first is empty")
        }

        return segments.compactMap { span in
            let start = max(0, Int(span.lowerBound * sampleRate))
            let end = min(mono.count, Int(span.upperBound * sampleRate))
            guard end > start else { return nil }
            guard let chroma = ChromaAnalysis.measure(Array(mono[start..<end]),
                                                      sampleRate: sampleRate) else { return nil }
            return Harmony(chroma: chroma)
        }
    }
}
