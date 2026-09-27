//
//  LevelReport.swift
//  AudioTimbre
//
//  How loud a file gets and whether it hit the rails.
//
//  Created by David Sherlock on 9/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The loudest sample a file reaches and how many samples sat AT the rails — measured on the
/// file's own samples at its own rate, since a converted sample is not the file's.
public struct LevelReport: Equatable, Sendable {
    /// The loudest absolute sample as a fraction of full scale, 0…1.
    public let peak: Float
    /// Samples at ±full scale — clipped, or a square wave, which is the same fact.
    public let clippedSamples: Int
    /// Samples measured, all channels.
    public let sampleCount: Int
    /// How much of the file was read.
    public let analyzedSeconds: Double

    public init(peak: Float, clippedSamples: Int, sampleCount: Int, analyzedSeconds: Double) {
        self.peak = peak; self.clippedSamples = clippedSamples; self.sampleCount = sampleCount; self.analyzedSeconds = analyzedSeconds
    }

    /// The peak in dB relative to full scale; nil for silence, which has no level.
    public var peakDbfs: Double? { peak > 0 ? 20 * log10(Double(peak)) : nil }
    /// The clipped fraction of the samples measured, 0…1.
    public var clippedShare: Double { sampleCount > 0 ? Double(clippedSamples) / Double(sampleCount) : 0 }
}
