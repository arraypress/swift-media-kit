//
//  Numbers.swift
//  MediaMetadata
//
//  Reading a number out of a Core Foundation dictionary without caring which
//  numeric type the format happened to use.
//
//  This exists because of a bug the tests caught. EXIF stores focal length as
//  a RATIONAL and focal-length-in-35mm as a SHORT, so ImageIO hands back a
//  `Double` for one and an `Int` for the other — and `value as? Double` on an
//  `Int` is `nil`, silently. Every numeric tag has the same exposure: a camera
//  writing ISO as a short and another writing it as a rational would disagree
//  about whether the column has any data in it.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Coerces whatever a framework returned into the number it represents.
public enum Numbers {

    /// A floating point value, whatever numeric type it arrived as.
    public static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            // A CFBoolean is an NSNumber too, and `true` is not `1.0` in any
            // sense a metadata column wants.
            CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() ? nil : number.doubleValue
        case let text as String:
            Double(text.trimmingCharacters(in: .whitespaces))
        default:
            nil
        }
    }

    /// A whole number, whatever numeric type it arrived as.
    public static func int(_ value: Any?) -> Int? {
        guard let double = double(value), double.isFinite else { return nil }
        return Int(double.rounded())
    }

    /// The first number in a value that may be a scalar or an array of them.
    ///
    /// `ISOSpeedRatings` is an array by specification — a camera may record
    /// several — while plenty of files write a bare number in the same tag.
    public static func firstDouble(_ value: Any?) -> Double? {
        if let array = value as? [Any] { return array.compactMap { double($0) }.first }
        return double(value)
    }

    /// The first whole number in a value that may be a scalar or an array.
    public static func firstInt(_ value: Any?) -> Int? {
        guard let double = firstDouble(value), double.isFinite else { return nil }
        return Int(double.rounded())
    }
}
