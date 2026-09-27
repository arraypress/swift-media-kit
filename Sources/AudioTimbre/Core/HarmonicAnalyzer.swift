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
//  THERE IS NO CHORD NAMER, by measurement. Template matching over these profiles names a
//  kick drum as a chord (one strong fundamental is the most salient thing there is) and reads
//  a single note's harmonic series — root, fifth, major third — as a major triad: it finds
//  fundamentals, which ``PitchEstimator`` already does better. No threshold over this feature
//  separates a kick from a chord; a namer needs beat-synchronous segmentation, a bass-aware
//  template set or a trained model (the measured attempt: `git log --all --
//  Sources/AudioTimbre/Core/ChordEstimator.swift`).
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

    /// Analyse a run of segments — bars, beats, or any caller-supplied boundaries — returning
    /// one reading each. This library does not track beats, so boundaries come from outside.
    ///
    /// - Parameter segments: start and end times in seconds. Spans past the end of the audio
    ///   and zero-length spans are skipped.
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
