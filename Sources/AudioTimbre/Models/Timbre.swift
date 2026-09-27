//
//  Timbre.swift
//  AudioTimbre
//
//  Everything measured about one piece of audio, and the sentence that reads it out.
//
//  The rule this type exists to enforce: EVERY WORD SHIPS BESIDE ITS NUMBER. ``brightness``
//  never appears without ``spectralCentroidHz``, ``texture`` never without
//  ``spectralFlatness``, ``pitch`` never without ``pitchConfidence``. The words are a
//  convenience for reading; the numbers are the measurement, and a caller who disagrees
//  with a bucket boundary can ignore the word and keep the figure.
//
//  It deliberately holds no class, instrument or genre. Those are a classifier's job —
//  swift-music-analysis already carries trained models for them, measured on held-out
//  packs — and a describer that guessed at them would be asserting with far less evidence
//  than the thing next door.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The measured character of one piece of audio.
public struct Timbre: Codable, Hashable, Sendable {

    // MARK: - What was measured

    /// Length in seconds.
    public let duration: Double

    /// Sample rate in Hz.
    public let sampleRate: Double

    /// Channel count. `1` means ``stereo`` is `nil`.
    public let channels: Int

    // MARK: - Spectral shape

    /// Where the energy sits, as a word. Always read with ``spectralCentroidHz``.
    public let brightness: Brightness

    /// The median per-frame spectral centroid in Hz.
    ///
    /// Median rather than mean, and per-frame rather than whole-file, because one FFT
    /// over a long file averages a dark opening and a bright ending into a number
    /// describing neither. On a one-shot there may be only one frame, in which case the
    /// two agree.
    public let spectralCentroidHz: Double

    /// The range of per-frame centroids, low and high, in Hz.
    ///
    /// Wide spread means the sound changes character as it plays; a tight spread means
    /// ``spectralCentroidHz`` describes the whole file fairly.
    public let spectralCentroidRangeHz: ClosedRange<Double>

    /// How far the energy spreads either side of the centroid, in Hz.
    ///
    /// A magnitude-weighted standard deviation of frequency. Centroid says where the
    /// energy sits; this says how tightly it is gathered there.
    public let spectralBandwidthHz: Double

    /// The frequency below which 85% of the magnitude lies, in Hz.
    ///
    /// Robust to a noise floor in a way ``spectralCentroidHz`` is not: measured on a
    /// 2 kHz tone, hiss rising from 0.001 to 0.010 left the rolloff at 2,024 Hz while the
    /// centroid climbed to 3,093. Read centroid for brightness including the noise, this
    /// for where the sound itself stops.
    public let spectralRolloffHz: Double

    /// Tone-like or noise-like, as a word. Always read with ``spectralFlatness``.
    public let texture: Texture

    /// The median per-frame spectral flatness, 0…1. `0` is a pure tone, `1` white noise.
    public let spectralFlatness: Double

    // MARK: - Pitch

    /// The estimated fundamental, or `nil` when none survived the gate.
    ///
    /// A `nil` here with a non-zero ``pitchConfidence`` means a candidate was found and
    /// rejected — see ``pitchRejection``.
    public let pitch: Pitch?

    /// The autocorrelation peak's height, 0…1, reported whether or not the estimate was
    /// accepted.
    public let pitchConfidence: Double

    /// Why no pitch was returned, or `nil` when one was.
    public let pitchRejection: PitchRejection?

    // MARK: - Envelope

    /// Time from the start of the file to its loudest point, in milliseconds.
    ///
    /// Always measured. On a one-shot this is the attack; on a loop it is wherever the
    /// arrangement peaked, which is why ``attackMs`` is a separate, gated field rather
    /// than this one wearing a better name.
    public let timeToPeakMs: Double

    /// ``timeToPeakMs`` when the signal rose to a single peak and was not struck again.
    /// `nil` otherwise — see ``attackRejection``.
    public let attackMs: Double?

    /// Why no attack was reported, or `nil` when one was.
    public let attackRejection: AttackRejection?

    /// Time from the loudest point until the level falls 60 dB below it, in milliseconds.
    ///
    /// `nil` when the file ends while still above that floor — a sustained note or a loop
    /// rather than a decaying one-shot. That absence is itself informative, which is why
    /// it is not reported as "the file length".
    public let decayMs: Double?

    /// The fraction of the file spent within 12 dB of the peak, 0…1.
    ///
    /// A rough percussive-versus-sustained signal, left as a ratio rather than forced
    /// into a label because a slow-decaying tail — a bell — fits neither cleanly.
    public let sustainRatio: Double

    // MARK: - Level

    /// The loudest single sample, in dBFS.
    public let peakDbfs: Double

    /// Root-mean-square level over the whole file, in dBFS.
    ///
    /// The reason both are here: raw sample libraries are not gain-matched to each other,
    /// so two one-shots that sound comparable in isolation can sit 18 dB apart in RMS.
    /// Anything layering samples needs this before choosing a level.
    public let rmsDbfs: Double

    // MARK: - Stereo

    /// The stereo relationship, or `nil` for a mono file.
    public let stereo: StereoImage?

    // MARK: - Reading it out

    /// A one-paragraph summary, every claim carrying its figure.
    ///
    /// Formatted for a person or a language model to read, deterministic and
    /// locale-independent so it can also be diffed and tested.
    public var summary: String {
        var lines: [String] = []

        lines.append(String(format: "%.2f s, %.3g kHz %@",
                            duration, sampleRate / 1000, channels == 1 ? "mono" : "stereo"))

        lines.append(String(format: "%@ (centroid %.0f Hz, range %.0f-%.0f, bandwidth %.0f, rolloff %.0f) - %@ (flatness %.3f)",
                            brightness.rawValue,
                            spectralCentroidHz,
                            spectralCentroidRangeHz.lowerBound,
                            spectralCentroidRangeHz.upperBound,
                            spectralBandwidthHz,
                            spectralRolloffHz,
                            texture.rawValue,
                            spectralFlatness))

        if let pitch {
            lines.append(String(format: "pitched %@ (%.1f Hz, %+.0f cents, confidence %.2f)",
                                pitch.name, pitch.frequencyHz, pitch.centsFromNote, pitchConfidence))
        } else {
            let why = pitchRejection?.rawValue ?? "none found"
            lines.append(String(format: "no pitch (%@, confidence %.2f)", why, pitchConfidence))
        }

        let rise = attackMs.map { String(format: "attack %.0f ms", $0) }
            ?? String(format: "peaks at %.0f ms (%@, not an attack)",
                      timeToPeakMs, attackRejection?.rawValue ?? "unknown")
        let fall = decayMs.map { String(format: "decay %.0f ms", $0) } ?? "no decay to -60 dB"
        lines.append(String(format: "%@, %@, sustain %.2f", rise, fall, sustainRatio))

        lines.append(String(format: "peak %.1f dBFS, RMS %.1f dBFS", peakDbfs, rmsDbfs))

        if let stereo {
            lines.append(String(format: "stereo: correlation %.2f, S/M %.1f dB",
                                stereo.correlation, stereo.sideMidDb))
        }

        return lines.joined(separator: "\n")
    }
}
