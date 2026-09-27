//
//  ValueKind.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What sort of thing a field holds.
///
/// Kept separate from the value itself so a caller can decide how to align a
/// column, how to sort it and whether to right-justify it before a single file
/// has been read.
public enum ValueKind: String, Sendable, CaseIterable, Codable {

    /// Free text.
    case text

    /// A whole number.
    case integer

    /// A fractional number.
    case decimal

    /// A count of bytes, which a renderer may want to humanise.
    case bytes

    /// A point in time.
    case date

    /// A length of time in seconds.
    case duration

    /// A signed degree value.
    case coordinate

    /// True or false.
    case boolean

    /// Several strings that belong together, such as keywords or tags.
    case list

    /// Whether a column of these reads better flush right.
    ///
    /// Numbers line up on their last digit or they cannot be compared down a
    /// column; text lines up on its first letter or it cannot be scanned.
    public var prefersTrailingAlignment: Bool {
        switch self {
        case .integer, .decimal, .bytes, .duration, .coordinate: true
        case .text, .date, .boolean, .list: false
        }
    }

    /// Whether values of this kind sort by magnitude rather than by character.
    public var sortsNumerically: Bool {
        switch self {
        case .integer, .decimal, .bytes, .duration, .coordinate, .date: true
        case .text, .boolean, .list: false
        }
    }
}
