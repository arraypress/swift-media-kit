//
//  ComparedImage.swift
//  ImageCompare
//
//  One side of an image comparison, decoded.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

/// One side of an image comparison: the picture, decoded, and the facts a reviewer reads.
public struct ComparedImage: @unchecked Sendable {
    /// The picture (an animation's first frame; a vector drawing rasterized at `vectorScale`).
    public let image: CGImage
    /// Width and height in pixels — for a vector drawing, its own size in points.
    public let width: Int
    /// See ``width``.
    public let height: Int
    /// True for a vector drawing (SVG, PDF), whose size is in points, not pixels.
    public let isVector: Bool
    /// The file's size in bytes.
    public let byteCount: Int
    /// The file's type as ImageIO names it (`public.png`), or `public.svg-image`; nil when unknown.
    public let typeIdentifier: String?
    /// How many frames it has (an animated GIF or PNG has several).
    public let frameCount: Int

    /// A side from its parts.
    public init(image: CGImage, width: Int, height: Int, isVector: Bool, byteCount: Int, typeIdentifier: String?, frameCount: Int) {
        self.image = image
        self.width = width
        self.height = height
        self.isVector = isVector
        self.byteCount = byteCount
        self.typeIdentifier = typeIdentifier
        self.frameCount = frameCount
    }
}
