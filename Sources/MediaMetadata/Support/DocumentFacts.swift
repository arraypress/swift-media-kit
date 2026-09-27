//
//  DocumentFacts.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

#if canImport(PDFKit)
import PDFKit

/// Reads what a PDF says about itself.
///
/// The SDK declares eight document attributes, but the dictionary is not
/// closed — a producer may write its own keys into the info dictionary, and
/// those come through the raw reader untouched.
public enum DocumentFacts {

    /// The eight declared attributes and the field each answers.
    static let attributes: [(key: PDFDocumentAttribute, field: MetadataField)] = [
        (.titleAttribute, .docTitle),
        (.authorAttribute, .docAuthor),
        (.subjectAttribute, .docSubject),
        (.creatorAttribute, .docCreator),
        (.producerAttribute, .docProducer),
        (.creationDateAttribute, .docCreated),
        (.modificationDateAttribute, .docModified)
    ]

    /// Fills in every document-sourced field the caller asked for.
    public static func read(
        _ url: URL,
        wanted: Set<MetadataField>,
        into values: inout [MetadataField: FieldValue]
    ) {
        guard let document = PDFDocument(url: url) else { return }

        func put(_ field: MetadataField, _ value: FieldValue?) {
            guard wanted.contains(field), let value, !value.isEmpty else { return }
            values[field] = value
        }

        put(.pageCount, .integer(document.pageCount))
        put(.isEncrypted, .boolean(document.isEncrypted))

        let info = document.documentAttributes ?? [:]
        for (key, field) in attributes {
            guard let value = info[key.rawValue] else { continue }
            if let date = value as? Date {
                put(field, .date(date))
            } else if let text = value as? String {
                put(field, .text(text))
            }
        }
        if let keywords = info[PDFDocumentAttribute.keywordsAttribute.rawValue] {
            if let list = keywords as? [String] {
                put(.docKeywords, .list(list))
            } else if let text = keywords as? String {
                put(.docKeywords, .list(
                    text.split(whereSeparator: { $0 == "," || $0 == ";" })
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                ))
            }
        }

        if wanted.contains(.pageSize), let page = document.page(at: 0) {
            put(.pageSize, .text(PaperSize.describe(page.bounds(for: .mediaBox).size)))
        }
    }

    /// Every attribute in the document's info dictionary, namespaced `pdf`.
    public static func readRaw(_ url: URL) -> [String: FieldValue] {
        guard let document = PDFDocument(url: url) else { return [:] }
        var values: [String: FieldValue] = [:]

        values["pdf.pageCount"] = .integer(document.pageCount)
        values["pdf.isEncrypted"] = .boolean(document.isEncrypted)
        values["pdf.isLocked"] = .boolean(document.isLocked)
        values["pdf.allowsPrinting"] = .boolean(document.allowsPrinting)
        values["pdf.allowsCopying"] = .boolean(document.allowsCopying)
        values["pdf.majorVersion"] = .integer(document.majorVersion)
        values["pdf.minorVersion"] = .integer(document.minorVersion)

        if let page = document.page(at: 0) {
            let size = page.bounds(for: .mediaBox).size
            values["pdf.pageWidth"] = .decimal(Double(size.width))
            values["pdf.pageHeight"] = .decimal(Double(size.height))
            values["pdf.pageSize"] = .text(PaperSize.describe(size))
        }

        if let info = document.documentAttributes as? [String: Any] {
            RawValue.flatten(info, prefix: "pdf", into: &values)
        }
        return values
    }
}

#else

/// PDFKit is not available on this platform, so documents contribute nothing.
public enum DocumentFacts {

    /// Adds nothing: there is no PDFKit to read with.
    public static func read(
        _ url: URL,
        wanted: Set<MetadataField>,
        into values: inout [MetadataField: FieldValue]
    ) {}

    /// Always empty: there is no PDFKit to read with.
    public static func readRaw(_ url: URL) -> [String: FieldValue] { [:] }
}

#endif

/// Names a page size in points.
enum PaperSize {

    /// Known sizes in points, portrait.
    private static let known: [(name: String, width: Double, height: Double)] = [
        ("A3", 842, 1191), ("A4", 595, 842), ("A5", 420, 595), ("A6", 298, 420),
        ("US Letter", 612, 792), ("US Legal", 612, 1008), ("US Tabloid", 792, 1224),
        ("Executive", 522, 756)
    ]

    /// Points, with a paper name when the size is within a point of a standard one.
    ///
    /// The tolerance matters: a PDF written from a word processor lands on
    /// 595.276 x 841.89 for A4, and an exact comparison names none of them.
    static func describe(_ size: CGSize) -> String {
        let width = Double(size.width), height = Double(size.height)
        let points = "\(Int(width.rounded()))x\(Int(height.rounded())) pt"
        let portrait = (min(width, height), max(width, height))
        for paper in known {
            if abs(portrait.0 - paper.width) <= 2, abs(portrait.1 - paper.height) <= 2 {
                let orientation = width > height ? " landscape" : ""
                return "\(points) (\(paper.name)\(orientation))"
            }
        }
        return points
    }
}
