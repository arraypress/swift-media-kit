//
//  StereoImage.swift
//  AudioTimbre
//
//  How wide a stereo file is, as two numbers and no adjective.
//
//  Note what is missing: there is no `StereoWidth` enum beside these figures, while
//  ``Brightness`` and ``Texture`` both get one. That is deliberate and it is the same
//  rule applied honestly in both directions. Those two inherited their boundaries from a
//  published source that measured real one-shots and documented where they fell. For
//  stereo width no such set was available, so inventing "narrow / wide / very wide" here
//  would be dressing a guess in the same clothes as a measurement. The numbers are exact;
//  when a boundary set exists that can be cited, a bucket can be added.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The stereo relationship between two channels.
public struct StereoImage: Codable, Hashable, Sendable {

    /// Pearson correlation between left and right, −1…1.
    ///
    /// `1` is a dual-mono file, `0` two unrelated channels, and anything negative means
    /// the channels partly cancel when summed to mono.
    public let correlation: Double

    /// The Side signal's level relative to Mid, in dB.
    ///
    /// Mid is `(L+R)/2` and Side is `(L−R)/2`. A dual-mono file has no Side at all and
    /// floors at ``AudioTimbre/Loudness/silenceFloorDbfs``; the wider the image, the
    /// closer this climbs to 0 dB.
    public let sideMidDb: Double

    /// Whether summing to mono preserves the signal rather than cancelling it.
    ///
    /// The test is `correlation > 0`, which is a definition rather than a threshold: at
    /// or below zero the channels cancel on sum. It says nothing about how *good* the
    /// image is, only that mono-summing will not hollow it out.
    public var survivesMonoSum: Bool { correlation > 0 }
}
