//
//  SpectralFeatures.swift
//  AudioTimbre
//
//  Where the energy sits (centroid) and how tone-like it is (flatness), frame by frame.
//
//  FRAME-WISE, AND THE MEDIAN — not one transform over the whole file. A single FFT across
//  sixty seconds folds a dark intro and a bright outro into one figure describing neither,
//  and the reference implementation this borrows its bucket boundaries from does exactly
//  that. It is a defensible choice there because its inputs are one-shots, where character
//  barely moves; it stops being defensible the moment the input is music. The median is
//  used rather than the mean because a couple of near-silent frames at a fade should not
//  drag the answer, and ``Timbre/spectralCentroidRangeHz`` reports the spread so a caller
//  can see when a single number is doing a poor job of describing the file.
//
//  DC IS REMOVED TWICE, and it takes both. A DC offset is not a sound, it is an offset,
//  and leaving it in adds magnitude at 0 Hz that contributes nothing to the centroid's
//  numerator while inflating its denominator — so material carrying one reads darker than
//  it is. Serum's own factory wavetables make that concrete: its 6.25% pulse sits at a DC
//  of −0.875. ``Spectrum`` subtracts each frame's mean before windowing, which removes the
//  cause; bin 0 is skipped here as well, because the mean of a windowed frame is never
//  exactly zero and the residue sits at the one frequency that drags a centroid hardest.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Spectral shape measurement.
public enum SpectralFeatures {

    /// The share of a frame's own peak magnitude below which it is treated as silence and
    /// skipped. Silent frames have no meaningful shape, and averaging them in pulls every
    /// figure toward zero.
    public static let silentFrameFloor: Float = 1e-6

    /// The share of a frame's magnitude that must sit below the rolloff frequency.
    ///
    /// 85% is librosa's default and the figure the reference pipeline reports, kept so
    /// the two are comparable.
    public static let rolloffPercent = 0.85

    /// The measured spectral shape of one signal.
    public struct Shape: Hashable, Sendable {
        /// Median per-frame centroid, Hz.
        public let centroidHz: Double
        /// Lowest and highest per-frame centroid, Hz.
        public let centroidRangeHz: ClosedRange<Double>
        /// Median per-frame bandwidth, Hz — how far the energy spreads either side of the
        /// centroid, as a magnitude-weighted standard deviation.
        ///
        /// Centroid says where the energy sits; this says how tightly. A pure tone and a
        /// two-tone chord an octave apart can share a centroid and differ here by
        /// hundreds of Hz.
        public let bandwidthHz: Double
        /// Median per-frame rolloff, Hz — the frequency below which ``rolloffPercent`` of the
        /// magnitude lies.
        ///
        /// The noise-robust figure: under added hiss a 2 kHz tone's rolloff holds at ~2,024 Hz
        /// while its centroid drifts past 3 kHz. Read centroid for brightness including noise,
        /// rolloff for where the sound itself stops.
        public let rolloffHz: Double
        /// Median per-frame flatness, 0…1.
        public let flatness: Double
        /// How many frames carried enough energy to measure.
        public let frames: Int
    }

    /// Measure a signal's spectral shape.
    ///
    /// - Parameters:
    ///   - samples: mono samples.
    ///   - sampleRate: samples per second; must be positive.
    /// - Returns: `nil` when no frame held enough energy to measure.
    public static func measure(_ samples: [Float], sampleRate: Double) -> Shape? {
        guard sampleRate > 0, !samples.isEmpty else { return nil }

        let frameSize = Spectrum.frameSize(forSignalOf: samples.count)
        guard let spectrum = Spectrum(frameSize: frameSize) else { return nil }

        let hop = max(1, frameSize / 4)
        let binWidth = sampleRate / Double(frameSize)

        var centroids: [Double] = []
        var bandwidths: [Double] = []
        var rolloffs: [Double] = []
        var flatnesses: [Double] = []

        var start = 0
        while start < samples.count {
            let end = min(start + frameSize, samples.count)
            let magnitudes = spectrum.magnitudes(of: samples[start..<end])
            if let frame = shape(of: magnitudes, binWidth: binWidth) {
                centroids.append(frame.centroid)
                bandwidths.append(frame.bandwidth)
                rolloffs.append(frame.rolloff)
                flatnesses.append(frame.flatness)
            }
            if end == samples.count { break }
            start += hop
        }

        guard let low = centroids.min(), let high = centroids.max() else { return nil }
        return Shape(centroidHz: median(centroids),
                     centroidRangeHz: min(low, high)...max(low, high),
                     bandwidthHz: median(bandwidths),
                     rolloffHz: median(rolloffs),
                     flatness: median(flatnesses),
                     frames: centroids.count)
    }

    /// The four shape figures for one magnitude spectrum, or `nil` if it is silent.
    ///
    /// - Parameters:
    ///   - magnitudes: bins from a real FFT, bin 0 first.
    ///   - binWidth: Hz per bin.
    static func shape(of magnitudes: [Float], binWidth: Double)
        -> (centroid: Double, bandwidth: Double, rolloff: Double, flatness: Double)? {
        guard magnitudes.count > 1 else { return nil }
        let bins = magnitudes[1...]                 // bin 0 is DC — see the file note.
        guard bins.contains(where: { $0 > silentFrameFloor }) else { return nil }

        var weighted = 0.0
        var total = 0.0
        var logSum = 0.0
        let epsilon = 1e-12

        for (offset, magnitude) in bins.enumerated() {
            let value = Double(magnitude)
            let frequency = Double(offset + 1) * binWidth
            weighted += value * frequency
            total += value
            logSum += log(value + epsilon)
        }

        guard total > epsilon else { return nil }
        let count = Double(bins.count)
        let geometric = exp(logSum / count)
        let arithmetic = total / count
        let flatness = min(1.0, max(0.0, geometric / (arithmetic + epsilon)))
        let centroid = weighted / total

        // Bandwidth: the magnitude-weighted standard deviation of frequency about the
        // centroid. Second pass rather than a running sum of squares — the numbers here
        // reach 10^8 and the one-pass form loses the precision that buys.
        var variance = 0.0
        // Rolloff: walk up the spectrum until `rolloffPercent` of the magnitude is behind
        // you. Reported as the centre of the bin that crosses, not its edge.
        let target = total * rolloffPercent
        var running = 0.0
        var rolloff = Double(bins.count) * binWidth
        var crossed = false

        for (offset, magnitude) in bins.enumerated() {
            let value = Double(magnitude)
            let frequency = Double(offset + 1) * binWidth
            let delta = frequency - centroid
            variance += value * delta * delta
            if !crossed {
                running += value
                if running >= target {
                    rolloff = frequency
                    crossed = true
                }
            }
        }
        return (centroid, (variance / total).squareRoot(), rolloff, flatness)
    }

    /// The middle value of an unsorted array. Even counts take the mean of the two central
    /// values, so a two-frame file does not silently pick one of them.
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
