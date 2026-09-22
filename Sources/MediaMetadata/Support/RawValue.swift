//
//  RawValue.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//

import Foundation
import CoreFoundation

/// Converts whatever a system framework hands back into a typed ``FieldValue``.
///
/// Core Foundation dictionaries arrive as `Any`, and the bridge is lossy in one
/// direction that matters: a `CFBoolean` will answer to `as? Int` and become
/// `1`, so booleans have to be recognised by their Core Foundation type before
/// anything else is tried.
public enum RawValue {

    /// Converts one value, or returns `nil` for something with no printable form.
    public static func convert(_ value: Any) -> FieldValue? {
        if let string = value as? String {
            return string.isEmpty ? nil : .text(string)
        }
        if let date = value as? Date {
            return .date(date)
        }
        if let number = value as? NSNumber {
            return convert(number)
        }
        if let array = value as? [Any] {
            let members = array.compactMap { convert($0)?.plain }
            return members.isEmpty ? nil : .list(members)
        }
        if let data = value as? Data {
            // Binary blobs — thumbnails, maker note payloads, colour profiles.
            // Their size is the only honest thing to say about them.
            return .text("<\(data.count) bytes>")
        }
        return nil
    }

    /// Converts a number, keeping booleans and whole numbers distinct.
    static func convert(_ number: NSNumber) -> FieldValue {
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
            return .boolean(number.boolValue)
        }
        let double = number.doubleValue
        if double == double.rounded(), abs(double) < 9.007e15 {
            return .integer(number.intValue)
        }
        return .decimal(double)
    }

    /// Flattens a nested dictionary into dotted keys under a prefix.
    ///
    /// - Parameters:
    ///   - dictionary: What the framework returned.
    ///   - prefix: The namespace, such as `exif`.
    ///   - values: Collected answers, added to in place.
    public static func flatten(
        _ dictionary: [String: Any],
        prefix: String,
        into values: inout [String: FieldValue]
    ) {
        for (key, value) in dictionary {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                flatten(nested, prefix: path, into: &values)
            } else if let nested = value as? [CFString: Any] {
                flatten(Dictionary(uniqueKeysWithValues: nested.map { ($0.key as String, $0.value) }),
                        prefix: path, into: &values)
            } else if let converted = convert(value) {
                values[path] = converted
            }
        }
    }
}
