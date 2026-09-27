//
//  FieldDescriptor.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Everything known about a field before any file has been read.
///
/// A column chooser, a `--help` listing and a table renderer all need the same
/// four facts — what to call it, where it belongs, what shape its values are
/// and what it costs — so they are described once.
public struct FieldDescriptor: Sendable, Equatable, Hashable, Codable {

    /// The token a caller types: `sha256`, `focalLength`.
    public let key: String

    /// The heading to print above the column: "SHA-256", "Focal Length".
    public let label: String

    /// The group it belongs to.
    public let category: FieldCategory

    /// The shape of its values.
    public let kind: ValueKind

    /// What has to be opened to answer it.
    public let source: FieldSource

    public init(
        key: String,
        label: String,
        category: FieldCategory,
        kind: ValueKind,
        source: FieldSource
    ) {
        self.key = key
        self.label = label
        self.category = category
        self.kind = kind
        self.source = source
    }
}
