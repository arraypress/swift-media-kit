//
//  FieldCatalogue.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//
//  The table behind ``MetadataField``. One row per field, so a label, a
//  category, a value shape and a cost are declared in exactly one place and
//  cannot drift apart.
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
        "crc": .crc32
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
        case .name: ("Name", .general, .text, .fileSystem)
        case .baseName: ("Base Name", .general, .text, .fileSystem)
        case .ext: ("Extension", .general, .text, .fileSystem)
        case .path: ("Path", .general, .text, .fileSystem)
        case .folder: ("Folder", .general, .text, .fileSystem)
        case .parentFolder: ("Parent Folder", .general, .text, .fileSystem)
        case .relativePath: ("Relative Path", .general, .text, .fileSystem)
        case .kind: ("Kind", .general, .text, .fileSystem)
        case .uti: ("Type Identifier", .general, .text, .fileSystem)
        case .size: ("Size", .general, .bytes, .fileSystem)
        case .sizeOnDisk: ("Size on Disk", .general, .bytes, .fileSystem)
        case .owner: ("Owner", .general, .text, .fileSystem)
        case .tags: ("Tags", .general, .list, .fileSystem)
        case .finderComment: ("Finder Comment", .general, .text, .fileSystem)
        case .whereFrom: ("Downloaded From", .general, .text, .fileSystem)

        // Dates
        case .created: ("Created", .dates, .date, .fileSystem)
        case .modified: ("Modified", .dates, .date, .fileSystem)
        case .accessed: ("Accessed", .dates, .date, .fileSystem)
        case .added: ("Added", .dates, .date, .fileSystem)
        case .captured: ("Captured", .dates, .date, .derived)
        case .year: ("Year", .dates, .text, .derived)
        case .month: ("Month", .dates, .text, .derived)
        case .day: ("Day", .dates, .text, .derived)
        case .time: ("Time", .dates, .text, .derived)

        // Image
        case .width: ("Width", .image, .integer, .image)
        case .height: ("Height", .image, .integer, .image)
        case .dimensions: ("Dimensions", .image, .text, .image)
        case .megapixels: ("Megapixels", .image, .decimal, .image)
        case .orientation: ("Orientation", .image, .text, .image)
        case .colorModel: ("Colour Model", .image, .text, .image)
        case .bitDepth: ("Bit Depth", .image, .integer, .image)
        case .dpi: ("DPI", .image, .integer, .image)
        case .hasAlpha: ("Has Alpha", .image, .boolean, .image)
        case .colorProfile: ("Colour Profile", .image, .text, .image)

        // Camera
        case .make: ("Make", .camera, .text, .image)
        case .camera: ("Camera Model", .camera, .text, .image)
        case .lens: ("Lens Model", .camera, .text, .image)
        case .focalLength: ("Focal Length", .camera, .text, .image)
        case .focalLength35: ("Focal Length (35mm)", .camera, .text, .image)
        case .aperture: ("F Number", .camera, .text, .image)
        case .shutterSpeed: ("Shutter Speed", .camera, .text, .image)
        case .iso: ("ISO", .camera, .integer, .image)
        case .exposureBias: ("Exposure Bias", .camera, .text, .image)
        case .meteringMode: ("Metering Mode", .camera, .text, .image)
        case .flash: ("Flash", .camera, .text, .image)
        case .whiteBalance: ("White Balance", .camera, .text, .image)
        case .software: ("Software", .camera, .text, .image)
        case .shotDate: ("Shooting Date", .camera, .date, .image)

        // IPTC
        case .headline: ("Headline", .iptc, .text, .image)
        case .caption: ("Caption", .iptc, .text, .image)
        case .keywords: ("Keywords", .iptc, .list, .image)
        case .credit: ("Credit", .iptc, .text, .image)
        case .copyright: ("Copyright", .iptc, .text, .image)
        case .byline: ("By-line", .iptc, .text, .image)
        case .iptcSource: ("Source", .iptc, .text, .image)
        case .iptcCity: ("City", .iptc, .text, .image)
        case .iptcState: ("State/Province", .iptc, .text, .image)
        case .iptcCountry: ("Country", .iptc, .text, .image)

        // Location
        case .latitude: ("Latitude", .location, .coordinate, .image)
        case .longitude: ("Longitude", .location, .coordinate, .image)
        case .coordinates: ("Coordinates", .location, .text, .image)
        case .altitude: ("Altitude", .location, .decimal, .image)

        // Audio
        case .title: ("Title", .audio, .text, .media)
        case .artist: ("Artist", .audio, .text, .media)
        case .albumArtist: ("Album Artist", .audio, .text, .media)
        case .album: ("Album", .audio, .text, .media)
        case .composer: ("Composer", .audio, .text, .media)
        case .genre: ("Genre", .audio, .text, .media)
        case .releaseYear: ("Release Year", .audio, .text, .media)
        case .track: ("Track", .audio, .text, .media)
        case .disc: ("Disc", .audio, .text, .media)
        case .mediaComment: ("Media Comment", .audio, .text, .media)
        case .bpm: ("BPM", .audio, .text, .media)
        case .musicalKey: ("Key", .audio, .text, .media)
        case .duration: ("Duration", .audio, .duration, .media)
        case .sampleRate: ("Sample Rate", .audio, .integer, .media)
        case .channels: ("Channels", .audio, .integer, .media)
        case .audioBitrate: ("Audio Bitrate", .audio, .integer, .media)
        case .audioCodec: ("Audio Codec", .audio, .text, .media)

        // Video
        case .videoWidth: ("Video Width", .video, .integer, .media)
        case .videoHeight: ("Video Height", .video, .integer, .media)
        case .videoDimensions: ("Video Dimensions", .video, .text, .media)
        case .resolution: ("Resolution", .video, .text, .media)
        case .framerate: ("Frame Rate", .video, .decimal, .media)
        case .videoCodec: ("Video Codec", .video, .text, .media)
        case .videoBitrate: ("Video Bitrate", .video, .integer, .media)
        case .hasAudio: ("Has Audio", .video, .boolean, .media)

        // Document
        case .pageCount: ("Pages", .document, .integer, .document)
        case .docTitle: ("Document Title", .document, .text, .document)
        case .docAuthor: ("Document Author", .document, .text, .document)
        case .docSubject: ("Subject", .document, .text, .document)
        case .docKeywords: ("Document Keywords", .document, .list, .document)
        case .docCreator: ("Created With", .document, .text, .document)
        case .docProducer: ("Producer", .document, .text, .document)
        case .isEncrypted: ("Encrypted", .document, .boolean, .document)
        case .pageSize: ("Page Size", .document, .text, .document)
        case .docCreated: ("Document Created", .document, .date, .document)
        case .docModified: ("Document Modified", .document, .date, .document)

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
