//
//  StereoAnalysis.swift
//  AudioTimbre
//
//  The relationship between two channels: how alike they are, and how much is not shared.
//
//  Both figures are needed because each hides something the other shows. Correlation says
//  whether the channels will cancel on a mono sum but nothing about how much stereo
//  content there is — a file with a whisper of decorrelated reverb over a centred source
//  reads near 1.0, the same as true dual mono. Side/Mid says how much material sits off
//  centre but nothing about polarity — a wide mix and a mix with one channel inverted can
//  report similar ratios while one of them collapses to nothing when summed.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Accelerate
import Foundation

/// Stereo image measurement.
public enum StereoAnalysis {

    /// Measure the relationship between two channels.
    ///
    /// - Parameters:
    ///   - left: the left channel.
    ///   - right: the right channel; must be the same length as `left`.
    /// - Returns: `nil` if the channels differ in length or are empty.
    public static func measure(left: [Float], right: [Float]) -> StereoImage? {
        guard !left.isEmpty, left.count == right.count else { return nil }

        var cross: Float = 0
        var leftEnergy: Float = 0
        var rightEnergy: Float = 0
        let n = vDSP_Length(left.count)
        vDSP_dotpr(left, 1, right, 1, &cross, n)
        vDSP_dotpr(left, 1, left, 1, &leftEnergy, n)
        vDSP_dotpr(right, 1, right, 1, &rightEnergy, n)

        let denominator = (Double(leftEnergy) * Double(rightEnergy)).squareRoot()
        // Two silent channels are identical, not undefined: report them as perfectly
        // correlated rather than dividing by zero.
        let correlation =
            denominator > 1e-12
            ? min(1.0, max(-1.0, Double(cross) / denominator))
            : 1.0

        let mid = vDSP.multiply(0.5, vDSP.add(left, right))
        let side = vDSP.multiply(0.5, vDSP.subtract(left, right))
        let midRms = Double(vDSP.rootMeanSquare(mid))
        let sideRms = Double(vDSP.rootMeanSquare(side))

        let sideMidDb: Double
        if midRms > 1e-9 {
            sideMidDb = max(Loudness.silenceFloorDbfs, 20 * log10(max(sideRms, 1e-12) / midRms))
        } else {
            // No Mid at all: the channels are equal and opposite. That is the widest a
            // file can be, not the narrowest, so it does not floor.
            sideMidDb = sideRms > 1e-9 ? 0 : Loudness.silenceFloorDbfs
        }

        return StereoImage(correlation: correlation, sideMidDb: sideMidDb)
    }
}
