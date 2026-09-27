//
//  OKLab.swift
//  ImagePalette
//
//  Colour distance the eye agrees with. Clustering in sRGB puts a dark blue
//  and a black in different bins and two greens the eye cannot tell apart in
//  the same one; OKLab is close enough to perceptual that a Euclidean
//  distance means "how different does this look".
//
//  Created by David Sherlock on 8/30/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A colour in OKLab: L is lightness 0…1, a and b are the opponent axes.
public struct OKLab: Sendable, Equatable, Hashable {
    /// Lightness, 0 (black) to 1 (white).
    public var l: Double
    /// The green–red axis; negative is green.
    public var a: Double
    /// The blue–yellow axis; negative is blue.
    public var b: Double

    /// A colour from its OKLab coordinates.
    public init(l: Double, a: Double, b: Double) {
        self.l = l; self.a = a; self.b = b
    }

    /// From 8-bit sRGB.
    public init(r: UInt8, g: UInt8, b: UInt8) {
        let rl = OKLab.linear(Double(r) / 255), gl = OKLab.linear(Double(g) / 255), bl = OKLab.linear(Double(b) / 255)
        let l_ = cbrt(0.4122214708 * rl + 0.5363325363 * gl + 0.0514459929 * bl)
        let m_ = cbrt(0.2119034982 * rl + 0.6806995451 * gl + 0.1073969566 * bl)
        let s_ = cbrt(0.0883024619 * rl + 0.2817188376 * gl + 0.6299787005 * bl)
        self.l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        self.a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        self.b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    }

    /// Back to 8-bit sRGB, clipped to gamut.
    public var rgb: (r: UInt8, g: UInt8, b: UInt8) {
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let l3 = l_ * l_ * l_, m3 = m_ * m_ * m_, s3 = s_ * s_ * s_
        let rl = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let gl = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        func byte(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (OKLab.gamma(v) * 255).rounded()))) }
        return (byte(rl), byte(gl), byte(bl))
    }

    /// Chroma — how far from grey.
    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Hue in degrees, 0…360.
    public var hue: Double {
        let h = atan2(b, a) * 180 / .pi
        return h < 0 ? h + 360 : h
    }

    /// Euclidean distance: roughly, ΔE.
    public func distance(to other: OKLab) -> Double {
        let dl = l - other.l, da = a - other.a, db = b - other.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    /// sRGB transfer function, encoded 0…1 channel to linear light.
    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Inverse of ``linear(_:)``: linear light back to an encoded sRGB channel.
    static func gamma(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}
