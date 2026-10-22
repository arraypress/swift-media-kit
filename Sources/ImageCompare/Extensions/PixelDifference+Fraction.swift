//
//  PixelDifference+Fraction.swift
//  ImageCompare
//
//  The share of pixels that changed.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension PixelDifference {
    /// The share of pixels that changed, 0…1.
    public var changedFraction: Double { totalPixels == 0 ? 0 : Double(changedPixels) / Double(totalPixels) }
}
