//
//  ImageSampling.swift
//  ImagePalette
//
//  Pixels in. A picture is drawn down to a small bitmap first: a palette
//  is a statement about the whole, and 60,000 samples describe it as well
//  as 20 million while making the clustering instant.
//
//  Created by David Sherlock on 8/30/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation
import ImageIO

/// Why an image could not be sampled.
public enum ImageSamplingError: Error, CustomStringConvertible, Sendable {
    /// ImageIO could not open or decode the file.
    case unreadable(URL)
    /// Every pixel is transparent, so there is nothing to sample.
    case noPixels
    /// The message for people.
    public var description: String {
        switch self {
        case .unreadable(let url): return String(localized: "\(url.path) is not an image ImageIO can read", bundle: .module, comment: "Image palette error; the value is a file path. ImageIO is the Apple framework name.")
        case .noPixels: return String(localized: "the image has no opaque pixels to sample", bundle: .module, comment: "Image palette error: every pixel is transparent, so no colours can be taken from it.")
        }
    }
}

/// Reading a picture into the pixels a palette is made from.
public enum ImageSampling {

    /// Loads any image ImageIO reads — PNG, JPEG, HEIC, TIFF, GIF, WebP, PDF's first page, RAW.
    ///
    /// With `maxSide`, the decoder itself scales to that long side and applies EXIF orientation:
    /// far faster for large photos, and the plain decode would leave portraits sideways.
    /// Without `maxSide` the full image comes back as stored.
    public static func load(_ url: URL, maxSide: Int? = nil) throws -> CGImage {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            throw ImageSamplingError.unreadable(url)
        }
        if let maxSide {
            let thumb = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxSide,
            ] as CFDictionary
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumb) { return image }
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw ImageSamplingError.unreadable(url)
        }
        return image
    }

    /// Opaque pixels as RGB bytes, from the image drawn down so its longer
    /// side is at most `maxSide`. Pixels with alpha below `alphaCutoff`
    /// are left out — a transparent PNG's clear area is not a colour.
    public static func pixels(of image: CGImage, maxSide: Int = 256, alphaCutoff: UInt8 = 128) throws -> [(r: UInt8, g: UInt8, b: UInt8)] {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw ImageSamplingError.noPixels }
        var out: [(r: UInt8, g: UInt8, b: UInt8)] = []
        out.reserveCapacity(width * height)
        var i = 0
        while i < data.count {
            let a = data[i + 3]
            if a >= alphaCutoff {
                // Un-premultiply so a half-transparent red is red, not dark red.
                if a == 255 {
                    out.append((data[i], data[i + 1], data[i + 2]))
                } else {
                    let f = 255.0 / Double(a)
                    let r = UInt8(min(255, Double(data[i]) * f))
                    let g = UInt8(min(255, Double(data[i + 1]) * f))
                    let b = UInt8(min(255, Double(data[i + 2]) * f))
                    out.append((r, g, b))
                }
            }
            i += 4
        }
        guard !out.isEmpty else { throw ImageSamplingError.noPixels }
        return out
    }
}
