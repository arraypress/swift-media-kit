//
//  ImageComparisonResult.swift
//  ImageCompare
//
//  Two versions of an image, decoded and compared.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Two versions of an image, decoded and compared.
public struct ImageComparisonResult: Sendable {
    /// The earlier version; nil when there is none (an added file) or it could not be read.
    public let old: ComparedImage?
    /// The later version; nil when there is none (a deleted file) or it could not be read.
    public let new: ComparedImage?
    /// The pixels the two do not share, when both were read and they are one size.
    public let difference: PixelDifference?

    /// A result from its parts.
    public init(old: ComparedImage?, new: ComparedImage?, difference: PixelDifference?) {
        self.old = old
        self.new = new
        self.difference = difference
    }
}
