//
//  FontSpecimen.swift
//  FontSpecimen
//
//  A font file's specimen: the face CoreText reads from the file's bytes (TrueType,
//  OpenType, WOFF and WOFF2 alike, nothing installed) and the lines a specimen shows —
//  the name, the alphabet and digits, then one sentence at a ladder of sizes.
//
//  Created by David Sherlock on 10/3/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreText
import Foundation

/// A font file's specimen: its face, read from the bytes, and the lines to show it with.
///
/// The face is never registered with the system, so previewing a font installs nothing. A
/// renderer draws each ``Line`` in ``font(size:)`` (or its own UI font for a ``Role/label``).
public struct FontSpecimen: @unchecked Sendable {
    /// What a line is for, so a renderer can style it.
    public enum Role: Sendable, Equatable {
        /// The file's name, in the interface font.
        case title
        /// The alphabet, digits and punctuation, in the specimen face.
        case glyphs
        /// A size caption ("72 pt"), in the interface font.
        case label
        /// The sample sentence, in the specimen face at ``Line/size``.
        case sample
    }

    /// One line of the specimen.
    public struct Line: Sendable, Equatable {
        /// The text to draw.
        public let text: String
        /// Its point size.
        public let size: Double
        /// What the line is for.
        public let role: Role
    }

    /// The face's full name as the file states it ("JetBrains Mono Regular").
    public let fullName: String
    /// The lines, top to bottom.
    public let lines: [Line]
    /// The sizes the sample sentence is shown at, largest first.
    public static let sampleSizes: [Double] = [72, 54, 40, 30, 24, 19, 15, 12]
    /// The sample sentence: every letter of the English alphabet.
    public static let sampleText = "The quick brown fox jumps over the lazy dog"

    private let descriptor: CTFontDescriptor

    /// Reads the first face in the font file at `url`, titled with `title` (the file name when
    /// nil); nil when the file is unreadable or CoreText finds no face in it.
    public init?(fileAt url: URL, title: String? = nil) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data, title: title ?? url.lastPathComponent)
    }

    /// Reads the first face in `data`, titled with `title`.
    public init?(data: Data, title: String) {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
            let first = descriptors.first
        else { return nil }
        descriptor = first
        fullName = CTFontCopyFullName(CTFontCreateWithFontDescriptor(first, 12, nil)) as String
        lines =
            [
                Line(text: title, size: 22, role: .title),
                Line(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", size: 20, role: .glyphs),
                Line(text: "abcdefghijklmnopqrstuvwxyz", size: 20, role: .glyphs),
                Line(text: "0123456789 &@#$%(){}[]<>/*", size: 20, role: .glyphs),
            ]
            + Self.sampleSizes.flatMap { size in
                [
                    Line(text: "\(Int(size)) pt", size: 12, role: .label),
                    Line(text: Self.sampleText, size: size, role: .sample),
                ]
            }
    }

    /// The specimen face at `size` points.
    public func font(size: Double) -> CTFont { CTFontCreateWithFontDescriptor(descriptor, CGFloat(size), nil) }
}
