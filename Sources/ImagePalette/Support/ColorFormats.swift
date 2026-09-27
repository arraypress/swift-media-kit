//
//  ColorFormats.swift
//  ImagePalette
//
//  CSS colour strings as pure functions. The HSL conversion is a real
//  algorithm — hue sectors, the lightness-folded saturation — and an
//  algorithm buried in a model property can only be tested by building
//  the model around it.
//
//  Created by David Sherlock on 8/31/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// String renderings of sRGB bytes for the formats people paste into CSS.
enum ColorFormats {

    /// `hsl(h, s%, l%)` — the CSS numbers, from sRGB.
    static func hsl(red: UInt8, green: UInt8, blue: UInt8) -> String {
        let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), d = maxC - minC
        let l = (maxC + minC) / 2
        var h = 0.0, s = 0.0
        if d > 0 {
            s = d / (1 - abs(2 * l - 1))
            switch maxC {
            case r: h = 60 * (((g - b) / d).truncatingRemainder(dividingBy: 6))
            case g: h = 60 * ((b - r) / d + 2)
            default: h = 60 * ((r - g) / d + 4)
            }
            if h < 0 { h += 360 }
        }
        return String(format: "hsl(%.0f, %.0f%%, %.0f%%)", h, s * 100, l * 100)
    }
}
