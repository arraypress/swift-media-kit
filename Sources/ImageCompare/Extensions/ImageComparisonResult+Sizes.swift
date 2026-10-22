//
//  ImageComparisonResult+Sizes.swift
//  ImageCompare
//
//  Whether the two versions are different sizes.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation

extension ImageComparisonResult {
    /// True when both versions were read and their sizes differ — in pixels, or for a drawing in
    /// points — so there is no pixel comparison.
    public var sizesDiffer: Bool {
        guard let old, let new else { return false }
        return old.width != new.width || old.height != new.height || old.image.width != new.image.width
            || old.image.height != new.image.height
    }
}
