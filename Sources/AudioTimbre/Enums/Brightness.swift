//
//  Brightness.swift
//  AudioTimbre
//
//  A word for where a sound's energy sits, bucketed from the spectral centroid.
//
//  The boundaries are INHERITED, not derived here. They come from serum-mcp's
//  `sample_analysis.py`, whose author picked them from where five real one-shots landed
//  (kick 168 Hz, bell 1,894 Hz, snare 3,134 Hz, clap 4,617 Hz, hi-hat 10,280 Hz) and said
//  so plainly rather than implying a standard exists. They are a rough perceptual
//  bucketing and nothing more.
//
//  Which is why the raw centroid always travels beside the word — see
//  ``Timbre/spectralCentroidHz``. The number is the measurement; this is a convenience
//  for reading it. Anyone who disagrees with a boundary still has the Hz.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Where a sound's spectral energy sits, as a word.
public enum Brightness: String, Codable, CaseIterable, Sendable {

    /// Below 500 Hz. Kicks, subs, muffled material.
    case dark
    /// 500 Hz to 2 kHz. Most pitched instruments and bells.
    case warm
    /// 2 kHz to 6 kHz. Snares, claps, presence-forward material.
    case bright
    /// Above 6 kHz. Hi-hats, cymbals, air.
    case airy

    /// The bucket for a spectral centroid in Hz.
    public static func of(centroidHz: Double) -> Brightness {
        switch centroidHz {
        case ..<500:  return .dark
        case ..<2000: return .warm
        case ..<6000: return .bright
        default:      return .airy
        }
    }
}
