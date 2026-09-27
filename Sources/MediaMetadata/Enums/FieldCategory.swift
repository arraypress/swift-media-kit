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
        case .general: String(localized: "General", bundle: .module, comment: "Metadata group heading: facts true of every file.")
        case .dates: String(localized: "Dates", bundle: .module, comment: "Metadata group heading: timestamps.")
        case .image: String(localized: "Image", bundle: .module, comment: "Metadata group heading or kind of file: a picture.")
        case .camera: String(localized: "Camera", bundle: .module, comment: "Metadata group heading: camera and exposure settings.")
        case .iptc: "IPTC"
        case .location: String(localized: "Location", bundle: .module, comment: "Metadata group heading: where a photo was taken.")
        case .audio: String(localized: "Audio", bundle: .module, comment: "Metadata group heading or kind of file: sound.")
        case .video: String(localized: "Video", bundle: .module, comment: "Metadata group heading or kind of file: moving pictures.")
        case .document: String(localized: "Document", bundle: .module, comment: "Metadata group heading or kind of file: a PDF document.")
        case .checksum: String(localized: "Checksums", bundle: .module, comment: "Metadata group heading: digests of the file's bytes.")
        }
    }
}
