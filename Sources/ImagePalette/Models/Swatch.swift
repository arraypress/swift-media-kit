//
//  Swatch.swift
//  ImagePalette
//
//  Created by David Sherlock on 8/30/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One colour of a palette and how much of the picture it covers.
public struct Swatch: Sendable, Equatable, Codable {
    /// Red, sRGB 0–255.
    public let red: UInt8
    /// Green, sRGB 0–255.
    public let green: UInt8
    /// Blue, sRGB 0–255.
    public let blue: UInt8
    /// The fraction of sampled pixels nearest this colour, 0…1. A palette's
    /// shares sum to 1 unless tiny clusters were dropped.
    public let share: Double
    /// OKLab lightness 0…1 — how light it looks.
    public let lightness: Double
    /// OKLab chroma — how far from grey. Above ~0.1 reads as a colour;
    /// below ~0.03 reads as a neutral.
    public let chroma: Double
    /// OKLab hue in degrees, 0…360. Meaningless for neutrals.
    public let hue: Double

    /// A swatch from sRGB bytes and its share of the picture.
    public init(red: UInt8, green: UInt8, blue: UInt8, share: Double) {
        self.red = red; self.green = green; self.blue = blue; self.share = share
        let lab = OKLab(r: red, g: green, b: blue)
        lightness = lab.l; chroma = lab.chroma; hue = lab.hue
    }

    /// `#RRGGBB`, upper case.
    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

    /// `rgb(r, g, b)`.
    public var rgb: String { "rgb(\(red), \(green), \(blue))" }

    /// `hsl(h, s%, l%)` — the CSS numbers, from sRGB.
    public var hsl: String { ColorFormats.hsl(red: red, green: green, blue: blue) }

    /// Whether this reads as a grey rather than a colour.
    public var isNeutral: Bool { chroma < 0.03 }

    /// The swatch in OKLab, for distances.
    public var oklab: OKLab { OKLab(r: red, g: green, b: blue) }
}
