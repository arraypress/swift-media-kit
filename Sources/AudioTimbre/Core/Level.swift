//
//  Level.swift
//  AudioTimbre
//
//  Peak level and rail hits, streamed at the file's own rate and channels.
//
//  `Loudness` measures arrays already in memory; this reads the file. No conversion: a
//  16-bit sample that reads 32767 is one the file itself put at the rail, and counting
//  those is the whole point.
//
//  Created by David Sherlock on 9/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import Foundation

/// Peak level and clipped-sample count of an audio file, read at its native format.
public enum Level {

    /// Read no further than this.
    public static let maxSeconds = 20.0 * 60
    /// The 16-bit rail: a sample at or beyond it counts as clipped.
    public static let rail: Int32 = 32_767

    /// The loudest sample and the count at the rails over the file's first `maxSeconds`.
    /// Throws when the file is missing, has no audio track, or cannot be read.
    public static func measure(fileAt url: URL, maxSeconds: Double = maxSeconds) async throws -> LevelReport {
        var peak: Int32 = 0, clipped = 0, count = 0
        let seconds = try await SampleStream.read(fileAt: url, maxSeconds: maxSeconds, settings: [:]) { samples, n in
            for i in 0..<n {
                let v = abs(Int32(samples[i]))
                if v > peak { peak = v }
                if v >= rail { clipped += 1 }
            }
            count += n
        }
        guard count > 0 else { throw AudioTimbreError.emptyAudio(url) }
        return LevelReport(peak: Float(min(peak, 32_768)) / 32_768, clippedSamples: clipped, sampleCount: count, analyzedSeconds: seconds)
    }
}
