//
//  ImageDecoding.swift
//  ImageCompare
//
//  Bytes to a picture: ImageIO for bitmaps, AppKit for SVG.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation
import ImageIO

#if canImport(AppKit)
    import AppKit
#endif

/// Bytes to a ``ComparedImage``: ImageIO for every bitmap format it reads (an animation's first
/// frame), and, where AppKit is present, `NSImage` for SVG, which ImageIO does not read —
/// rasterized at ``vectorScale`` so two versions of a drawing are compared at one resolution.
enum ImageDecoding {
    /// Pixels per point for a vector drawing.
    static let vectorScale = 2

    /// The picture in `data`, or nil when no decoder reads it.
    static func decode(_ data: Data) -> ComparedImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            return ComparedImage(
                image: image, width: image.width, height: image.height, isVector: false, byteCount: data.count,
                typeIdentifier: CGImageSourceGetType(source) as String?, frameCount: CGImageSourceGetCount(source))
        }
        return decodeVector(data)
    }

    #if canImport(AppKit)
        /// An SVG (or anything else only `NSImage` reads), drawn at ``vectorScale`` into a
        /// transparent sRGB bitmap.
        private static func decodeVector(_ data: Data) -> ComparedImage? {
            guard let picture = NSImage(data: data), picture.size.width >= 1, picture.size.height >= 1 else { return nil }
            let width = Int(picture.size.width.rounded()), height = Int(picture.size.height.rounded())
            guard width * height <= 100_000_000 / (vectorScale * vectorScale),
                let context = CGContext(
                    data: nil, width: width * vectorScale, height: height * vectorScale, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            picture.draw(in: NSRect(x: 0, y: 0, width: width * vectorScale, height: height * vectorScale))
            NSGraphicsContext.restoreGraphicsState()
            guard let image = context.makeImage() else { return nil }
            let isSVG = picture.representations.contains { String(describing: type(of: $0)).contains("SVG") }
            return ComparedImage(
                image: image, width: width, height: height, isVector: true, byteCount: data.count,
                typeIdentifier: isSVG ? "public.svg-image" : nil, frameCount: 1)
        }
    #else
        private static func decodeVector(_ data: Data) -> ComparedImage? { nil }
    #endif
}
