//
//  AudioDecoder.swift
//  AudioTimbre
//
//  A file to float samples, one array per channel. The only part of this library that
//  touches AVFoundation.
//
//  Everything downstream takes `[[Float]]` and a sample rate, so the measurements can be
//  tested against signals generated in memory with mathematically known answers — a sine
//  whose centroid must come back at its own frequency, noise whose flatness must approach
//  one. That is not a convenience; it is the only way to tell a correct implementation
//  from one that merely returns plausible numbers.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import Foundation

/// Decoding a file into raw samples.
public enum AudioDecoder {

    /// Decoded audio: one array per channel, all the same length.
    public struct Decoded: Sendable {
        /// Deinterleaved samples, one array per channel.
        public let channels: [[Float]]
        /// Samples per second.
        public let sampleRate: Double
    }

    /// Read a file into float samples.
    ///
    /// Whatever the file holds on disk, `AVAudioFile` presents it as deinterleaved 32-bit
    /// float through its processing format, so every supported container arrives in one
    /// shape.
    ///
    /// - Parameter url: any audio file AVFoundation can open, including MP3.
    public static func decode(fileAt url: URL) throws -> Decoded {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioTimbreError.fileNotFound(url)
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioTimbreError.cannotDecode(url, underlying: error.localizedDescription)
        }

        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0 else { throw AudioTimbreError.emptyAudio(url) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw AudioTimbreError.cannotDecode(url, underlying: "could not allocate a \(frames)-frame buffer")
        }

        do {
            try file.read(into: buffer)
        } catch {
            throw AudioTimbreError.cannotDecode(url, underlying: error.localizedDescription)
        }

        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else {
            throw AudioTimbreError.emptyAudio(url)
        }

        let count = Int(buffer.frameLength)
        let channels = (0..<Int(format.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: data[channel], count: count))
        }
        return Decoded(channels: channels, sampleRate: format.sampleRate)
    }

    /// The mean of every channel, which is what the shape measurements run on.
    ///
    /// A mean rather than the left channel alone: content panned hard right would
    /// otherwise be analysed as near-silence.
    public static func mono(_ channels: [[Float]]) -> [Float] {
        guard let first = channels.first else { return [] }
        guard channels.count > 1 else { return first }

        var sum = [Float](repeating: 0, count: first.count)
        for channel in channels {
            for i in 0..<min(sum.count, channel.count) { sum[i] += channel[i] }
        }
        let scale = 1 / Float(channels.count)
        return sum.map { $0 * scale }
    }
}
