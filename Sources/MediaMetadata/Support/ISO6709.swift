//
//  ISO6709.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Parses the location string QuickTime containers carry.
///
/// A recording made on a phone stores its fix as ISO 6709 text rather than as
/// the GPS dictionary a photograph gets — `+37.7749-122.4194+018.000/` — so
/// video location needs its own reader even though the answer is the same
/// shape.
public enum ISO6709 {

    /// Reads a coordinate, or `nil` when the string holds no usable pair.
    ///
    /// The components are signed decimals in the order the standard writes
    /// them: latitude, longitude, then altitude where present.
    public static func parse(_ string: String) -> Coordinate? {
        let component = /([+-]\d+(?:\.\d+)?)/
        let numbers = string.matches(of: component).compactMap { Double($0.output.1) }
        guard numbers.count >= 2 else { return nil }
        let coordinate = Coordinate(
            latitude: numbers[0],
            longitude: numbers[1],
            altitude: numbers.count >= 3 ? numbers[2] : nil
        )
        return coordinate.isPlausible ? coordinate : nil
    }
}
