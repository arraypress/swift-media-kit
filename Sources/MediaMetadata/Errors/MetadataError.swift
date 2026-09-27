//
//  MetadataError.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Why a file could not be read at all.
///
/// Deliberately short. A *field* that cannot be answered is never an error —
/// it is simply absent, because a folder of mixed files would otherwise throw
/// on nearly every row. These are the cases where there is no file to read.
public enum MetadataError: Error, Equatable, Sendable, LocalizedError {

    /// Nothing exists at the path.
    case notFound(String)

    /// It exists but cannot be opened — permissions, or a volume that went away.
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path): "No file at \(path)"
        case .unreadable(let path): "Cannot read \(path)"
        }
    }
}
