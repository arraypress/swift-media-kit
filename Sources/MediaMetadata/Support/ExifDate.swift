//
//  ExifDate.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Reads the date format EXIF uses.
///
/// `DateTimeOriginal` is written `2026:06:27 13:42:11` and carries **no time zone**; Spotlight
/// resolves it against one anyway, so the index and the file can disagree by hours. It is
/// parsed in the current zone and written out exactly as recorded; nothing here converts it.
public enum ExifDate {

    /// Parses `yyyy:MM:dd HH:mm:ss`, returning `nil` for anything else.
    public static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
