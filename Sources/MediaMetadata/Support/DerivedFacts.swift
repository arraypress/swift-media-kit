//
//  DerivedFacts.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Fields computed from values already read, at no further cost.
public enum DerivedFacts {

    /// Settles the capture date and the calendar parts that hang off it.
    ///
    /// The order is the point: a photograph's own capture time beats the
    /// container date of a video, which beats whatever the file system holds —
    /// because copying a file to a delivery drive rewrites the last of those
    /// and none of the others.
    public static func read(
        wanted: Set<MetadataField>,
        into values: inout [MetadataField: FieldValue]
    ) {
        guard let date = capturedDate(in: values) else { return }

        func put(_ field: MetadataField, _ value: FieldValue) {
            guard wanted.contains(field) else { return }
            values[field] = value
        }

        put(.captured, .date(date))

        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        if let year = parts.year { put(.year, .text(String(format: "%04d", year))) }
        if let month = parts.month { put(.month, .text(String(format: "%02d", month))) }
        if let day = parts.day { put(.day, .text(String(format: "%02d", day))) }
        if let hour = parts.hour, let minute = parts.minute, let second = parts.second {
            put(.time, .text(String(format: "%02d:%02d:%02d", hour, minute, second)))
        }
    }

    /// The best available answer to "when was this made".
    static func capturedDate(in values: [MetadataField: FieldValue]) -> Date? {
        if case .date(let shot)? = values[.shotDate] { return shot }
        if case .date(let container)? = values[.captured] { return container }
        if case .date(let created)? = values[.created] { return created }
        return nil
    }
}
