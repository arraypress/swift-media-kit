//
//  MetadataReader.swift
//  MediaMetadata
//
//  One pass per file, and only the passes the caller paid for.
//
//  The older design in the app this was lifted from asked for each placeholder
//  separately as a file arrived, building a fresh `CGImageSource` or
//  `AVURLAsset` for every one of them. This reads a file once: one set of
//  resource values, one image source, one asset — and skips each of those
//  entirely when nothing asked for anything it answers.
//
//  That skipping is the whole performance story. Measured over 107,765 files:
//  filesystem fields alone take 3.9 s; the same tree through Spotlight takes
//  54.8 s; opening every image for its EXIF costs about 0.32 ms each and
//  parallelises roughly tenfold.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import UniformTypeIdentifiers

/// Reads metadata from files.
public enum MetadataReader {

    // MARK: - One file

    /// Reads exactly the fields asked for.
    ///
    /// - Parameters:
    ///   - url: The file to read.
    ///   - fields: What to answer. A field this file cannot answer is simply
    ///     absent from the result.
    ///   - root: The folder a scan began at, for ``MetadataField/relativePath``.
    /// - Throws: ``MetadataError`` when there is no readable file at `url`.
    public static func read(
        _ url: URL,
        fields: Set<MetadataField>,
        root: URL? = nil
    ) async throws -> FileFacts {
        let kind = try classify(url)
        var values: [MetadataField: FieldValue] = [:]

        // Dates that feed the derived fields have to be read even when the
        // caller only asked for the derived ones.
        var wanted = fields
        if fields.contains(where: { [.year, .month, .day, .time, .captured].contains($0) }) {
            wanted.formUnion([.created, .shotDate, .captured])
        }

        let needed = Set(wanted.map(\.source))

        if needed.contains(.fileSystem) || needed.contains(.derived) {
            FileSystemFacts.read(url, wanted: wanted, root: root, into: &values)
        }
        if needed.contains(.image), kind == .image {
            ImageFacts.read(url, wanted: wanted, into: &values)
        }
        if needed.contains(.media), kind == .audio || kind == .video {
            await MediaFacts.read(url, wanted: wanted, into: &values)
        }
        if needed.contains(.document), kind == .document {
            DocumentFacts.read(url, wanted: wanted, into: &values)
        }
        if needed.contains(.derived) {
            DerivedFacts.read(wanted: wanted, into: &values)
        }
        if needed.contains(.checksum) {
            ChecksumFacts.read(url, wanted: wanted, into: &values)
        }

        // Fields pulled in only to feed a derived one are dropped again.
        values = values.filter { fields.contains($0.key) }

        return FileFacts(url: url, kind: kind, values: values)
    }

    /// Reads every field that does not require opening the file.
    ///
    /// The cheap answer, for a listing that wants names, sizes, types and
    /// dates over a very large tree.
    public static func readFree(_ url: URL, root: URL? = nil) async throws -> FileFacts {
        try await read(url, fields: Set(MetadataField.freeFields), root: root)
    }

    /// Reads every curated field this file could possibly answer.
    public static func readAll(_ url: URL, root: URL? = nil) async throws -> FileFacts {
        let kind = try classify(url)
        let fields = MetadataField.allCases.filter { kind.answers($0) && $0.source != .checksum }
        return try await read(url, fields: Set(fields), root: root)
    }

    // MARK: - Everything

    /// Reads the curated fields *and* every raw key the system frameworks hold.
    ///
    /// This is the exhaustive read: 676 image property constants, 294 media
    /// identifiers and 127 resource keys are what the SDK declares, and a file
    /// may carry keys outside all of them — maker notes especially. Nothing is
    /// filtered, so whatever the frameworks return is in ``FileFacts/raw``.
    ///
    /// - Parameters:
    ///   - url: The file to read.
    ///   - fields: Curated fields to answer alongside the raw keys.
    ///   - root: The folder a scan began at.
    public static func readEverything(
        _ url: URL,
        fields: Set<MetadataField> = Set(MetadataField.allCases.filter { $0.source != .checksum }),
        root: URL? = nil
    ) async throws -> FileFacts {
        var facts = try await read(url, fields: fields, root: root)
        var raw = FileSystemRaw.read(url)

        switch facts.kind {
        case .image:
            raw.merge(ImageRaw.read(url)) { current, _ in current }
        case .audio, .video:
            raw.merge(await MediaRaw.read(url)) { current, _ in current }
        case .document:
            raw.merge(DocumentFacts.readRaw(url)) { current, _ in current }
        case .folder, .other:
            break
        }

        facts.raw = raw
        return facts
    }

    // MARK: - Many files

    /// How many files to read at once.
    ///
    /// Bounded rather than unbounded: the work is a mix of disk and processor,
    /// and a task per file over a folder of a hundred thousand of them spends
    /// more on scheduling than on reading.
    public static var concurrencyLimit: Int {
        max(2, min(ProcessInfo.processInfo.activeProcessorCount, 16))
    }

    /// Reads many files at once, in the order they were given.
    ///
    /// - Parameters:
    ///   - urls: Files to read.
    ///   - fields: What to answer for each.
    ///   - root: The folder a scan began at.
    ///   - onProgress: Called as each file finishes, with how many are done.
    public static func read(
        _ urls: [URL],
        fields: Set<MetadataField>,
        root: URL? = nil,
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> [FileFacts] {
        guard !urls.isEmpty else { return [] }

        var results = [FileFacts?](repeating: nil, count: urls.count)
        var completed = 0

        await withTaskGroup(of: (Int, FileFacts?).self) { group in
            var next = 0
            let limit = min(concurrencyLimit, urls.count)

            func submit(_ index: Int) {
                let url = urls[index]
                group.addTask {
                    (index, try? await read(url, fields: fields, root: root))
                }
            }

            while next < limit {
                submit(next)
                next += 1
            }

            for await (index, facts) in group {
                results[index] = facts
                completed += 1
                onProgress?(completed)
                if next < urls.count {
                    submit(next)
                    next += 1
                }
            }
        }

        return zip(urls, results).map { url, facts in
            facts ?? FileFacts.empty(url: url)
        }
    }

    // MARK: - Classification

    /// What sort of file this is, without opening it.
    static func classify(_ url: URL) throws -> MediaKind {
        let resources = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        if resources == nil, !FileManager.default.fileExists(atPath: url.path) {
            throw MetadataError.notFound(url.path)
        }
        if resources?.isDirectory == true { return .folder }
        return MediaKind(type: resources?.contentType, pathExtension: url.pathExtension)
    }
}
