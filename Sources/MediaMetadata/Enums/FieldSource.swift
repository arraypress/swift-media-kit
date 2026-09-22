//
//  FieldSource.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//
//  What has to be opened to answer a field — which is the whole performance
//  story of this package.
//
//  Measured on a tree of 107,765 files: reading name, size, dates and type for
//  every one of them takes 3.9 s, because those come from the directory the
//  kernel already walked. Asking Spotlight for the same files takes 54.8 s.
//  Opening each image to read its EXIF costs about 0.32 ms per file, and
//  hashing costs whatever the disk costs.
//
//  So a reader that always reads everything is 14× slower than one that reads
//  what was asked for, and the fix is to know, per field, what it costs.
//

import Foundation

/// Where a field's value comes from, ordered by what it costs to get.
public enum FieldSource: String, Sendable, CaseIterable, Codable, Comparable {

    /// From the directory entry and its resource values. Effectively free.
    case fileSystem

    /// Computed from values already read. Free.
    case derived

    /// Needs a `CGImageSource` — the file is opened and its headers parsed.
    case image

    /// Needs an `AVAsset` — the container is opened and its tracks loaded.
    case media

    /// Needs a `PDFDocument`.
    case document

    /// Needs every byte of the file read. Bounded by the disk, not the CPU.
    case checksum

    /// Rough cost order, cheapest first.
    private var rank: Int {
        switch self {
        case .fileSystem: 0
        case .derived: 1
        case .image: 2
        case .media: 3
        case .document: 4
        case .checksum: 5
        }
    }

    public static func < (lhs: FieldSource, rhs: FieldSource) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Whether answering this field means opening the file itself.
    public var opensTheFile: Bool { self >= .image }
}
