//
//  FieldCategory.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The group a field belongs to, for presenting a chooser or a `--help` listing.
public enum FieldCategory: String, Sendable, CaseIterable, Codable {

    /// Name, path, size, type — true of every file.
    case general

    /// Timestamps, and the parts of one.
    case dates

    /// Pixel geometry and colour.
    case image

    /// What took the photograph, and how it was exposed.
    case camera

    /// What the photographer wrote into the file: caption, credit, rights.
    case iptc

    /// Where the file was made, as the device recorded it.
    case location

    /// Tags and stream facts for sound.
    case audio

    /// Tags and stream facts for moving pictures.
    case video

    /// Title, author and page count from a document.
    case document

    /// Digests of the file's bytes.
    case checksum

    /// A heading fit to print above the group.
    public var label: String {
        switch self {
        case .general: "General"
        case .dates: "Dates"
        case .image: "Image"
        case .camera: "Camera"
        case .iptc: "IPTC"
        case .location: "Location"
        case .audio: "Audio"
        case .video: "Video"
        case .document: "Document"
        case .checksum: "Checksums"
        }
    }
}
