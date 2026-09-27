//
//  ChromaAnalysis.swift
//  AudioTimbre
//
//  Folding a spectrum onto the twelve pitch classes.
//
//  THE FRAME IS 16,384 SAMPLES, eight times the one the timbre measurements use, and the
//  reason is arithmetic rather than taste. Chroma needs to tell one semitone from the next,
//  and semitones get closer together as pitch falls: 15.6 Hz apart at C4, 7.8 at C3, 3.9 at
//  C2. A 2,048-point frame at 44.1 kHz has 21.5 Hz bins, which cannot separate a semitone
//  anywhere below the top of the piano; 16,384 gives 2.7 Hz bins and resolves down past C2.
//  The cost is a 372 ms window, so this is a harmonic measurement over a passage rather
//  than an instantaneous one — which is what harmony is.
//
//  FRAMES ARE WEIGHTED BY THEIR OWN ENERGY, not normalised individually. See ``fold``:
//  normalising per frame gives a silent gap between two chords the same vote as the chords,
//  and a four-bar loop then comes back with all twelve classes lit.
//
//  ONLY 55 Hz TO 5 kHz CONTRIBUTES. Below A1 there is rumble and little reliable pitch
//  class; above roughly C8 the harmonics of everything crowd together and every note starts
//  looking like every other one. librosa's chroma uses the whole spectrum and leans on its
//  filterbank weighting instead; bounding the range does the same job and is easier to
//  reason about when a result looks wrong.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Pitch class measurement.
public enum ChromaAnalysis {

    /// Frame length for chroma, in samples. 372 ms at 44.1 kHz.
    public static let frameSize = 16_384

    /// Lowest frequency that contributes, Hz — A1.
    public static let minimumHz = 55.0

    /// Highest frequency that contributes, Hz.
    public static let maximumHz = 5_000.0

    /// How loud a spectral peak must be, relative to the loudest in its frame, to count.
    ///
    /// −40 dB. Low enough to keep the quiet upper partials that distinguish one chord
    /// voicing from another, high enough to drop the ringing either side of a strong peak.
    public static let peakFloor = 0.01

    /// Measure the pitch class content of a signal.
    ///
    /// - Parameters:
    ///   - samples: mono samples.
    ///   - sampleRate: samples per second; must be positive.
    /// - Returns: `nil` when no frame carried enough energy in the pitched range.
    public static func measure(_ samples: [Float], sampleRate: Double) -> PitchClassProfile? {
        guard sampleRate > 0, !samples.isEmpty else { return nil }

        // A signal shorter than the preferred frame drops to the largest power of two that
        // fits, the same rule the timbre spectrum uses — a short one-shot still gets a
        // profile, just a coarser one.
        let size = samples.count >= frameSize ? frameSize : Spectrum.frameSize(forSignalOf: samples.count)
        guard let spectrum = Spectrum(frameSize: size) else { return nil }

        let hop = max(1, size / 2)
        let binWidth = sampleRate / Double(size)

        var totals = [Double](repeating: 0, count: 12)
        var frames = 0
        var start = 0

        while start < samples.count {
            let end = min(start + size, samples.count)
            let magnitudes = spectrum.magnitudes(of: samples[start..<end])
            if let frame = fold(magnitudes, binWidth: binWidth) {
                for i in 0..<12 { totals[i] += frame[i] }
                frames += 1
            }
            if end == samples.count { break }
            start += hop
        }

        guard frames > 0 else { return nil }
        return PitchClassProfile(raw: totals, frames: frames)
    }

    /// Fold one magnitude spectrum onto twelve classes, or `nil` if nothing is in range.
    ///
    /// Returns RAW magnitudes, deliberately unnormalised. Normalising each frame to its own
    /// peak before summing was the first version and it is wrong: it gives a near-silent
    /// gap between chords exactly as much say as the chord, so a four-bar loop comes back
    /// with all twelve classes lit and no chord findable in it. Leaving the magnitudes raw
    /// weights each frame by how much sound is actually in it.
    ///
    /// - Parameters:
    ///   - magnitudes: bins from a real FFT, bin 0 first.
    ///   - binWidth: Hz per bin.
    static func fold(_ magnitudes: [Float], binWidth: Double) -> [Double]? {
        guard binWidth > 0, magnitudes.count > 2 else { return nil }
        // One bin of headroom each side: a local maximum needs both neighbours.
        let first = max(1, Int((minimumHz / binWidth).rounded(.down)))
        let last = min(magnitudes.count - 2, Int((maximumHz / binWidth).rounded(.up)))
        guard last > first else { return nil }

        // ONLY SPECTRAL PEAKS VOTE. A played note makes a local maximum; the thousands of
        // bins between notes carry a noise floor that is individually tiny and collectively
        // enormous, because each pitch class gathers bins from seven octaves. Summing every
        // bin let that floor dominate: an A minor loop came back with all twelve classes
        // between 0.7 and 1.0, and no chord was findable in it at any segment length. Taking
        // maxima only removes the floor instead of trying to out-weight it.
        var ceiling: Float = 0
        for index in first...last where magnitudes[index] > ceiling { ceiling = magnitudes[index] }
        guard ceiling > 0 else { return nil }
        let floor = Double(ceiling) * peakFloor

        var bins = [Double](repeating: 0, count: 12)
        var total = 0.0
        for index in first...last {
            let magnitude = Double(magnitudes[index])
            guard magnitude >= floor else { continue }
            guard magnitude > Double(magnitudes[index - 1]),
                  magnitude >= Double(magnitudes[index + 1]) else { continue }
            let frequency = Double(index) * binWidth
            let midi = 69.0 + 12.0 * log2(frequency / 440.0)
            let nearest = midi.rounded()

            // Discount bins that sit between two semitones. Assigning every bin to its
            // nearest class at full weight lets the noise between notes count as much as
            // the notes, which is most of why the first version smeared. A raised cosine
            // over half a semitone either side reaches zero exactly at the midpoint, so
            // only energy near a real semitone centre votes.
            let offset = abs(midi - nearest)
            let weight = pow(cos(.pi * offset), 2)
            guard weight > 0 else { continue }

            bins[((Int(nearest) % 12) + 12) % 12] += magnitude * weight
            total += magnitude * weight
        }

        guard total > 0 else { return nil }
        return bins
    }
}
