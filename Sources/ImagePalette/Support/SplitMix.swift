//
//  SplitMix.swift
//  ImagePalette
//
//  The fixed-seed generator behind k-means++ seeding. It is the reason a
//  picture gives the same palette on every run and every machine — swap
//  it and every palette in the world changes, which is what the sequence
//  test exists to catch.
//
//  Created by David Sherlock on 8/31/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

/// SplitMix64: a tiny deterministic generator, so palettes never depend on system randomness.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// A uniform value in 0..<1 built from the top 53 bits.
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
