//
//  MediaFacts.swift
//  MediaMetadata
//
//  Tags and stream facts for anything AVFoundation will open.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import CoreMedia
import Foundation

/// Reads audio and video fields from a single `AVURLAsset`.
public enum MediaFacts {

    /// Fills in every media-sourced field the caller asked for.
    public static func read(
        _ url: URL,
        wanted: Set<MetadataField>,
        into values: inout [MetadataField: FieldValue]
    ) async {
        let asset = AVURLAsset(url: url)
        guard
            let (common, all, duration, tracks) = try? await asset.load(
                .commonMetadata, .metadata, .duration, .tracks
            )
        else { return }

        func put(_ field: MetadataField, _ value: FieldValue?) {
            guard wanted.contains(field), let value, !value.isEmpty else { return }
            values[field] = value
        }

        await readTags(common: common, all: all, put: put)
        await readTracks(tracks, put: put)

        let seconds = CMTimeGetSeconds(duration)
        if seconds.isFinite, seconds > 0 {
            put(.duration, .duration(seconds))
        }
        put(.hasAudio, .boolean(tracks.contains { $0.mediaType == .audio }))

        if let creation = try? await asset.load(.creationDate),
            let date = try? await creation.load(.dateValue)
        {
            put(.captured, .date(date))
        }

        await readLocation(all, put: put)
    }

    // MARK: - Tags

    private static func readTags(
        common: [AVMetadataItem],
        all: [AVMetadataItem],
        put: (MetadataField, FieldValue?) -> Void
    ) async {
        /// A value from the common key space, which only a handful of tags use.
        func commonValue(_ key: AVMetadataKey) async -> String? {
            guard let item = common.first(where: { $0.commonKey == key }) else { return nil }
            return try? await item.load(.stringValue)
        }

        /// A value from the first identifier that carries one.
        func value(_ identifiers: AVMetadataIdentifier...) async -> String? {
            for identifier in identifiers {
                for item in AVMetadataItem.metadataItems(from: all, filteredByIdentifier: identifier) {
                    if let string = try? await item.load(.stringValue), !string.isEmpty { return string }
                    if let number = try? await item.load(.numberValue) { return number.stringValue }
                }
            }
            return nil
        }

        put(.title, await commonValue(.commonKeyTitle).map { .text($0) })
        put(.artist, await commonValue(.commonKeyArtist).map { .text($0) })
        put(.album, await commonValue(.commonKeyAlbumName).map { .text($0) })

        put(
            .albumArtist,
            await value(
                .iTunesMetadataAlbumArtist, .id3MetadataBand
            ).map { .text($0) })

        // Genre, track and tempo are NOT common keys and never resolve as one.
        // Asked for that way they come back empty from every file that has
        // them, which is the quietest possible bug: the column is there, the
        // data is there, and the cells are blank.
        put(
            .genre,
            await value(
                .iTunesMetadataUserGenre, .iTunesMetadataPredefinedGenre,
                .id3MetadataContentType, .quickTimeMetadataGenre,
                .quickTimeUserDataGenre
            ).map { .text($0) })

        put(
            .bpm,
            await value(
                .id3MetadataBeatsPerMinute, .iTunesMetadataBeatsPerMin
            ).map { .text($0) })

        put(.musicalKey, await value(.id3MetadataInitialKey).map { .text($0) })

        put(
            .mediaComment,
            await value(
                .id3MetadataComments, .iTunesMetadataUserComment, .quickTimeUserDataComment
            ).map { .text($0) })

        if let composer = await value(.id3MetadataComposer, .iTunesMetadataComposer) {
            put(.composer, .text(composer))
        } else {
            put(.composer, await commonValue(.commonKeyCreator).map { .text($0) })
        }

        put(.track, await trackNumber(in: all).map { .text($0) })
        put(.disc, await discNumber(in: all).map { .text($0) })

        if let year = await value(
            .id3MetadataYear, .id3MetadataRecordingTime,
            .iTunesMetadataReleaseDate, .quickTimeMetadataYear,
            .quickTimeUserDataCreationDate
        ), let match = year.range(of: #"\d{4}"#, options: .regularExpression) {
            put(.releaseYear, .text(String(year[match])))
        }
    }

    /// iTunes packs the track number as binary; ID3 writes it as `3/12`.
    ///
    /// Two formats, two shapes, and neither answers to `stringValue` the way
    /// the other does — which is why this is a function and not a lookup.
    private static func trackNumber(in items: [AVMetadataItem]) async -> String? {
        await packedNumber(in: items, iTunes: .iTunesMetadataTrackNumber, id3: .id3MetadataTrackNumber)
    }

    private static func discNumber(in items: [AVMetadataItem]) async -> String? {
        await packedNumber(in: items, iTunes: .iTunesMetadataDiscNumber, id3: .id3MetadataPartOfASet)
    }

    private static func packedNumber(
        in items: [AVMetadataItem],
        iTunes: AVMetadataIdentifier,
        id3: AVMetadataIdentifier
    ) async -> String? {
        for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: iTunes) {
            if let number = try? await item.load(.numberValue) { return number.stringValue }
            // The payload is a packed big-endian record; the number sits in
            // bytes 2 and 3.
            if let data = try? await item.load(.dataValue), data.count >= 4 {
                let value = Int(data[data.startIndex + 2]) << 8 | Int(data[data.startIndex + 3])
                if value > 0 { return String(value) }
            }
        }
        for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id3) {
            if let string = try? await item.load(.stringValue),
                let first = string.split(separator: "/").first, !first.isEmpty
            {
                return String(first)
            }
        }
        return nil
    }

    // MARK: - Tracks

    private static func readTracks(
        _ tracks: [AVAssetTrack],
        put: (MetadataField, FieldValue?) -> Void
    ) async {
        if let audio = tracks.first(where: { $0.mediaType == .audio }) {
            if let descriptions = try? await audio.load(.formatDescriptions),
                let description = descriptions.first
            {
                if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
                    if basic.mSampleRate > 0 { put(.sampleRate, .integer(Int(basic.mSampleRate))) }
                    if basic.mChannelsPerFrame > 0 { put(.channels, .integer(Int(basic.mChannelsPerFrame))) }
                }
                put(.audioCodec, .text(Lookup.codecName(fourCharCode(description))))
            }
            if let rate = try? await audio.load(.estimatedDataRate), rate > 0 {
                put(.audioBitrate, .integer(Int(rate)))
            }
        }

        guard let video = tracks.first(where: { $0.mediaType == .video }) else { return }

        if let size = try? await video.load(.naturalSize), size.width > 0, size.height > 0 {
            // The stored frame and the displayed frame differ whenever a clip
            // carries a rotation — phone video shot upright is the common case.
            let transform = (try? await video.load(.preferredTransform)) ?? .identity
            let displayed = size.applying(transform)
            let width = Int(abs(displayed.width).rounded())
            let height = Int(abs(displayed.height).rounded())
            put(.videoWidth, .integer(width))
            put(.videoHeight, .integer(height))
            put(.videoDimensions, .text(Format.dimensions(width, height)))
            put(.resolution, .text(Format.resolutionLabel(width: width, height: height)))
        }
        if let rate = try? await video.load(.nominalFrameRate), rate > 0 {
            put(.framerate, .decimal(Double((rate * 100).rounded() / 100)))
        }
        if let rate = try? await video.load(.estimatedDataRate), rate > 0 {
            put(.videoBitrate, .integer(Int(rate)))
        }
        if let descriptions = try? await video.load(.formatDescriptions), let description = descriptions.first {
            put(.videoCodec, .text(Lookup.codecName(fourCharCode(description))))
        }
    }

    /// The media subtype as its four characters.
    private static func fourCharCode(_ description: CMFormatDescription) -> String {
        let code = CMFormatDescriptionGetMediaSubType(description)
        let bytes = withUnsafeBytes(of: code.bigEndian) { Data($0) }
        return String(data: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    // MARK: - Location

    private static func readLocation(
        _ items: [AVMetadataItem],
        put: (MetadataField, FieldValue?) -> Void
    ) async {
        // `mdta` is what a phone writes and `udta` what older cameras do.
        // 3GP has an identifier of its own, but its Objective-C name begins
        // with a digit and is not importable into Swift — files carrying it
        // still come through the raw reader.
        for identifier in [
            AVMetadataIdentifier.quickTimeMetadataLocationISO6709,
            .quickTimeUserDataLocationISO6709,
        ] {
            for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier) {
                guard let string = try? await item.load(.stringValue),
                    let coordinate = ISO6709.parse(string)
                else { continue }
                put(.latitude, .coordinate(coordinate.latitude))
                put(.longitude, .coordinate(coordinate.longitude))
                put(.coordinates, .text(coordinate.formatted))
                if let altitude = coordinate.altitude {
                    put(.altitude, .decimal((altitude * 10).rounded() / 10))
                }
                return
            }
        }
    }
}
