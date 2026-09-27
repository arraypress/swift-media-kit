//
//  Fixtures.swift
//  MediaMetadataTests
//
//  Files written with metadata this test suite chose, so every assertion has a
//  known right answer rather than whatever happened to be on the disk.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(PDFKit)
import PDFKit
#endif

enum Fixtures {

    /// A scratch directory for one test, deleted by the caller.
    static func directory(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-metadata-tests-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Images

    /// What ``writeImage(to:)`` puts in the file. Every value here is asserted
    /// on the way back out.
    enum Photo {
        static let width = 120
        static let height = 80
        static let make = "Nikon"
        static let model = "NIKON Z 6"
        static let lens = "NIKKOR Z 24-70mm f/4 S"
        static let software = "MediaMetadata Tests"
        static let iso = 320
        static let fNumber = 4.0
        static let exposureTime = 1.0 / 250
        static let focalLength = 35.0
        static let focalLength35 = 52.0
        static let exposureBias = 0.5
        static let meteringMode = 5
        static let flash = 0x19
        static let dateOriginal = "2026:06:27 13:42:11"
        static let headline = "Larsen Wedding"
        static let caption = "The first dance, shot from the balcony."
        static let keywords = ["wedding", "larsen", "reception"]
        static let credit = "David Sherlock"
        static let copyright = "© 2026 ArrayPress"
        static let byline = "D. Sherlock"
        static let source = "ArrayPress"
        static let city = "Kyoto"
        static let state = "Kyoto Prefecture"
        static let country = "Japan"
        static let latitude = 35.011_636
        static let longitude = 135.768_029
        static let altitude = 56.4
    }

    /// Writes a JPEG carrying every ``Photo`` value.
    @discardableResult
    static func writeImage(to url: URL, orientation: Int = 1) throws -> URL {
        let context = CGContext(
            data: nil,
            width: Photo.width, height: Photo.height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Photo.width, height: Photo.height))
        let image = context.makeImage()!

        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: Photo.make,
                kCGImagePropertyTIFFModel: Photo.model,
                kCGImagePropertyTIFFSoftware: Photo.software,
                kCGImagePropertyTIFFOrientation: orientation
            ] as [CFString: Any],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: Photo.lens,
                kCGImagePropertyExifISOSpeedRatings: [Photo.iso],
                kCGImagePropertyExifFNumber: Photo.fNumber,
                kCGImagePropertyExifExposureTime: Photo.exposureTime,
                kCGImagePropertyExifFocalLength: Photo.focalLength,
                kCGImagePropertyExifFocalLenIn35mmFilm: Photo.focalLength35,
                kCGImagePropertyExifExposureBiasValue: Photo.exposureBias,
                kCGImagePropertyExifMeteringMode: Photo.meteringMode,
                kCGImagePropertyExifFlash: Photo.flash,
                kCGImagePropertyExifWhiteBalance: 0,
                kCGImagePropertyExifDateTimeOriginal: Photo.dateOriginal
            ] as [CFString: Any],
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCHeadline: Photo.headline,
                kCGImagePropertyIPTCCaptionAbstract: Photo.caption,
                kCGImagePropertyIPTCKeywords: Photo.keywords,
                kCGImagePropertyIPTCCredit: Photo.credit,
                kCGImagePropertyIPTCCopyrightNotice: Photo.copyright,
                kCGImagePropertyIPTCByline: [Photo.byline],
                kCGImagePropertyIPTCSource: Photo.source,
                kCGImagePropertyIPTCCity: Photo.city,
                kCGImagePropertyIPTCProvinceState: Photo.state,
                kCGImagePropertyIPTCCountryPrimaryLocationName: Photo.country
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: Photo.latitude,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: Photo.longitude,
                kCGImagePropertyGPSLongitudeRef: "E",
                kCGImagePropertyGPSAltitude: Photo.altitude,
                kCGImagePropertyGPSAltitudeRef: 0
            ] as [CFString: Any]
        ]

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw Failure.cannotWrite }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.cannotWrite }
        return url
    }

    /// Writes a photograph in the southern and western hemispheres, to prove
    /// the reference letters are applied.
    @discardableResult
    static func writeSouthWestImage(to url: URL) throws -> URL {
        let context = CGContext(
            data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let image = context.makeImage()!
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 33.868_8,
                kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 70.650_0,
                kCGImagePropertyGPSLongitudeRef: "W"
            ] as [CFString: Any]
        ]
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw Failure.cannotWrite }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.cannotWrite }
        return url
    }

    // MARK: - Audio

    /// What ``writeAudio(to:)`` puts in the file.
    enum Song {
        static let title = "Around the World"
        static let artist = "Daft Punk"
        static let album = "Homework"
        static let seconds = 1.0
        static let sampleRate = 44_100.0
        static let channels = 2
    }

    /// Writes a one second stereo m4a carrying common tags.
    @discardableResult
    static func writeAudio(to url: URL) async throws -> URL {
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Song.sampleRate,
            AVNumberOfChannelsKey: Song.channels,
            AVEncoderBitRateKey: 128_000
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        writer.metadata = [
            item(.commonIdentifierTitle, Song.title),
            item(.commonIdentifierArtist, Song.artist),
            item(.commonIdentifierAlbumName, Song.album)
        ]

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frames = Int(Song.sampleRate * Song.seconds)
        let buffer = try silence(frames: frames)
        while !input.isReadyForMoreMediaData { await Task.yield() }
        input.append(buffer)
        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else { throw Failure.cannotWrite }
        return url
    }

    private static func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    /// A block of silence, as linear PCM the writer will encode.
    private static func silence(frames: Int) throws -> CMSampleBuffer {
        var description: AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: Song.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * Song.channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(2 * Song.channels),
            mChannelsPerFrame: UInt32(Song.channels),
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &description,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &format
        )

        let bytes = frames * 2 * Song.channels
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: bytes, flags: 0, blockBufferOut: &block
        )
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: bytes)

        var sample: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(Song.sampleRate)),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var size = 2 * Song.channels
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
            sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample
        )
        guard let sample else { throw Failure.cannotWrite }
        return sample
    }

    // MARK: - Documents

    #if canImport(PDFKit)
    /// What ``writePDF(to:)`` puts in the file.
    enum Document {
        static let title = "Statement of Delivery"
        static let author = "ArrayPress"
        static let subject = "Larsen Wedding"
        static let pages = 3
        static let width = 595.0
        static let height = 842.0
    }

    /// Writes a three page A4 PDF with document properties set.
    @discardableResult
    static func writePDF(to url: URL) throws -> URL {
        let document = PDFDocument()
        for index in 0..<Document.pages {
            let page = PDFPage()
            page.setBounds(CGRect(x: 0, y: 0, width: Document.width, height: Document.height), for: .mediaBox)
            document.insert(page, at: index)
        }
        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: Document.title,
            PDFDocumentAttribute.authorAttribute: Document.author,
            PDFDocumentAttribute.subjectAttribute: Document.subject
        ]
        guard document.write(to: url) else { throw Failure.cannotWrite }
        return url
    }
    #endif

    // MARK: - Plain files

    /// Writes a file of a known byte count.
    @discardableResult
    static func writeText(_ text: String, to url: URL) throws -> URL {
        try Data(text.utf8).write(to: url)
        return url
    }

    enum Failure: Error { case cannotWrite }
}
