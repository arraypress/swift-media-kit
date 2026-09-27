//
//  AttackRejection.swift
//  AudioTimbre
//
//  Why a time-to-peak is not an attack.
//
//  ``Timbre/timeToPeakMs`` is always measured and always means the same thing: how far
//  into the signal its loudest moment sits. On a one-shot that IS the attack, which is
//  why the reference implementation calls it one. On anything longer it is wherever the
//  arrangement peaked, and the word becomes a lie — measured on a real 5.65-second pad
//  loop, "attack 3040 ms" described the third bar being marginally louder than the second.
//
//  So the number is reported under an honest name and the WORD is gated, the same way a
//  pitch estimate is: named when the shape supports it, refused with a reason when it
//  does not. "No attack" and "an attack of 3 seconds" are very different claims, and only
//  one of them is true of a pad loop.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Why a signal's time-to-peak was not reported as an attack.
public enum AttackRejection: String, Codable, Sendable {

    /// The loudest moment is too far into the file to be an onset — it is wherever the
    /// arrangement peaked, or where a swell was cut off. Measured on a real pad loop: the
    /// peak sits 54% of the way in, and calling that a three-second attack describes one
    /// bar being marginally louder than the one before it.
    ///
    /// A signal that starts at full level and peaks immediately is NOT this: that is an
    /// instant onset, a real attack of about zero.
    case peaksLate

    /// The signal returns to near its peak after decaying away from it — it is struck
    /// more than once. A loop, a sequence or an arp: each hit has an attack, and the file
    /// as a whole does not have one.
    case reArticulates
}
