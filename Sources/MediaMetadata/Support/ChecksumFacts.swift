//
//  ChecksumFacts.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CodecKit
import Foundation

/// Digests of a file's bytes, mapped onto `CodecKit`, which streams a megabyte at a time.
///
/// Hashing is bounded by the disk, not the processor (SHA-256 runs at roughly 1 GB/s per
/// core), so a warm local folder is free and half a terabyte on a USB drive is forty minutes.
public enum ChecksumFacts {

    /// The algorithm each checksum field asks for.
    static let algorithms: [MetadataField: HashAlgorithm] = [
        .md5: .md5,
        .sha1: .sha1,
        .sha256: .sha256,
        .sha384: .sha384,
        .sha512: .sha512,
        .crc32: .crc32,
    ]

    /// Computes only the digests the caller asked for, reading the file once
    /// per algorithm.
    public static func read(
        _ url: URL,
        wanted: Set<MetadataField>,
        into values: inout [MetadataField: FieldValue]
    ) {
        for (field, algorithm) in algorithms where wanted.contains(field) {
            guard let digest = try? Digest.hash(contentsOf: url, using: algorithm) else { continue }
            values[field] = .text(digest)
        }
    }
}
