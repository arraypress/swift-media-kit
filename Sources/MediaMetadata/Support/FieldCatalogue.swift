//
//  FieldCatalogue.swift
//  MediaMetadata
//
//  The table behind ``MetadataField``. One row per field, so a label, a
//  category, a value shape and a cost are declared in exactly one place and
//  cannot drift apart.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Static facts about every field.
public enum FieldCatalogue {

    /// The full description of a field.
    public static func descriptor(for field: MetadataField) -> FieldDescriptor {
        let row = row(for: field)
        return FieldDescriptor(
            key: field.rawValue,
            label: row.label,
            category: row.category,
            kind: row.kind,
            source: row.source
        )
    }

    /// Every field, described.
    public static var all: [FieldDescriptor] {
        MetadataField.allCases.map(descriptor(for:))
    }

    // MARK: - Tokens

    /// Words a caller might reasonably type for a field whose key is something
    /// else. Lowercased on both sides before comparison.
    static let aliases: [String: MetadataField] = [
        "filename": .name,
        "stem": .baseName,
        "extension": .ext,
        "type": .kind,
        "mime": .uti,
        "contenttype": .uti,
        "bytes": .size,
        "filesize": .size,
        "physicalsize": .sizeOnDisk,
        "comment": .finderComment,
        "downloadedfrom": .whereFrom,
        "createddate": .created,
        "modifieddate": .modified,
        "date": .captured,
        "capturedate": .captured,
        "contentdate": .captured,
        "shot": .shotDate,
        "shootingdate": .shotDate,
        "datetimeoriginal": .shotDate,
        "model": .camera,
        "cameramodel": .camera,
        "lensmodel": .lens,
        "fnumber": .aperture,
        "exposure": .shutterSpeed,
        "exposuretime": .shutterSpeed,
        "isospeed": .iso,
        "description": .caption,
        "creator": .byline,
        "author": .byline,
        "rights": .copyright,
        "lat": .latitude,
        "lon": .longitude,
        "lng": .longitude,
        "gps": .coordinates,
        "key": .musicalKey,
        "tempo": .bpm,
        "length": .duration,
        "runtime": .duration,
        "fps": .framerate,
        "pages": .pageCount,
        "sha": .sha256,
        "checksum": .sha256,
        "crc": .crc32,
    ]

    /// Resolves a typed token to a field, ignoring case, spaces, hyphens and
    /// underscores, and honouring ``aliases``.
    public static func field(forToken token: String) -> MetadataField? {
        let normalised = normalise(token)
        if let direct = MetadataField.allCases.first(where: { normalise($0.rawValue) == normalised }) {
            return direct
        }
        return aliases[normalised]
    }

    /// Strips the punctuation people put in field names and lowercases the rest.
    static func normalise(_ token: String) -> String {
        token.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - The table

    private typealias Row = (label: String, category: FieldCategory, kind: ValueKind, source: FieldSource)

    private static func row(for field: MetadataField) -> Row {
        switch field {

        // General
        case .name:
            (String(localized: "Name", bundle: .module, comment: "Metadata field label: the file's name."), .general, .text, .fileSystem)
        case .baseName: (String(localized: "Base Name", bundle: .module), .general, .text, .fileSystem)
        case .ext:
            (
                String(localized: "Extension", bundle: .module, comment: "Metadata field label: the file name extension."), .general, .text,
                .fileSystem
            )
        case .path:
            (
                String(localized: "Path", bundle: .module, comment: "Metadata field label: the file's full path."), .general, .text,
                .fileSystem
            )
        case .folder:
            (
                String(localized: "Folder", bundle: .module, comment: "Metadata field label: the folder containing the file."), .general,
                .text, .fileSystem
            )
        case .parentFolder: (String(localized: "Parent Folder", bundle: .module), .general, .text, .fileSystem)
        case .relativePath: (String(localized: "Relative Path", bundle: .module), .general, .text, .fileSystem)
        case .kind:
            (
                String(localized: "Kind", bundle: .module, comment: "Metadata field label: the file type as Finder describes it."),
                .general, .text, .fileSystem
            )
        case .uti: (String(localized: "Type Identifier", bundle: .module), .general, .text, .fileSystem)
        case .size:
            (
                String(localized: "Size", bundle: .module, comment: "Metadata field label: the file's size in bytes."), .general, .bytes,
                .fileSystem
            )
        case .sizeOnDisk: (String(localized: "Size on Disk", bundle: .module), .general, .bytes, .fileSystem)
        case .owner:
            (
                String(localized: "Owner", bundle: .module, comment: "Metadata field label: the user account that owns the file."),
                .general, .text, .fileSystem
            )
        case .tags:
            (
                String(localized: "Tags", bundle: .module, comment: "Metadata field label: the file's Finder tags."), .general, .list,
                .fileSystem
            )
        case .finderComment: (String(localized: "Finder Comment", bundle: .module), .general, .text, .fileSystem)
        case .whereFrom: (String(localized: "Downloaded From", bundle: .module), .general, .text, .fileSystem)

        // Dates
        case .created:
            (
                String(localized: "Created", bundle: .module, comment: "Metadata field label: when the file was created."), .dates, .date,
                .fileSystem
            )
        case .modified:
            (
                String(localized: "Modified", bundle: .module, comment: "Metadata field label: when the file was last modified."), .dates,
                .date, .fileSystem
            )
        case .accessed:
            (
                String(localized: "Accessed", bundle: .module, comment: "Metadata field label: when the file was last opened."), .dates,
                .date, .fileSystem
            )
        case .added:
            (
                String(localized: "Added", bundle: .module, comment: "Metadata field label: when the file was added to its folder."),
                .dates, .date, .fileSystem
            )
        case .captured:
            (
                String(localized: "Captured", bundle: .module, comment: "Metadata field label: when the photo or recording was made."),
                .dates, .date, .derived
            )
        case .year:
            (
                String(localized: "Year", bundle: .module, comment: "Metadata field label: the year part of the capture date."), .dates,
                .text, .derived
            )
        case .month:
            (
                String(localized: "Month", bundle: .module, comment: "Metadata field label: the month part of the capture date."), .dates,
                .text, .derived
            )
        case .day:
            (
                String(localized: "Day", bundle: .module, comment: "Metadata field label: the day part of the capture date."), .dates,
                .text, .derived
            )
        case .time:
            (
                String(localized: "Time", bundle: .module, comment: "Metadata field label: the time-of-day part of the capture date."),
                .dates, .text, .derived
            )

        // Image
        case .width: (String(localized: "Width", bundle: .module), .image, .integer, .image)
        case .height: (String(localized: "Height", bundle: .module), .image, .integer, .image)
        case .dimensions: (String(localized: "Dimensions", bundle: .module), .image, .text, .image)
        case .megapixels: (String(localized: "Megapixels", bundle: .module), .image, .decimal, .image)
        case .orientation: (String(localized: "Orientation", bundle: .module), .image, .text, .image)
        case .colorModel: (String(localized: "Colour Model", bundle: .module), .image, .text, .image)
        case .bitDepth: (String(localized: "Bit Depth", bundle: .module), .image, .integer, .image)
        case .dpi: ("DPI", .image, .integer, .image)
        case .hasAlpha: (String(localized: "Has Alpha", bundle: .module), .image, .boolean, .image)
        case .colorProfile: (String(localized: "Colour Profile", bundle: .module), .image, .text, .image)

        // Camera
        case .make:
            (String(localized: "Make", bundle: .module, comment: "Metadata field label: the camera manufacturer."), .camera, .text, .image)
        case .camera: (String(localized: "Camera Model", bundle: .module), .camera, .text, .image)
        case .lens: (String(localized: "Lens Model", bundle: .module), .camera, .text, .image)
        case .focalLength: (String(localized: "Focal Length", bundle: .module), .camera, .text, .image)
        case .focalLength35: (String(localized: "Focal Length (35mm)", bundle: .module), .camera, .text, .image)
        case .aperture: (String(localized: "F Number", bundle: .module), .camera, .text, .image)
        case .shutterSpeed: (String(localized: "Shutter Speed", bundle: .module), .camera, .text, .image)
        case .iso: ("ISO", .camera, .integer, .image)
        case .exposureBias: (String(localized: "Exposure Bias", bundle: .module), .camera, .text, .image)
        case .meteringMode: (String(localized: "Metering Mode", bundle: .module), .camera, .text, .image)
        case .flash:
            (
                String(localized: "Flash", bundle: .module, comment: "Metadata field label: whether and how the camera flash fired."),
                .camera, .text, .image
            )
        case .whiteBalance: (String(localized: "White Balance", bundle: .module), .camera, .text, .image)
        case .software:
            (
                String(localized: "Software", bundle: .module, comment: "Metadata field label: the software that wrote the image."),
                .camera, .text, .image
            )
        case .shotDate: (String(localized: "Shooting Date", bundle: .module), .camera, .date, .image)

        // IPTC
        case .headline: (String(localized: "Headline", bundle: .module), .iptc, .text, .image)
        case .caption: (String(localized: "Caption", bundle: .module), .iptc, .text, .image)
        case .keywords: (String(localized: "Keywords", bundle: .module), .iptc, .list, .image)
        case .credit:
            (
                String(localized: "Credit", bundle: .module, comment: "Metadata field label (IPTC): who to credit for the photo."), .iptc,
                .text, .image
            )
        case .copyright: (String(localized: "Copyright", bundle: .module), .iptc, .text, .image)
        case .byline:
            (
                String(localized: "By-line", bundle: .module, comment: "Metadata field label (IPTC): the photo's creator."), .iptc, .text,
                .image
            )
        case .iptcSource:
            (
                String(
                    localized: "Source", bundle: .module,
                    comment: "Metadata field label (IPTC): the original owner or supplier of the photo."), .iptc, .text, .image
            )
        case .iptcCity: (String(localized: "City", bundle: .module), .iptc, .text, .image)
        case .iptcState:
            (
                String(
                    localized: "State/Province", bundle: .module,
                    comment: "Metadata field label (IPTC): the state or province where the photo was taken."), .iptc, .text, .image
            )
        case .iptcCountry: (String(localized: "Country", bundle: .module), .iptc, .text, .image)

        // Location
        case .latitude: (String(localized: "Latitude", bundle: .module), .location, .coordinate, .image)
        case .longitude: (String(localized: "Longitude", bundle: .module), .location, .coordinate, .image)
        case .coordinates: (String(localized: "Coordinates", bundle: .module), .location, .text, .image)
        case .altitude: (String(localized: "Altitude", bundle: .module), .location, .decimal, .image)

        // Audio
        case .title:
            (
                String(localized: "Title", bundle: .module, comment: "Metadata field label: a song or media title tag."), .audio, .text,
                .media
            )
        case .artist: (String(localized: "Artist", bundle: .module), .audio, .text, .media)
        case .albumArtist: (String(localized: "Album Artist", bundle: .module), .audio, .text, .media)
        case .album: (String(localized: "Album", bundle: .module), .audio, .text, .media)
        case .composer: (String(localized: "Composer", bundle: .module), .audio, .text, .media)
        case .genre: (String(localized: "Genre", bundle: .module), .audio, .text, .media)
        case .releaseYear: (String(localized: "Release Year", bundle: .module), .audio, .text, .media)
        case .track:
            (
                String(localized: "Track", bundle: .module, comment: "Metadata field label: the track number on an album."), .audio, .text,
                .media
            )
        case .disc:
            (
                String(localized: "Disc", bundle: .module, comment: "Metadata field label: the disc number of a multi-disc album."), .audio,
                .text, .media
            )
        case .mediaComment: (String(localized: "Media Comment", bundle: .module), .audio, .text, .media)
        case .bpm: ("BPM", .audio, .text, .media)
        case .musicalKey:
            (
                String(localized: "Key", bundle: .module, comment: "Metadata field label: the musical key of a song (e.g. C minor)."),
                .audio, .text, .media
            )
        case .duration: (String(localized: "Duration", bundle: .module), .audio, .duration, .media)
        case .sampleRate: (String(localized: "Sample Rate", bundle: .module), .audio, .integer, .media)
        case .channels:
            (
                String(localized: "Channels", bundle: .module, comment: "Metadata field label: the number of audio channels."), .audio,
                .integer, .media
            )
        case .audioBitrate: (String(localized: "Audio Bitrate", bundle: .module), .audio, .integer, .media)
        case .audioCodec: (String(localized: "Audio Codec", bundle: .module), .audio, .text, .media)

        // Video
        case .videoWidth: (String(localized: "Video Width", bundle: .module), .video, .integer, .media)
        case .videoHeight: (String(localized: "Video Height", bundle: .module), .video, .integer, .media)
        case .videoDimensions: (String(localized: "Video Dimensions", bundle: .module), .video, .text, .media)
        case .resolution:
            (
                String(
                    localized: "Resolution", bundle: .module, comment: "Metadata field label: a video's resolution class (e.g. 1080p, 4K)."),
                .video, .text, .media
            )
        case .framerate: (String(localized: "Frame Rate", bundle: .module), .video, .decimal, .media)
        case .videoCodec: (String(localized: "Video Codec", bundle: .module), .video, .text, .media)
        case .videoBitrate: (String(localized: "Video Bitrate", bundle: .module), .video, .integer, .media)
        case .hasAudio: (String(localized: "Has Audio", bundle: .module), .video, .boolean, .media)

        // Document
        case .pageCount:
            (
                String(localized: "Pages", bundle: .module, comment: "Metadata field label: the number of pages in a document."), .document,
                .integer, .document
            )
        case .docTitle: (String(localized: "Document Title", bundle: .module), .document, .text, .document)
        case .docAuthor: (String(localized: "Document Author", bundle: .module), .document, .text, .document)
        case .docSubject:
            (
                String(localized: "Subject", bundle: .module, comment: "Metadata field label: a document's subject."), .document, .text,
                .document
            )
        case .docKeywords: (String(localized: "Document Keywords", bundle: .module), .document, .list, .document)
        case .docCreator:
            (
                String(
                    localized: "Created With", bundle: .module, comment: "Metadata field label: the application that created a document."),
                .document, .text, .document
            )
        case .docProducer:
            (
                String(localized: "Producer", bundle: .module, comment: "Metadata field label: the software that produced a PDF."),
                .document, .text, .document
            )
        case .isEncrypted:
            (
                String(localized: "Encrypted", bundle: .module, comment: "Metadata field label: whether a document is encrypted."),
                .document, .boolean, .document
            )
        case .pageSize: (String(localized: "Page Size", bundle: .module), .document, .text, .document)
        case .docCreated: (String(localized: "Document Created", bundle: .module), .document, .date, .document)
        case .docModified: (String(localized: "Document Modified", bundle: .module), .document, .date, .document)

        // Checksums
        case .md5: ("MD5", .checksum, .text, .checksum)
        case .sha1: ("SHA-1", .checksum, .text, .checksum)
        case .sha256: ("SHA-256", .checksum, .text, .checksum)
        case .sha384: ("SHA-384", .checksum, .text, .checksum)
        case .sha512: ("SHA-512", .checksum, .text, .checksum)
        case .crc32: ("CRC-32", .checksum, .text, .checksum)
        }
    }
}
