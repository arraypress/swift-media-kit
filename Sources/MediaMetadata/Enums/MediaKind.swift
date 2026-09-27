//
//  MediaKind.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import UniformTypeIdentifiers

/// The broad sort of file, decided from its type identifier alone.
///
/// Decided without opening anything, because its whole purpose is to say what
/// is worth opening.
public enum MediaKind: String, Sendable, CaseIterable, Codable {

    case image
    case audio
    case video
    /// A PDF.
    case document
    case folder
    /// Anything the other kinds do not claim.
    case other

    /// Classifies a type identifier, falling back to the extension when the
    /// system declares no type at all.
    ///
    /// macOS declares **no UTI for Matroska** (nor `.ape`, `.wv`, `.dsf`): the dynamic type it
    /// returns conforms to nothing. A *declared* type always decides; ``undeclared`` is consulted
    /// only when the system is silent, so it can never contradict the SDK.
    public init(type: UTType?, pathExtension: String = "") {
        if let type, type.isDeclared {
            if type.conforms(to: .folder) { self = .folder }
            else if type.conforms(to: .image) { self = .image }
            else if type.conforms(to: .movie) || type.conforms(to: .video) { self = .video }
            else if type.conforms(to: .audio) { self = .audio }
            else if type.conforms(to: .pdf) { self = .document }
            else { self = .other }
            return
        }
        self = Self.undeclared[pathExtension.lowercased()] ?? .other
    }

    /// Classifies by file extension, for a path that is not on disk.
    public init(pathExtension: String) {
        self.init(type: UTType(filenameExtension: pathExtension), pathExtension: pathExtension)
    }

    /// Formats macOS declares no type for, and what they actually are. If `UTType` ever declares
    /// one, the declared answer wins and the row becomes dead weight rather than a conflict.
    public static let undeclared: [String: MediaKind] = [
        "mkv": .video, "mk3d": .video, "mks": .video, "ogm": .video, "rmvb": .video, "divx": .video,
        "mka": .audio, "ape": .audio, "wv": .audio, "dsf": .audio, "dff": .audio,
        "tak": .audio, "tta": .audio, "mpc": .audio, "shn": .audio, "opus": .audio
    ]

    /// The sources worth consulting for a file of this sort.
    ///
    /// A JPEG is never handed to `AVFoundation` and an MP3 is never handed to
    /// `ImageIO`, which is most of what makes reading a mixed folder quick.
    public var sources: Set<FieldSource> {
        switch self {
        case .image: [.fileSystem, .derived, .image]
        case .audio, .video: [.fileSystem, .derived, .media]
        case .document: [.fileSystem, .derived, .document]
        case .folder, .other: [.fileSystem, .derived]
        }
    }

    /// Whether this sort of file can answer a field at all.
    public func answers(_ field: MetadataField) -> Bool {
        field.source == .checksum || sources.contains(field.source)
    }

    /// What to call it in a listing.
    public var label: String {
        switch self {
        case .image: "Image"
        case .audio: "Audio"
        case .video: "Video"
        case .document: "Document"
        case .folder: "Folder"
        case .other: "Other"
        }
    }
}
