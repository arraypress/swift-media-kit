//
//  URL+MediaMetadata.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

public extension URL {

    /// What sort of file this is, decided from its type alone.
    var mediaKind: MediaKind {
        (try? MetadataReader.classify(self)) ?? MediaKind(pathExtension: pathExtension)
    }

    /// Reads the fields named.
    func metadata(fields: Set<MetadataField>) async throws -> FileFacts {
        try await MetadataReader.read(self, fields: fields)
    }

    /// Reads every curated field this file can answer, checksums aside.
    func metadata() async throws -> FileFacts {
        try await MetadataReader.readAll(self)
    }

    /// Reads everything, curated and raw.
    func allMetadata() async throws -> FileFacts {
        try await MetadataReader.readEverything(self)
    }
}
