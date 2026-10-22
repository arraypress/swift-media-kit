//
//  PixelDifference.swift
//  ImageCompare
//
//  Which pixels two pictures of one size do not share.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

/// Which pixels two pictures of one size do not share: how many, where, and a mask of them.
public struct PixelDifference: @unchecked Sendable {
    /// Pixels whose colour or opacity differ in any channel.
    public let changedPixels: Int
    /// Pixels compared (width × height).
    public let totalPixels: Int
    /// The smallest rectangle holding every changed pixel, in pixels from the top-left corner;
    /// nil when none changed.
    public let changedBounds: CGRect?
    /// A grayscale mask the size of the pictures, white where a pixel changed and black
    /// elsewhere — for drawing the changes in a colour of the caller's choosing.
    public let mask: CGImage?

    /// A difference from its parts.
    public init(changedPixels: Int, totalPixels: Int, changedBounds: CGRect?, mask: CGImage?) {
        self.changedPixels = changedPixels
        self.totalPixels = totalPixels
        self.changedBounds = changedBounds
        self.mask = mask
    }
}
