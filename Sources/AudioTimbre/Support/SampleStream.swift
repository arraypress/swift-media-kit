//
//  SampleStream.swift
//  AudioTimbre
//
//  Streams a file's samples as 16-bit integers through a sink, never holding the file.
//
//  `AudioDecoder` reads a whole file into Float arrays, which is right for a one-shot and
//  wrong for a ten-minute mix: 44.1 kHz stereo is 106 million floats, 423 MB. The waveform
//  envelope and the level check only need each sample once, so they read through here —
//  an `AVAssetReader` handing out blocks of Int16, converted or resampled by the reader
//  itself, capped at `maxSeconds`.
//
//  Created by David Sherlock on 9/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import Foundation

/// Block-by-block 16-bit reads of long files, for measurements that see each sample once.
enum SampleStream {

    /// Reads up to `maxSeconds` of the file's first audio track as 16-bit PCM in the
    /// `settings` given (sample rate, channel count): `willRead` gets the seconds about to be
    /// read, before any block, so a caller can size its bins; `sink` gets each block of
    /// samples. Returns the seconds read. Throws when there is no file, no audio track, or
    /// the reader will not start.
    static func read(
        fileAt url: URL,
        maxSeconds: Double,
        settings: [String: Any],
        willRead: (Double) -> Void = { _ in },
        sink: (UnsafePointer<Int16>, Int) -> Void
    ) async throws -> Double {
        guard FileManager.default.fileExists(atPath: url.path) else { throw AudioTimbreError.fileNotFound(url) }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioTimbreError.cannotDecode(url, underlying: "no audio track")
        }
        let duration = (try? await asset.load(.duration)) ?? .zero
        let seconds = duration.isNumeric ? min(CMTimeGetSeconds(duration), maxSeconds) : 0
        guard seconds > 0 else { throw AudioTimbreError.emptyAudio(url) }
        willRead(seconds)
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw AudioTimbreError.cannotDecode(url, underlying: "no reader")
        }
        var pcm = settings
        pcm[AVFormatIDKey] = kAudioFormatLinearPCM
        pcm[AVLinearPCMBitDepthKey] = 16
        pcm[AVLinearPCMIsFloatKey] = false
        pcm[AVLinearPCMIsBigEndianKey] = false
        pcm[AVLinearPCMIsNonInterleaved] = false
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: pcm)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioTimbreError.cannotDecode(url, underlying: "output refused") }
        reader.add(output)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
        guard reader.startReading() else { throw AudioTimbreError.cannotDecode(url, underlying: "reader would not start") }
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == kCMBlockBufferNoErr,
                  let base = pointer else { continue }
            let count = length / 2
            base.withMemoryRebound(to: Int16.self, capacity: count) { sink($0, count) }
        }
        guard reader.status == .completed || reader.status == .reading else {
            throw AudioTimbreError.cannotDecode(url, underlying: reader.error?.localizedDescription ?? "reader failed")
        }
        return seconds
    }
}
