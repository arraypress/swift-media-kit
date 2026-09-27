//
//  FieldValue.swift
//  MediaMetadata
//
//  Values stay typed all the way to the renderer.
//
//  The temptation is to keep everything as a formatted string, which is what
//  a rename template wants. It is also how a table ends up sorted with "9 MB"
//  above "10 MB" and a JSON document where every number is quoted. So a size
//  is an integer until something decides to print it, and the decision about
//  how to print it belongs to whatever is doing the printing.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One answer about one file.
public enum FieldValue: Sendable, Equatable, Hashable {

    case text(String)
    case integer(Int)
    case decimal(Double)
    case bytes(Int64)
    case date(Date)
    case duration(Double)
    case coordinate(Double)
    case boolean(Bool)
    case list([String])

    /// The shape of this value.
    public var kind: ValueKind {
        switch self {
        case .text: .text
        case .integer: .integer
        case .decimal: .decimal
        case .bytes: .bytes
        case .date: .date
        case .duration: .duration
        case .coordinate: .coordinate
        case .boolean: .boolean
        case .list: .list
        }
    }

    /// Whether there is nothing here worth printing.
    ///
    /// An empty string and an empty list both count: a column of them is a
    /// column a caller asked for and no file answered, which is exactly what
    /// "leave empty columns out" has to be able to detect.
    public var isEmpty: Bool {
        switch self {
        case .text(let value): value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .list(let values): values.isEmpty
        default: false
        }
    }

    /// An unformatted rendering, for templates and for a caller that wants a
    /// string and no opinions.
    ///
    /// Dates come out ISO 8601 in the local time zone. Nothing here is
    /// localised or humanised — that is a renderer's job.
    public var plain: String {
        switch self {
        case .text(let value): value
        case .integer(let value): String(value)
        case .decimal(let value): Self.trimmed(value)
        case .bytes(let value): String(value)
        case .date(let value): value.formatted(.iso8601)
        case .duration(let value): Self.trimmed(value)
        case .coordinate(let value): String(format: "%.6f", value)
        case .boolean(let value): value ? "true" : "false"
        case .list(let values): values.joined(separator: ", ")
        }
    }

    /// A key that sorts values of the same field correctly.
    ///
    /// Numbers sort by magnitude and text sorts case-insensitively, so a
    /// caller can order a whole table without knowing what is in it.
    public var sortKey: (Double?, String) {
        switch self {
        case .integer(let value): (Double(value), "")
        case .decimal(let value), .duration(let value), .coordinate(let value): (value, "")
        case .bytes(let value): (Double(value), "")
        case .date(let value): (value.timeIntervalSince1970, "")
        case .boolean(let value): (value ? 1 : 0, "")
        case .text(let value): (nil, value.lowercased())
        case .list(let values): (nil, values.joined(separator: ", ").lowercased())
        }
    }

    /// Drops a trailing `.0` so a whole number does not print as a fraction.
    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int(value))
            : String(format: "%g", value)
    }
}

// MARK: - Coding

extension FieldValue: Encodable {

    /// Encodes as the natural JSON type, so numbers are numbers.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .decimal(let value), .duration(let value), .coordinate(let value): try container.encode(value)
        case .bytes(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .list(let values): try container.encode(values)
        }
    }
}

extension FieldValue {

    /// Decodes a value whose shape is already known from its field.
    ///
    /// JSON cannot tell a byte count from a duration — both arrive as a
    /// number — so the field's own ``ValueKind`` supplies what the document
    /// cannot.
    public init(from decoder: any Decoder, as kind: ValueKind) throws {
        let container = try decoder.singleValueContainer()
        switch kind {
        case .text: self = .text(try container.decode(String.self))
        case .integer: self = .integer(try container.decode(Int.self))
        case .decimal: self = .decimal(try container.decode(Double.self))
        case .bytes: self = .bytes(try container.decode(Int64.self))
        case .date: self = .date(try container.decode(Date.self))
        case .duration: self = .duration(try container.decode(Double.self))
        case .coordinate: self = .coordinate(try container.decode(Double.self))
        case .boolean: self = .boolean(try container.decode(Bool.self))
        case .list: self = .list(try container.decode([String].self))
        }
    }
}
