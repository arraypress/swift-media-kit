//
//  Waveform.swift
//  AudioTimbre
//
//  The shape of a sound over time: one peak per bin, for drawing.
//
//  Read at 8 kHz mono — the reader resamples, so ten minutes is 4.8 million samples rather
//  than fifty — and normalised so the loudest bin is 1, because a waveform thumbnail is a
//  picture of shape, not of level. `Level` is where level lives.
//
//  Created by David Sherlock on 9/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import Foundation

/// Normalised per-bin peaks of an audio file, for drawing waveform thumbnails and scrubbers.
public enum Waveform {

    /// Bins for a thumbnail; a scrubber asks for more.
    public static let defaultBins = 96
    /// The rate the reader resamples to: enough for an envelope, cheap for an hour.
    public static let sampleRate = 8_000.0
    /// Read no further than this; a podcast's shape is settled long before.
    public static let maxSeconds = 20.0 * 60

    /// The peak absolute sample in each of `bins` equal spans of the sound's first
    /// `maxSeconds`, normalised to the loudest bin (all zero for silence). Throws when the
    /// file is missing, has no audio track, or cannot be read.
    public static func peaks(fileAt url: URL, bins: Int = defaultBins, maxSeconds: Double = maxSeconds) async throws -> [Float] {
        let bins = max(1, bins)
        var peaks = [Float](repeating: 0, count: bins)
        var index = 0
        var perBin = 1
        _ = try await SampleStream.read(
            fileAt: url, maxSeconds: maxSeconds,
            settings: [AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1],
            // the length is known before the first block
            willRead: { seconds in perBin = max(1, (Int(seconds * sampleRate) + bins - 1) / bins) }
        ) { samples, count in
            for i in 0..<count {
                let bin = min(bins - 1, (index + i) / perBin)
                let v = abs(Float(samples[i])) / 32_768
                if v > peaks[bin] { peaks[bin] = v }
            }
            index += count
        }
        let loudest = peaks.max() ?? 0
        return loudest > 0 ? peaks.map { $0 / loudest } : peaks
    }
}
