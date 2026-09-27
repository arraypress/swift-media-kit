//
//  Texture.swift
//  AudioTimbre
//
//  A word for how tone-like or noise-like a sound is, bucketed from spectral flatness.
//
//  Flatness is the ratio of the geometric to the arithmetic mean of the magnitude
//  spectrum: 0 for a pure tone, 1 for white noise. The raw figure always ships alongside
//  in ``Timbre/spectralFlatness``.
//
//  UNLIKE ``Brightness``, THESE BOUNDARIES ARE MEASURED HERE, because the inherited ones
//  did not fit. serum-mcp cuts at 0.15 and 0.30, read off five one-shots. Run against 240
//  one-shots from a commercial trance pack, that put 22 of 25 claps in the same bucket as
//  a kick — and a clap is not tonal. The cause is that this library measures flatness per
//  frame and takes the median, where the reference takes one transform over the whole
//  file, and the two produce different numbers on the same audio. Inheriting a threshold
//  across a change of method is what went wrong, not the original threshold.
//
//  Median flatness per class, 30 files each (n=240):
//
//  sub bass 0.001   kick 0.003   clap 0.071   ride 0.162
//  crash 0.177      open hat 0.234   snare 0.380   closed hat 0.601
//
//  0.025 separates the pitched drums from the clap family (kick p90 is 0.022, clap p10 is
//  0.033 — the gap is real, not a coin toss), and 0.25 separates the clap family from the
//  snares and closed hats. Both sit in a gap between clusters rather than through one.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// How tone-like or noise-like a sound is, as a word.
public enum Texture: String, Codable, CaseIterable, Sendable {

    /// Flatness below 0.025. A clear pitch or a tight harmonic series — kicks, subs,
    /// basses, and anything with a fundamental you could name.
    case tonal
    /// 0.025 to 0.25. Harmonic content with noise over it — claps, rides, open hats.
    case mixed
    /// Above 0.25. Broadband — snares, closed hats, noise.
    case noisy

    /// The bucket for a spectral flatness of 0…1.
    public static func of(flatness: Double) -> Texture {
        switch flatness {
        case ..<0.025: return .tonal
        case ..<0.25:  return .mixed
        default:      return .noisy
        }
    }
}
