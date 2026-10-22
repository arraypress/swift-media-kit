//
//  ImageComparison.swift
//  ImageCompare
//
//  Two versions of an image compared: their facts, and the pixels they do not share.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

/// Two versions of an image — a file before and after a change — decoded and compared: each
/// side's facts (size, bytes, type, frames) and, when both are one size, which pixels differ.
public enum ImageComparison {
    /// The largest picture compared pixel by pixel (a 40-megapixel pair is ~320 MB of buffers).
    public static let pixelLimit = 40_000_000

    /// `old` and `new` compared. Either may be nil (an added or deleted file); a side no
    /// decoder reads is nil too. Blocks while decoding and comparing: call it off the main thread.
    public static func compare(old: Data?, new: Data?) -> ImageComparisonResult {
        let before = old.flatMap(ImageDecoding.decode)
        let after = new.flatMap(ImageDecoding.decode)
        var difference: PixelDifference?
        if let before, let after { difference = self.difference(before.image, after.image) }
        return ImageComparisonResult(old: before, new: after, difference: difference)
    }

    /// The pixels `a` and `b` do not share, both drawn into sRGB at their own size; nil when
    /// their sizes differ or they hold more than `limit` pixels.
    public static func difference(_ a: CGImage, _ b: CGImage, limit: Int = pixelLimit) -> PixelDifference? {
        let width = a.width, height = a.height
        guard width == b.width, height == b.height, width > 0, height > 0, width * height <= limit,
            let first = PixelBuffer(a), let second = PixelBuffer(b)
        else { return nil }
        var mask = [UInt8](repeating: 0, count: width * height)
        var changed = 0
        var minX = width, minY = height, maxX = -1, maxY = -1
        first.pixels.withUnsafeBufferPointer { p in
            second.pixels.withUnsafeBufferPointer { q in
                for y in 0..<height {
                    let row = y * width
                    for x in 0..<width where p[row + x] != q[row + x] {
                        mask[row + x] = 255
                        changed += 1
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
            }
        }
        let bounds = changed == 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return PixelDifference(
            changedPixels: changed, totalPixels: width * height, changedBounds: bounds,
            mask: changed == 0 ? nil : maskImage(mask, width: width, height: height))
    }

    /// A grayscale image of `bytes`, row by row from the top.
    private static func maskImage(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
