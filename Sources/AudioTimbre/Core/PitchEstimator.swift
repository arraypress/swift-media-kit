//
//  PitchEstimator.swift
//  AudioTimbre
//
//  An autocorrelation fundamental, and the two gates that stop it lying.
//
//  THE CENTROID GATE IS THE IMPORTANT PART, and it exists because of a specific documented
//  failure rather than caution. Run a plain autocorrelator over a kick drum and it can
//  lock onto roughly 1,520 Hz — a transient artifact, when the drum's real content lives
//  between 60 and 170 Hz — and report it with high confidence. The tell is that a genuine
//  fundamental does not sit far ABOVE the spectral centroid: the centroid is
//  energy-weighted, so for harmonic material it lands at or above the fundamental, never
//  well below it. Anything claiming otherwise is measuring the wrong thing.
//
//  THE CONFIDENCE IS RETURNED EITHER WAY. "This has no pitch" and "this has a pitch I do
//  not believe" are different facts about a sound, and a caller can act on the difference:
//  a hi-hat is genuinely unpitched, while a rejected 0.8 means something periodic is there
//  and the gate distrusted its frequency.
//
//  THE CORRELATION IS NORMALISED PER LAG, which the reference implementation's is not, and
//  the difference is the whole low end. A raw autocorrelation sums over the overlap, and
//  the overlap SHRINKS as the lag grows — so a short lag wins on term count even when it
//  correlates worse. Measured here: a clean 110 Hz sine, true lag 401. Raw sums give lag
//  29 a score of 977 against lag 401's 902, so the estimator reports 1,520 Hz, the
//  centroid gate then correctly throws it away, and a plainly pitched bass note comes back
//  as unpitched. Dividing by the energy of the two overlapping spans removes the bias
//  entirely: every lag is then a true correlation coefficient in −1…1 and 110 Hz reads as
//  A2. The energies come from a prefix sum, so this costs one extra pass over the window.
//
//  THE FIRST PEAK WINS, NOT THE TALLEST, because a periodic signal correlates just as well
//  at two or three times its period as at one. Taking the tallest reports a note an octave
//  or a twelfth too low — the classic octave error — and for a pure tone the tallest of
//  several near-identical peaks is decided by rounding noise, so it is not even stable.
//  The period is the SHORTEST lag that is a true local maximum and scores nearly as well
//  as the best; every longer peak is a multiple of it. The maximum must be interior:
//  a raw correlation is highest at the shortest lag searched and falls away from it, so
//  accepting a boundary would hand back the top of that slope instead of a period.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Accelerate
import Foundation

/// Fundamental frequency estimation.
public enum PitchEstimator {

    /// Lowest fundamental searched, Hz.
    ///
    /// Must not be 50 Hz (the reference implementation's floor): sub basses at C1 (32.7 Hz) and
    /// D1 come back unpitched. 20 Hz sits under a piano's A0 (27.5 Hz) and any sub worth naming.
    public static let minimumHz = 20.0

    /// Highest fundamental searched, Hz.
    public static let maximumHz = 1500.0

    /// The normalised autocorrelation peak below which an estimate is not trusted.
    public static let minimumConfidence = 0.5

    /// How well the first peak must score, relative to the tallest, to be taken as the
    /// period rather than treated as noise on the way up to it.
    public static let firstPeakTolerance = 0.9

    /// How far above the spectral centroid a candidate may sit before it is rejected as
    /// an artifact rather than a fundamental.
    public static let centroidGateRatio = 1.5

    /// The long window searched for a fundamental, in seconds, taken at the loudest point.
    ///
    /// A window must hold two periods, so 20 Hz needs 100 ms; 150 ms gives three while staying
    /// inside one note. It is tried SECOND — see ``windowLadder``.
    public static let windowSeconds = 0.15

    /// Window lengths to try, shortest first, in seconds; the first that finds a period wins.
    ///
    /// No single length suits both: 150 ms spans a kick's pitch glide so no period fits, while
    /// 50 ms cannot hold two periods of a 32.7 Hz sub.
    public static let windowLadder = [0.05, windowSeconds]

    /// The outcome of an estimate: at most one of `pitch` or `rejection` is set, and
    /// `confidence` is always meaningful.
    public struct Estimate: Hashable, Sendable {
        /// The estimated fundamental, when one was trusted.
        public let pitch: Pitch?
        /// The normalised autocorrelation peak, 0…1.
        public let confidence: Double
        /// Why no pitch was reported, when none was.
        public let rejection: PitchRejection?
    }

    /// Estimate the fundamental of a signal.
    ///
    /// - Parameters:
    ///   - samples: mono samples.
    ///   - sampleRate: samples per second; must be positive.
    ///   - centroidHz: the signal's spectral centroid, for the artifact gate.
    public static func estimate(_ samples: [Float], sampleRate: Double, centroidHz: Double) -> Estimate {
        guard sampleRate > 0, !samples.isEmpty else {
            return Estimate(pitch: nil, confidence: 0, rejection: .noPeak)
        }

        var last = Estimate(pitch: nil, confidence: 0, rejection: .noPeak)
        for seconds in windowLadder {
            last = estimate(
                samples, sampleRate: sampleRate, centroidHz: centroidHz,
                windowSeconds: seconds)
            if last.pitch != nil { return last }
        }
        return last
    }

    /// One pass at a single window length.
    static func estimate(
        _ samples: [Float], sampleRate: Double, centroidHz: Double,
        windowSeconds: Double
    ) -> Estimate {
        let minimumLag = max(1, Int(sampleRate / maximumHz))
        let idealMaximumLag = Int(sampleRate / minimumHz)
        let window = loudestWindow(samples, length: Int(windowSeconds * sampleRate))

        // Only half a window can ever be a period, so a short file searches a narrower
        // range rather than being refused — the lowest pitch it could detect simply rises.
        let maximumLag = min(idealMaximumLag, window.count / 2)
        guard maximumLag > minimumLag + 1 else {
            return Estimate(pitch: nil, confidence: 0, rejection: .tooShortForLowestPitch)
        }

        // Remove the mean: a DC offset correlates perfectly with itself at every lag and
        // would flatten the function this is looking for a peak in.
        let mean = vDSP.mean(window)
        let centred = vDSP.add(-mean, window)

        let correlations = normalisedCorrelations(centred, from: minimumLag, to: maximumLag)
        guard let peak = correlations.max(), peak > 0 else {
            return Estimate(pitch: nil, confidence: 0, rejection: .noPeak)
        }
        guard let bestLag = period(in: correlations, from: minimumLag, peak: peak) else {
            // Confidence is zero rather than `peak` on purpose. With no interior maximum
            // the tallest correlation sits at the shortest lag searched, which is an
            // artifact of where the search starts; reporting it as confidence would claim
            // certainty about a period that was never found.
            return Estimate(pitch: nil, confidence: 0, rejection: .noPeak)
        }

        let confidence = correlations[bestLag - minimumLag]
        guard confidence >= minimumConfidence else {
            return Estimate(pitch: nil, confidence: max(0, confidence), rejection: .lowConfidence)
        }

        let frequency = sampleRate / Double(bestLag)
        guard frequency <= centroidHz * centroidGateRatio else {
            return Estimate(pitch: nil, confidence: confidence, rejection: .aboveCentroid)
        }
        guard let pitch = Pitch(frequencyHz: frequency) else {
            return Estimate(pitch: nil, confidence: confidence, rejection: .noPeak)
        }
        return Estimate(pitch: pitch, confidence: confidence, rejection: nil)
    }

    /// The shortest lag that is an interior local maximum scoring within
    /// ``firstPeakTolerance`` of `peak` — the period, rather than a multiple of it.
    ///
    /// - Parameters:
    ///   - correlations: one value per lag, indexed from `from`.
    ///   - from: the lag `correlations[0]` refers to.
    ///   - peak: the tallest correlation present.
    static func period(in correlations: [Double], from: Int, peak: Double) -> Int? {
        let threshold = peak * firstPeakTolerance
        guard correlations.count > 2 else { return nil }
        for i in 1..<(correlations.count - 1) {
            let value = correlations[i]
            guard value >= threshold else { continue }
            if value > correlations[i - 1], value >= correlations[i + 1] {
                return i + from
            }
        }
        // No interior peak means no period. Must not fall back to the tallest lag: for
        // aperiodic material that is the SHORTEST lag searched (correlation decays from zero
        // lag), so it reports the edge of the search range (~1,520 Hz) with high confidence —
        // an artifact of the window, not a measurement.
        return nil
    }

    /// The correlation coefficient at every lag in `from...to`, each normalised by the
    /// energy of the two spans it compares so that lags are comparable with one another.
    ///
    /// - Returns: one value per lag, indexed from `from`; each in −1…1.
    static func normalisedCorrelations(_ samples: [Float], from: Int, to: Int) -> [Double] {
        let count = samples.count
        var energy = [Double](repeating: 0, count: count + 1)
        for i in 0..<count {
            let value = Double(samples[i])
            energy[i + 1] = energy[i] + value * value
        }

        var correlations = [Double](repeating: 0, count: to - from + 1)
        samples.withUnsafeBufferPointer { buffer in
            let base = buffer.baseAddress!
            for lag in from...to {
                let overlap = count - lag
                guard overlap > 0 else { continue }
                var dot: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &dot, vDSP_Length(overlap))
                let left = energy[overlap] - energy[0]
                let right = energy[overlap + lag] - energy[lag]
                let denominator = (left * right).squareRoot()
                correlations[lag - from] = denominator > 1e-12 ? Double(dot) / denominator : 0
            }
        }
        return correlations
    }

    /// The loudest window of the signal, by RMS, `length` samples long — or the whole signal
    /// when it is shorter than that.
    ///
    /// Periodicity is clearest where the sound is strongest; a window taken from a decaying
    /// tail is mostly room and noise.
    static func loudestWindow(_ samples: [Float], length wanted: Int) -> [Float] {
        let length = min(samples.count, max(1, wanted))
        guard length < samples.count else { return samples }

        let hop = max(1, length / 2)
        var bestStart = 0
        var bestLevel: Float = -1
        var start = 0
        while start + length <= samples.count {
            let level = vDSP.rootMeanSquare(Array(samples[start..<(start + length)]))
            if level > bestLevel {
                bestLevel = level
                bestStart = start
            }
            start += hop
        }
        return Array(samples[bestStart..<(bestStart + length)])
    }
}
