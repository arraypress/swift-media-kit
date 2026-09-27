//
//  MediaRaw.swift
//  MediaMetadata
//
//  Every metadata item AVFoundation will hand over, from every key space the
//  file actually carries.
//
//  The SDK declares 294 metadata identifiers — 93 for ID3, 73 for QuickTime's
//  `mdta`, 39 for QuickTime user data, the rest iTunes and ISO — and a file is
//  free to carry keys outside all of them. So rather than asking for a list of
//  identifiers, this asks the asset which formats it has and reads all of
//  each, which covers the declared keys and the undeclared ones alike.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import CoreMedia
import Foundation

/// Reads every tag in a media file, addressed as `id3.TPE1` or `mdta.com.apple.quicktime.model`.
public enum MediaRaw {

    /// Every metadata item in every format the file carries, plus a summary of
    /// each track.
    public static func read(_ url: URL) async -> [String: FieldValue] {
        let asset = AVURLAsset(url: url)
        var values: [String: FieldValue] = [:]

        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                guard let items = try? await asset.loadMetadata(for: format) else { continue }
                await collect(items, into: &values)
            }
        }
        // `.metadata` can carry items that belong to no advertised format.
        if let items = try? await asset.load(.metadata) {
            await collect(items, into: &values)
        }

        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 { values["asset.duration"] = .duration(seconds) }
        }
        if let tracks = try? await asset.load(.tracks) {
            await collectTracks(tracks, into: &values)
        }

        return values
    }

    // MARK: - Items

    private static func collect(
        _ items: [AVMetadataItem],
        into values: inout [String: FieldValue]
    ) async {
        for item in items {
            guard let path = path(for: item) else { continue }
            if values[path] != nil { continue }
            if let value = await value(of: item) {
                values[path] = value
            }
        }
    }

    /// `id3/TPE1` becomes `id3.TPE1`.
    ///
    /// Identifiers are already namespaced by key space, which is exactly the
    /// addressing wanted here — so the only work is choosing a separator and
    /// falling back to the raw key for an item that has no identifier.
    static func path(for item: AVMetadataItem) -> String? {
        if let identifier = item.identifier?.rawValue, !identifier.isEmpty {
            let parts = identifier.split(separator: "/", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return "\(sanitise(parts[0])).\(sanitise(parts[1]))"
            }
            return sanitise(identifier)
        }
        guard let key = item.key?.description, !key.isEmpty else { return nil }
        let space = item.keySpace?.rawValue ?? "unknown"
        return "\(sanitise(space)).\(sanitise(key))"
    }

    /// Strips the characters that would make a key unquotable on a command line.
    ///
    /// iTunes keys begin with a copyright sign — `©nam` — which AVFoundation
    /// reports percent-encoded as `%A9nam`. That escape is Latin-1, not UTF-8,
    /// so `removingPercentEncoding` returns nil for it and the sigil has to be
    /// dropped by hand; otherwise the key reads `A9nam`, which looks like data
    /// and is not.
    static func sanitise(_ token: String) -> String {
        let decoded = token.removingPercentEncoding
            ?? token.replacing(/%[0-9A-Fa-f]{2}/, with: "")
        let cleaned = decoded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            if scalar == "." || scalar == "-" || scalar == "_" { return Character(scalar) }
            return "_"
        }
        return String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    /// The item's value in whatever shape it actually holds.
    static func value(of item: AVMetadataItem) async -> FieldValue? {
        if let string = try? await item.load(.stringValue), !string.isEmpty {
            return .text(string)
        }
        if let number = try? await item.load(.numberValue) {
            return RawValue.convert(number)
        }
        if let date = try? await item.load(.dateValue) {
            return .date(date)
        }
        if let data = try? await item.load(.dataValue) {
            return .text("<\(data.count) bytes>")
        }
        return nil
    }

    // MARK: - Tracks

    private static func collectTracks(
        _ tracks: [AVAssetTrack],
        into values: inout [String: FieldValue]
    ) async {
        for (index, track) in tracks.enumerated() {
            let prefix = "track\(index)"
            values["\(prefix).mediaType"] = .text(track.mediaType.rawValue)
            values["\(prefix).trackID"] = .integer(Int(track.trackID))

            if let enabled = try? await track.load(.isEnabled) {
                values["\(prefix).enabled"] = .boolean(enabled)
            }
            if let language = try? await track.load(.languageCode), !language.isEmpty {
                values["\(prefix).language"] = .text(language)
            }
            if let rate = try? await track.load(.estimatedDataRate), rate > 0 {
                values["\(prefix).dataRate"] = .integer(Int(rate))
            }
            if let duration = try? await track.load(.timeRange) {
                let seconds = CMTimeGetSeconds(duration.duration)
                if seconds.isFinite, seconds > 0 { values["\(prefix).duration"] = .duration(seconds) }
            }
            if let size = try? await track.load(.naturalSize), size.width > 0 {
                values["\(prefix).width"] = .integer(Int(size.width))
                values["\(prefix).height"] = .integer(Int(size.height))
            }
            if let rate = try? await track.load(.nominalFrameRate), rate > 0 {
                values["\(prefix).frameRate"] = .decimal(Double((rate * 100).rounded() / 100))
            }
            if let descriptions = try? await track.load(.formatDescriptions),
               let description = descriptions.first {
                let code = CMFormatDescriptionGetMediaSubType(description)
                let bytes = withUnsafeBytes(of: code.bigEndian) { Data($0) }
                if let raw = String(data: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces),
                   !raw.isEmpty {
                    values["\(prefix).codec"] = .text(raw)
                    values["\(prefix).codecName"] = .text(Lookup.codecName(raw))
                }
                if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
                    if basic.mSampleRate > 0 { values["\(prefix).sampleRate"] = .integer(Int(basic.mSampleRate)) }
                    if basic.mChannelsPerFrame > 0 {
                        values["\(prefix).channels"] = .integer(Int(basic.mChannelsPerFrame))
                    }
                    if basic.mBitsPerChannel > 0 {
                        values["\(prefix).bitsPerChannel"] = .integer(Int(basic.mBitsPerChannel))
                    }
                }
            }
        }
    }
}
