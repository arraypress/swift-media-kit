//
//  Pitch.swift
//  AudioTimbre
//
//  A fundamental that survived the gate, and the reasons one might not.
//
//  ``PitchRejection`` exists because "no pitch" and "a pitch I do not believe" are
//  different facts and a caller can use the difference. A hi-hat genuinely has no
//  fundamental; a kick has one at ~60 Hz that an autocorrelator can miss while locking
//  onto a transient artifact ten times higher. Collapsing both to `nil` throws away the
//  more interesting half, so the confidence is reported either way and this says which
//  test failed.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// An estimated fundamental.
public struct Pitch: Codable, Hashable, Sendable {

    /// Pitch class without the octave: `"C"`, `"F#"`.
    public let note: String

    /// Scientific pitch notation octave, where middle C is C4.
    public let octave: Int

    /// MIDI note number, where middle C is 60.
    public let midi: Int

    /// The measured frequency, before rounding to a note.
    public let frequencyHz: Double

    /// Note and octave together: `"C5"`.
    public var name: String { "\(note)\(octave)" }

    /// How far the measurement sits from the tempered note, in cents. Negative is flat.
    ///
    /// Useful on its own: a sample reading 45 cents flat is either detuned or the
    /// estimate landed between two notes, and both are worth knowing before the name is
    /// trusted.
    public var centsFromNote: Double {
        let exact = 69.0 + 12.0 * log2(frequencyHz / 440.0)
        return (exact - Double(midi)) * 100.0
    }

    private static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// The nearest tempered note to a frequency, at A4 = 440 Hz.
    ///
    /// - Parameter frequencyHz: must be positive.
    public init?(frequencyHz: Double) {
        guard frequencyHz > 0, frequencyHz.isFinite else { return nil }
        let midi = Int((69.0 + 12.0 * log2(frequencyHz / 440.0)).rounded())
        guard midi >= 0, midi <= 127 else { return nil }
        self.midi = midi
        self.note = Self.names[((midi % 12) + 12) % 12]
        self.octave = midi / 12 - 1
        self.frequencyHz = frequencyHz
    }
}

/// Why a pitch estimate was not returned.
public enum PitchRejection: String, Codable, Sendable {

    /// The autocorrelation had no usable peak in the searched lag range.
    case noPeak

    /// A peak was found but its correlation fell below the confidence threshold.
    case lowConfidence

    /// A confident peak was found and discarded for sitting far above the spectral
    /// centroid — the shape of a transient artifact rather than a fundamental. This is
    /// the gate that stops a kick reading as a 1.5 kHz tone.
    case aboveCentroid

    /// The signal was too short to hold even one lag of the lowest searchable pitch.
    case tooShortForLowestPitch
}
