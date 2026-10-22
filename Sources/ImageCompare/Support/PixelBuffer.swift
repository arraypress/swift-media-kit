//
//  PixelBuffer.swift
//  ImageCompare
//
//  A picture's pixels as one 32-bit word each, top row first.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

/// A picture's pixels drawn into 8-bit premultiplied sRGB RGBA, one `UInt32` a pixel, the top
/// row first — so two pictures are compared in one colour space whatever they were saved in.
struct PixelBuffer {
    let pixels: [UInt32]

    init?(_ image: CGImage) {
        let width = image.width, height = image.height
        var words = [UInt32](repeating: 0, count: width * height)
        let drawn = words.withUnsafeMutableBytes { raw -> Bool in
            guard
                let context = CGContext(
                    data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            // A bitmap context keeps its top row first in memory, so the picture drawn unflipped
            // leaves row 0 of the buffer as its top row (a flip here mirrors every position).
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        pixels = words
    }
}
