//
//  TimbreAnalyzer.swift
//  AudioTimbre
//
//  The entry point: audio in, measured facts out.
//
//  There is no minimum duration anywhere in here, and that is the reason the library
//  exists. Apple's sound classifier works on a fixed three-second window and returns
//  nothing at all below it; MusicUnderstanding needs two beats before it will name a
//  tempo. Both are correct for what they do and both leave a 400 ms one-shot — the most
//  common object in any sample library — described by nothing but its file size. Direct
//  measurement has no such floor: a spectral centroid is well defined over 64 samples and
//  an attack time over two.
//
//  What it will not do is name the sound. Classification belongs to a trained model with
//  held-out accuracy behind it, and swift-music-analysis already carries one. Measuring
//  and guessing are different jobs and this library only does the first.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Measures what audio sounds like.
public enum TimbreAnalyzer {

    /// Analyse an audio file.
    ///
    /// - Parameter url: any file AVFoundation can decode, of any length.
    /// - Throws: ``AudioTimbreError`` if the file is missing, undecodable or silent.
    public static func analyze(fileAt url: URL) throws -> Timbre {
        let decoded = try AudioDecoder.decode(fileAt: url)
        return try analyze(channels: decoded.channels, sampleRate: decoded.sampleRate)
    }

    /// Analyse samples already in memory.
    ///
    /// - Parameters:
    ///   - channels: one array per channel; all must be the same length and non-empty.
    ///   - sampleRate: samples per second.
    /// - Throws: ``AudioTimbreError`` if the channels are malformed or the audio is silent.
    public static func analyze(channels: [[Float]], sampleRate: Double) throws -> Timbre {
        guard sampleRate > 0 else { throw AudioTimbreError.invalidSampleRate(sampleRate) }
        guard let first = channels.first, !first.isEmpty else {
            throw AudioTimbreError.malformedChannels("no channels, or the first is empty")
        }
        guard channels.allSatisfy({ $0.count == first.count }) else {
            let lengths = channels.map(\.count).map(String.init).joined(separator: ", ")
            throw AudioTimbreError.malformedChannels("channel lengths differ: \(lengths)")
        }

        let mono = AudioDecoder.mono(channels)
        let (peakDbfs, rmsDbfs) = Loudness.measure(mono)
        guard peakDbfs > Loudness.silenceFloorDbfs else { throw AudioTimbreError.silent }

        guard let spectral = SpectralFeatures.measure(mono, sampleRate: sampleRate) else {
            throw AudioTimbreError.silent
        }

        let envelope = Envelope.measure(mono, sampleRate: sampleRate)
        let pitch = PitchEstimator.estimate(mono, sampleRate: sampleRate,
                                            centroidHz: spectral.centroidHz)
        let stereo = channels.count >= 2
            ? StereoAnalysis.measure(left: channels[0], right: channels[1])
            : nil

        return Timbre(
            duration: Double(first.count) / sampleRate,
            sampleRate: sampleRate,
            channels: channels.count,
            brightness: Brightness.of(centroidHz: spectral.centroidHz),
            spectralCentroidHz: spectral.centroidHz,
            spectralCentroidRangeHz: spectral.centroidRangeHz,
            spectralBandwidthHz: spectral.bandwidthHz,
            spectralRolloffHz: spectral.rolloffHz,
            texture: Texture.of(flatness: spectral.flatness),
            spectralFlatness: spectral.flatness,
            pitch: pitch.pitch,
            pitchConfidence: pitch.confidence,
            pitchRejection: pitch.rejection,
            timeToPeakMs: envelope.timeToPeakMs,
            attackMs: envelope.attackMs,
            attackRejection: envelope.attackRejection,
            decayMs: envelope.decayMs,
            sustainRatio: envelope.sustainRatio,
            peakDbfs: peakDbfs,
            rmsDbfs: rmsDbfs,
            stereo: stereo
        )
    }
}
