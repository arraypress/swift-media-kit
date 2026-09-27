//
//  FileFacts.swift
//  MediaMetadata
//
//  Everything read about one file, in one pass.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The answers for a single file.
///
/// Sparse on purpose: a field nothing could answer is absent rather than
/// present and empty, so `facts[.camera] == nil` means "this file has no
/// camera" without a caller having to know whether it is a photograph.
public struct FileFacts: Sendable, Equatable {

    /// The file these facts describe.
    public let url: URL

    /// What sort of file it is.
    public let kind: MediaKind

    /// The answers, keyed by field.
    public var values: [MetadataField: FieldValue]

    /// Everything the system frameworks returned, namespaced and untouched —
    /// `exif.LensMake`, `iptc.ArtworkTitle`, `id3.TPE2`, `fs.inode`.
    ///
    /// Empty unless asked for. The curated ``values`` are a readable subset of
    /// this; a caller chasing a key no one has named yet reads it from here.
    public var raw: [String: FieldValue]

    /// Creates facts for `url`; both maps default to empty.
    public init(
        url: URL,
        kind: MediaKind,
        values: [MetadataField: FieldValue] = [:],
        raw: [String: FieldValue] = [:]
    ) {
        self.url = url
        self.kind = kind
        self.values = values
        self.raw = raw
    }

    // MARK: - Reading

    /// The value for a field, or `nil` when this file has none.
    public subscript(field: MetadataField) -> FieldValue? {
        get { values[field] }
        set { values[field] = newValue }
    }

    /// A field's value as an unformatted string.
    public func string(for field: MetadataField) -> String? {
        guard let value = values[field], !value.isEmpty else { return nil }
        return value.plain
    }

    /// The value for a token, whether it names a curated field or a raw key.
    ///
    /// `size` and `exif.LensMake` are both valid columns, so both resolve
    /// here and a caller never has to know which sort it was handed.
    public func value(forToken token: String) -> FieldValue? {
        if let field = MetadataField(token: token) { return values[field] }
        if let exact = raw[token] { return exact }
        // Raw keys keep the framework's own capitalisation, which nobody
        // remembers; a case-insensitive fall back costs one pass and saves
        // the guessing.
        let wanted = token.lowercased()
        return raw.first { $0.key.lowercased() == wanted }?.value
    }

    /// Every raw key under a namespace, sorted.
    public func rawKeys(in namespace: String) -> [String] {
        let prefix = namespace.hasSuffix(".") ? namespace : namespace + "."
        return raw.keys.filter { $0.hasPrefix(prefix) }.sorted()
    }

    /// Every field that was answered, in catalogue order.
    public var answered: [MetadataField] {
        MetadataField.allCases.filter { values[$0] != nil }
    }

    /// Where the file says it was made.
    public var coordinate: Coordinate? {
        guard case .coordinate(let latitude)? = values[.latitude],
            case .coordinate(let longitude)? = values[.longitude]
        else { return nil }
        var altitude: Double?
        if case .decimal(let metres)? = values[.altitude] { altitude = metres }
        let coordinate = Coordinate(latitude: latitude, longitude: longitude, altitude: altitude)
        return coordinate.isPlausible ? coordinate : nil
    }

    /// When the *content* was made, as opposed to when the file was written.
    ///
    /// A photograph copied to a delivery drive last week was still taken when
    /// it was taken, so the capture time wins over the file's creation date
    /// wherever there is one.
    public var capturedDate: Date? {
        if case .date(let shot)? = values[.shotDate] { return shot }
        if case .date(let captured)? = values[.captured] { return captured }
        if case .date(let created)? = values[.created] { return created }
        return nil
    }

    /// Size in bytes, when it was read.
    public var byteCount: Int64? {
        guard case .bytes(let count)? = values[.size] else { return nil }
        return count
    }

    /// Facts for a file nothing has been read from.
    public static func empty(url: URL) -> FileFacts {
        FileFacts(url: url, kind: .other)
    }

    /// Whether anything at all was read.
    public var isEmpty: Bool { values.isEmpty && raw.isEmpty }
}

// MARK: - Coding

extension FileFacts: Codable {

    private enum CodingKeys: String, CodingKey {
        case url, kind, values, raw
    }

    private struct FieldKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url.path, forKey: .url)
        try container.encode(kind, forKey: .kind)

        var fields = container.nestedContainer(keyedBy: FieldKey.self, forKey: .values)
        // Written in catalogue order rather than dictionary order — but note
        // that `JSONEncoder` does not preserve the order keys are encoded in:
        // it builds a dictionary, and Swift seeds string hashing per process,
        // so the same facts encode in a different order in the next run.
        //
        // A caller who needs byte-identical documents from one run to the next
        // — to diff two manifests, or to hash one — must set
        // `outputFormatting = [.sortedKeys]`. Nothing here can do it for them.
        for field in MetadataField.allCases {
            guard let value = values[field], let key = FieldKey(stringValue: field.rawValue) else { continue }
            try fields.encode(value, forKey: key)
        }

        if !raw.isEmpty {
            var rawFields = container.nestedContainer(keyedBy: FieldKey.self, forKey: .raw)
            for path in raw.keys.sorted() {
                guard let key = FieldKey(stringValue: path), let value = raw[path] else { continue }
                try rawFields.encode(value, forKey: key)
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = URL(fileURLWithPath: try container.decode(String.self, forKey: .url))
        kind = try container.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .other

        var decoded: [MetadataField: FieldValue] = [:]
        let fields = try container.nestedContainer(keyedBy: FieldKey.self, forKey: .values)
        for key in fields.allKeys {
            guard let field = MetadataField(rawValue: key.stringValue) else { continue }
            let value = try FieldValue(
                from: try fields.superDecoder(forKey: key),
                as: field.kind
            )
            decoded[field] = value
        }
        values = decoded

        var decodedRaw: [String: FieldValue] = [:]
        if let rawFields = try? container.nestedContainer(keyedBy: FieldKey.self, forKey: .raw) {
            for key in rawFields.allKeys {
                // A raw value's shape is not declared anywhere, so it is
                // recovered by trying the JSON types in order.
                let decoder = try rawFields.superDecoder(forKey: key)
                let single = try decoder.singleValueContainer()
                if let text = try? single.decode(String.self) {
                    decodedRaw[key.stringValue] = .text(text)
                } else if let flag = try? single.decode(Bool.self) {
                    decodedRaw[key.stringValue] = .boolean(flag)
                } else if let whole = try? single.decode(Int.self) {
                    decodedRaw[key.stringValue] = .integer(whole)
                } else if let number = try? single.decode(Double.self) {
                    decodedRaw[key.stringValue] = .decimal(number)
                } else if let list = try? single.decode([String].self) {
                    decodedRaw[key.stringValue] = .list(list)
                }
            }
        }
        raw = decodedRaw
    }
}
