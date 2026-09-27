//
//  Loudness.swift
//  AudioTimbre
//
//  Absolute level, in dB relative to full scale.
//
//  Both figures are here for a specific reason found in practice rather than theory: raw
//  one-shot libraries are not gain-matched to one another, and two samples layered into
//  one sound can need very different gains to sit level. A measured 18 dB RMS gap between
//  two one-shots in a single preset — both with their volume set to roughly the same
//  value — is the kind of thing this catches before it is mixed rather than after.
//
//  Peak alone will not do it: a sharp transient and a sustained pad can share a peak and
//  be nowhere near each other in perceived level.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Accelerate
import Foundation

/// Peak and RMS level measurement.
public enum Loudness {

    /// The level reported for silence, in dBFS.
    ///
    /// A true zero signal is negative infinity, which no JSON encoder will accept and no
    /// reader benefits from. Everything below this floors here instead.
    public static let silenceFloorDbfs: Double = -120

    /// Peak and RMS level of a signal, in dBFS.
    ///
    /// - Parameter samples: any length, including empty.
    /// - Returns: both floored at ``silenceFloorDbfs``.
    public static func measure(_ samples: [Float]) -> (peak: Double, rms: Double) {
        guard !samples.isEmpty else { return (silenceFloorDbfs, silenceFloorDbfs) }
        let peak = Double(vDSP.maximumMagnitude(samples))
        let rms = Double(vDSP.rootMeanSquare(samples))
        return (dbfs(peak), dbfs(rms))
    }

    /// A linear amplitude as dBFS, floored rather than allowed to reach negative infinity.
    public static func dbfs(_ amplitude: Double) -> Double {
        guard amplitude > 1e-9 else { return silenceFloorDbfs }
        return max(20.0 * log10(amplitude), silenceFloorDbfs)
    }
}
