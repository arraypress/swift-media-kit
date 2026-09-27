//
//  Corpus.swift
//  MediaMetadataTests
//
//  A corpus of real files in real formats, generated rather than committed.
//
//  Images come from ImageIO's own list of writable types, so the set grows
//  with the SDK instead of with this file. Audio and video come from ffmpeg,
//  because AVFoundation writes only the handful of containers Apple ships an
//  encoder for, and a reader that has only ever seen Apple's own output is not
//  a reader anybody can point at a folder.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import MediaMetadata

enum Corpus {

    /// Tags written into every generated media file, asserted on the way back.
    enum Tags {
        static let title = "Around the World"
        static let artist = "Daft Punk"
        static let album = "Homework"
        static let genre = "House"
        static let year = "1997"
        static let track = "3"
        static let comment = "generated for tests"
    }

    static let videoSize = (width: 320, height: 240)
    static let seconds = 1

    // MARK: - Availability

    /// Where ffmpeg is, when it is installed at all.
    ///
    /// Not a dependency: the suite falls back to the formats AVFoundation and
    /// ImageIO can write themselves, and skips the rest rather than failing on
    /// a machine that has no ffmpeg.
    static let ffmpeg: URL? = {
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }()

    // MARK: - Images

    /// One writable image type, and the file made from it.
    struct ImageSample {
        let type: UTType
        let url: URL
    }

    /// Every image type this machine can write, straight from ImageIO, so the corpus tracks the
    /// OS rather than a hand-kept list. Filtered to actual images: the list includes PDF.
    static var writableImageTypes: [UTType] {
        let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return
            identifiers
            .compactMap { UTType($0) }
            .filter { $0.conforms(to: .image) && $0.preferredFilenameExtension != nil }
    }

    /// Writes one image of every writable type into `directory`.
    static func writeImages(into directory: URL) -> [ImageSample] {
        let context = CGContext(
            data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        let image = context.makeImage()!

        var samples: [ImageSample] = []
        for type in writableImageTypes {
            guard let ext = type.preferredFilenameExtension else { continue }
            let url = directory.appendingPathComponent("image-\(ext).\(ext)")
            guard
                let destination = CGImageDestinationCreateWithURL(
                    url as CFURL, type.identifier as CFString, 1, nil
                )
            else { continue }

            // Every format is handed the same metadata. Most ignore most of
            // it, which is itself worth knowing.
            let properties: [CFString: Any] = [
                kCGImagePropertyTIFFDictionary: [
                    kCGImagePropertyTIFFMake: "Nikon",
                    kCGImagePropertyTIFFModel: "NIKON Z 6",
                ] as [CFString: Any],
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifLensModel: "NIKKOR Z 24-70mm f/4 S",
                    kCGImagePropertyExifDateTimeOriginal: "2026:06:27 13:42:11",
                ] as [CFString: Any],
            ]
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination),
                FileManager.default.fileExists(atPath: url.path)
            else { continue }
            samples.append(ImageSample(type: type, url: url))
        }
        return samples
    }

    // MARK: - Audio and video

    /// A generated media file and what it was supposed to contain.
    struct MediaSample {
        let name: String
        let url: URL
        let expectedKind: MediaKind
        /// Whether the container carries the tags ffmpeg was given.
        let carriesTags: Bool
    }

    /// The containers and codec pairings worth proving.
    ///
    /// Chosen to cover what actually arrives in a delivery folder: Apple's own
    /// formats, the web's, the broadcast ones, and two that AVFoundation is
    /// expected to refuse — a reader has to be honest about those rather than
    /// report an empty row as though the file were empty.
    static let mediaRecipes: [(name: String, arguments: [String], kind: MediaKind, tags: Bool)] = [
        ("h264.mp4", ["-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac"], .video, true),
        ("hevc.mp4", ["-c:v", "libx265", "-preset", "ultrafast", "-tag:v", "hvc1", "-pix_fmt", "yuv420p", "-c:a", "aac"], .video, true),
        ("prores.mov", ["-c:v", "prores_ks", "-profile:v", "0", "-c:a", "pcm_s16le"], .video, true),
        ("mpeg4.avi", ["-c:v", "mpeg4", "-c:a", "libmp3lame"], .video, false),
        ("vp9.webm", ["-c:v", "libvpx-vp9", "-deadline", "realtime", "-cpu-used", "8", "-c:a", "libopus"], .video, false),
        ("h264.mkv", ["-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac"], .video, false),
        ("aac.m4a", ["-vn", "-c:a", "aac"], .audio, true),
        ("alac.m4a", ["-vn", "-c:a", "alac"], .audio, true),
        ("lame.mp3", ["-vn", "-c:a", "libmp3lame", "-write_id3v2", "1"], .audio, true),
        ("pcm.wav", ["-vn", "-c:a", "pcm_s16le"], .audio, false),
        ("pcm.aiff", ["-vn", "-c:a", "pcm_s16be"], .audio, true),
        ("flac.flac", ["-vn", "-c:a", "flac"], .audio, true),
        ("opus.opus", ["-vn", "-c:a", "libopus"], .audio, false),
        ("pcm.caf", ["-vn", "-c:a", "pcm_s16le"], .audio, false),
    ]

    /// Generates every recipe ffmpeg can complete, returning what it produced.
    static func writeMedia(into directory: URL) throws -> [MediaSample] {
        guard let ffmpeg else { return [] }
        var samples: [MediaSample] = []

        for recipe in mediaRecipes {
            let url = directory.appendingPathComponent(recipe.name)
            var arguments = [
                "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "testsrc=size=\(videoSize.width)x\(videoSize.height):rate=25:duration=\(seconds)",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=\(seconds)",
            ]
            arguments += recipe.arguments
            arguments += [
                "-metadata", "title=\(Tags.title)",
                "-metadata", "artist=\(Tags.artist)",
                "-metadata", "album=\(Tags.album)",
                "-metadata", "genre=\(Tags.genre)",
                "-metadata", "date=\(Tags.year)",
                "-metadata", "track=\(Tags.track)",
                "-metadata", "comment=\(Tags.comment)",
                url.path,
            ]

            guard run(ffmpeg, arguments), FileManager.default.fileExists(atPath: url.path) else { continue }
            samples.append(
                MediaSample(
                    name: recipe.name, url: url, expectedKind: recipe.kind, carriesTags: recipe.tags
                ))
        }
        return samples
    }

    /// Runs a tool and reports whether it succeeded.
    @discardableResult
    static func run(_ tool: URL, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
