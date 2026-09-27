//
//  AudioTimbreError.swift
//  AudioTimbre
//
//  Every way an analysis can refuse, each naming what it saw.
//
//  There is deliberately no "too short" case. A duration floor is the failure mode this
//  library exists to avoid: Apple's sound classifier has a fixed three-second window and
//  MusicUnderstanding needs two beats, so a 400 ms one-shot comes back empty from both.
//  Direct measurement has no such floor — a spectral centroid is well defined over 64
//  samples — so the only refusals here are for audio that is absent, unreadable or silent.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A failure during analysis.
public enum AudioTimbreError: Error, LocalizedError, Equatable, Sendable {

    /// No file at that path.
    case fileNotFound(URL)
    /// The file exists but no decoder would open it.
    case cannotDecode(URL, underlying: String)
    /// The decode produced no frames at all.
    case emptyAudio(URL)
    /// The samples are all zero, so every shape measurement would be meaningless.
    case silent
    /// A channel array was empty, or the channels had differing lengths.
    case malformedChannels(String)
    /// The sample rate was zero or negative.
    case invalidSampleRate(Double)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "No file at \(url.path)."
        case .cannotDecode(let url, let underlying):
            return "Could not decode \(url.lastPathComponent): \(underlying)"
        case .emptyAudio(let url):
            return "\(url.lastPathComponent) decoded to zero frames."
        case .silent:
            return "The audio is entirely silent; there is no spectrum to measure."
        case .malformedChannels(let detail):
            return "Malformed channel data: \(detail)"
        case .invalidSampleRate(let rate):
            return "Sample rate must be positive; got \(rate)."
        }
    }
}
