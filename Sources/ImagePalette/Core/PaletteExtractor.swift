//
//  PaletteExtractor.swift
//  ImagePalette
//
//  Pixels to a palette: k-means in OKLab, seeded deterministically so the
//  same picture gives the same palette on every run and every machine,
//  then clusters the eye cannot tell apart are merged and slivers dropped.
//  Shares are the fraction of sampled pixels nearest each colour — the
//  percentages a designer asks for.
//
//  Created by David Sherlock on 8/30/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

/// How a palette is extracted: how many colours, what merges, what is too small to keep.
public struct PaletteOptions: Sendable, Equatable {
    /// How many colours to ask for. Fewer may come back after merging and
    /// dropping.
    public var count: Int
    /// Clusters covering less than this fraction of the picture are dropped
    /// and their share given to the nearest survivor.
    public var minimumShare: Double
    /// Colours closer than this in OKLab are one colour (ΔE ≈ 0.02 is
    /// "just noticeable").
    public var mergeDistance: Double
    /// The longer side the image is drawn down to before sampling.
    public var sampleSide: Int
    /// The k-means seed. Fixed, so results reproduce.
    public var seed: UInt64

    /// Options; the defaults are what the `palette` command uses.
    public init(count: Int = 6, minimumShare: Double = 0.01, mergeDistance: Double = 0.03, sampleSide: Int = 256, seed: UInt64 = 7919) {
        self.count = count
        self.minimumShare = minimumShare
        self.mergeDistance = mergeDistance
        self.sampleSide = sampleSide
        self.seed = seed
    }
}

/// The colours of a picture and the share of it each one covers.
public enum PaletteExtractor {

    /// The palette of an image file.
    public static func extract(from url: URL, options: PaletteOptions = PaletteOptions()) throws -> [Swatch] {
        try extract(from: try ImageSampling.load(url, maxSide: options.sampleSide), options: options)
    }

    /// The palette of an image.
    public static func extract(from image: CGImage, options: PaletteOptions = PaletteOptions()) throws -> [Swatch] {
        let pixels = try ImageSampling.pixels(of: image, maxSide: options.sampleSide)
        return extract(from: pixels.map { OKLab(r: $0.r, g: $0.g, b: $0.b) }, options: options)
    }

    /// The palette of a set of colours. The core, exposed for tests and for
    /// callers with their own pixels.
    public static func extract(from samples: [OKLab], options: PaletteOptions) -> [Swatch] {
        guard !samples.isEmpty else { return [] }
        let k = max(1, min(options.count, samples.count))
        var centres = Self.seedCentres(samples, k: k, seed: options.seed)
        var assignment = [Int](repeating: 0, count: samples.count)

        // Lloyd's iterations, to a fixed cap: convergence is fast on
        // pictures and a bound keeps the run time a function of the input.
        for _ in 0..<24 {
            var moved = false
            for (i, s) in samples.enumerated() {
                var best = 0, bestD = Double.greatestFiniteMagnitude
                for (c, centre) in centres.enumerated() {
                    let d = s.distance(to: centre)
                    if d < bestD { bestD = d; best = c }
                }
                if assignment[i] != best { assignment[i] = best; moved = true }
            }
            var sumL = [Double](repeating: 0, count: k), sumA = sumL, sumB = sumL
            var counts = [Int](repeating: 0, count: k)
            for (i, s) in samples.enumerated() {
                let c = assignment[i]
                sumL[c] += s.l; sumA[c] += s.a; sumB[c] += s.b; counts[c] += 1
            }
            for c in 0..<k where counts[c] > 0 {
                centres[c] = OKLab(l: sumL[c] / Double(counts[c]), a: sumA[c] / Double(counts[c]), b: sumB[c] / Double(counts[c]))
            }
            if !moved { break }
        }

        // Clusters with their shares.
        var counts = [Int](repeating: 0, count: k)
        for c in assignment { counts[c] += 1 }
        var clusters: [(centre: OKLab, count: Int)] = zip(centres, counts).filter { $0.1 > 0 }.map { ($0.0, $0.1) }

        // Merge colours the eye cannot tell apart, weighting the centre by size.
        var merged = true
        while merged {
            merged = false
            outer: for i in 0..<clusters.count {
                for j in (i + 1)..<clusters.count where clusters[i].centre.distance(to: clusters[j].centre) < options.mergeDistance {
                    let a = clusters[i], b = clusters[j]
                    let total = Double(a.count + b.count)
                    let centre = OKLab(l: (a.centre.l * Double(a.count) + b.centre.l * Double(b.count)) / total,
                                       a: (a.centre.a * Double(a.count) + b.centre.a * Double(b.count)) / total,
                                       b: (a.centre.b * Double(a.count) + b.centre.b * Double(b.count)) / total)
                    clusters[i] = (centre, a.count + b.count)
                    clusters.remove(at: j)
                    merged = true
                    break outer
                }
            }
        }

        // Drop slivers, handing their pixels to the nearest survivor.
        let total = Double(samples.count)
        let keep = clusters.filter { Double($0.count) / total >= options.minimumShare }
        var survivors = keep.isEmpty ? [clusters.max { $0.count < $1.count }!] : keep
        for dropped in clusters where !survivors.contains(where: { $0.centre == dropped.centre }) {
            var nearest = 0, best = Double.greatestFiniteMagnitude
            for (i, s) in survivors.enumerated() {
                let d = s.centre.distance(to: dropped.centre)
                if d < best { best = d; nearest = i }
            }
            survivors[nearest].count += dropped.count
        }

        return survivors
            .sorted { $0.count > $1.count }
            .map { cluster in
                let rgb = cluster.centre.rgb
                return Swatch(red: rgb.r, green: rgb.g, blue: rgb.b, share: Double(cluster.count) / total)
            }
    }

    /// k-means++: the first centre is the sample nearest the mean (so the
    /// dominant colour anchors the palette), each next one is drawn with
    /// probability proportional to squared distance from the centres so
    /// far — from a fixed-seed generator.
    static func seedCentres(_ samples: [OKLab], k: Int, seed: UInt64) -> [OKLab] {
        var rng = SplitMix(seed: seed)
        let mean = OKLab(l: samples.reduce(0) { $0 + $1.l } / Double(samples.count),
                         a: samples.reduce(0) { $0 + $1.a } / Double(samples.count),
                         b: samples.reduce(0) { $0 + $1.b } / Double(samples.count))
        var centres = [samples.min { $0.distance(to: mean) < $1.distance(to: mean) }!]
        var d2 = samples.map { $0.distance(to: centres[0]) }.map { $0 * $0 }
        while centres.count < k {
            let sum = d2.reduce(0, +)
            guard sum > 0 else { break }
            var r = rng.nextDouble() * sum
            var pick = samples.count - 1
            for (i, w) in d2.enumerated() { r -= w; if r <= 0 { pick = i; break } }
            let next = samples[pick]
            centres.append(next)
            for (i, s) in samples.enumerated() {
                let d = s.distance(to: next)
                d2[i] = min(d2[i], d * d)
            }
        }
        return centres
    }


}
