//
//  MetadataField.swift
//  MediaMetadata
//
//  The catalogue of everything this package can answer about a file.
//
//  One flat list rather than a type per media kind, because the caller's
//  question is flat: a folder holds photographs beside invoices beside
//  recordings, and the answer is one table with a column per field and an
//  empty cell where a field does not apply. A file is never asked whether it
//  "is an image" — it is asked for `camera`, and says nothing if it has none.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A single fact about a file.
///
/// The raw value is the token a caller types. Labels, categories, value shapes
/// and costs come from ``descriptor``.
public enum MetadataField: String, Sendable, CaseIterable, Codable, Hashable {

    // MARK: - General

    /// File name including the extension.
    case name
    /// File name with the extension removed.
    case baseName
    /// The extension, lowercased, without its dot.
    case ext
    /// Full path.
    case path
    /// Name of the folder holding the file.
    case folder
    /// Name of that folder's parent.
    case parentFolder
    /// Path relative to the root the scan started from.
    case relativePath
    /// What Finder calls it: "JPEG image", "PDF document".
    case kind
    /// Apple's uniform type identifier: `public.jpeg`.
    case uti
    /// Logical size in bytes.
    case size
    /// Bytes actually allocated on disk, which differs on a compressed volume.
    case sizeOnDisk
    /// The account that owns the file.
    case owner
    /// Finder tags.
    case tags
    /// The Finder comment.
    case finderComment
    /// Where a downloaded file came from.
    case whereFrom

    // MARK: - Dates

    /// When the file was created on this volume.
    case created
    /// When its contents last changed.
    case modified
    /// When it was last opened.
    case accessed
    /// When it was added to the folder it is in.
    case added
    /// When the *content* was made — capture time for a photo, container date
    /// for media, and the file's own creation date for everything else.
    case captured
    /// Four-digit year of ``captured``.
    case year
    /// Two-digit month of ``captured``.
    case month
    /// Two-digit day of ``captured``.
    case day
    /// Time of day of ``captured``.
    case time

    // MARK: - Image

    /// Pixel width.
    case width
    /// Pixel height.
    case height
    /// Width and height together: `4000x3000`.
    case dimensions
    /// Pixels in millions, to one decimal place.
    case megapixels
    /// Landscape, Portrait or Square.
    case orientation
    /// RGB, CMYK, Gray.
    case colorModel
    /// Bits per sample.
    case bitDepth
    /// Dots per inch, when the file records any.
    case dpi
    /// Whether an alpha channel is present.
    case hasAlpha
    /// The embedded ICC profile's name.
    case colorProfile

    // MARK: - Camera

    /// Manufacturer of the camera.
    case make
    /// Camera model.
    case camera
    /// Lens model.
    case lens
    /// Focal length in millimetres.
    case focalLength
    /// Focal length expressed for a 35 mm frame.
    case focalLength35
    /// Aperture as an f-number.
    case aperture
    /// Exposure time, as a fraction of a second where that reads better.
    case shutterSpeed
    /// ISO sensitivity.
    case iso
    /// Exposure compensation in stops.
    case exposureBias
    /// How the camera metered the scene.
    case meteringMode
    /// Whether the flash fired.
    case flash
    /// White balance setting.
    case whiteBalance
    /// Software that last wrote the file.
    case software
    /// EXIF `DateTimeOriginal` — when the shutter opened.
    case shotDate

    // MARK: - IPTC

    /// The photographer's one-line headline.
    case headline
    /// The caption or description.
    case caption
    /// Keywords the photographer assigned.
    case keywords
    /// Credit line.
    case credit
    /// Copyright notice.
    case copyright
    /// By-line — who made the picture.
    case byline
    /// Who supplied it.
    case iptcSource
    /// City, as written into the file rather than looked up.
    case iptcCity
    /// State or province, as written into the file.
    case iptcState
    /// Country, as written into the file.
    case iptcCountry

    // MARK: - Location

    /// Latitude in signed degrees.
    case latitude
    /// Longitude in signed degrees.
    case longitude
    /// Both, formatted together.
    case coordinates
    /// Metres above sea level.
    case altitude

    // MARK: - Audio

    /// Track title.
    case title
    /// Performing artist.
    case artist
    /// Album artist, where it differs.
    case albumArtist
    /// Album name.
    case album
    /// Composer.
    case composer
    /// Genre.
    case genre
    /// Year of release, from the tags.
    case releaseYear
    /// Track number.
    case track
    /// Disc number.
    case disc
    /// The comment written into the tags.
    case mediaComment
    /// Beats per minute.
    case bpm
    /// Musical key.
    case musicalKey
    /// Running time in seconds.
    case duration
    /// Samples per second.
    case sampleRate
    /// Channel count.
    case channels
    /// Audio data rate in bits per second.
    case audioBitrate
    /// Audio codec, four character code resolved to a name where known.
    case audioCodec

    // MARK: - Video

    /// Pixel width of the video track.
    case videoWidth
    /// Pixel height of the video track.
    case videoHeight
    /// Both together.
    case videoDimensions
    /// The shorthand a person uses: 1080p, 4K.
    case resolution
    /// Frames per second.
    case framerate
    /// Video codec.
    case videoCodec
    /// Video data rate in bits per second.
    case videoBitrate
    /// Whether the file carries a sound track.
    case hasAudio

    // MARK: - Document

    /// Number of pages.
    case pageCount
    /// Title from the document's own properties.
    case docTitle
    /// Author from the document's own properties.
    case docAuthor
    /// Subject.
    case docSubject
    /// Keywords.
    case docKeywords
    /// The application that created it.
    case docCreator
    /// The library that wrote the file.
    case docProducer
    /// Whether the document is encrypted.
    case isEncrypted
    /// Page size of the first page, in points and as a paper name where one fits.
    case pageSize
    /// The creation date the document records about itself.
    case docCreated
    /// The modification date the document records about itself.
    case docModified

    // MARK: - Checksums

    /// MD5 digest.
    case md5
    /// SHA-1 digest.
    case sha1
    /// SHA-256 digest.
    case sha256
    /// SHA-384 digest.
    case sha384
    /// SHA-512 digest.
    case sha512
    /// CRC-32 checksum.
    case crc32

    // MARK: - Description

    /// What this field is called, where it belongs, its shape and its cost.
    public var descriptor: FieldDescriptor { FieldCatalogue.descriptor(for: self) }

    /// The token a caller types.
    public var key: String { rawValue }

    /// The heading to print above the column.
    public var label: String { descriptor.label }

    /// The group it belongs to.
    public var category: FieldCategory { descriptor.category }

    /// The shape of its values.
    public var kind: ValueKind { descriptor.kind }

    /// What has to be opened to answer it.
    public var source: FieldSource { descriptor.source }

    // MARK: - Lookup

    /// Resolves a token a person typed, ignoring case, spacing and a handful
    /// of synonyms.
    ///
    /// Aliases exist because the obvious word and the precise one are rarely
    /// the same: `shot` for ``shotDate``, `fnumber` for ``aperture``, `mime`
    /// for ``uti``. A caller who guesses gets an answer instead of an error.
    public init?(token: String) {
        guard let field = FieldCatalogue.field(forToken: token) else { return nil }
        self = field
    }

    /// Every field in a category, in declaration order.
    public static func fields(in category: FieldCategory) -> [MetadataField] {
        allCases.filter { $0.category == category }
    }

    /// Every field answerable without opening the file.
    public static var freeFields: [MetadataField] {
        allCases.filter { !$0.source.opensTheFile }
    }
}
