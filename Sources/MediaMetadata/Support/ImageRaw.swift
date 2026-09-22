//
//  ImageRaw.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//
//  Every property ImageIO returns, namespaced and typed, with nothing dropped.
//
//  The macOS 27 SDK declares 676 image property constants across 26
//  dictionaries — EXIF alone has 85, IPTC 239 once the extension schema is
//  counted, DNG 92. Transcribing that into a Swift enum would be wrong twice
//  over: it would be stale the first time Apple added a key, and it would
//  still miss the maker notes, which are the whole reason a photographer looks
//  past EXIF.
//
//  So nothing is transcribed. Whatever `CGImageSourceCopyPropertiesAtIndex`
//  hands back is walked and flattened, which makes coverage a property of the
//  SDK rather than of this file.
//

import Foundation
import ImageIO

/// Reads every image property the system exposes, addressed as `exif.LensModel`.
public enum ImageRaw {

    /// The dictionaries ImageIO nests inside an image's properties, and the
    /// short prefix each is addressed by.
    ///
    /// Taken from `CGImageProperties.h`. A dictionary absent from a given file
    /// simply contributes nothing.
    static var namespaces: [(key: CFString, prefix: String)] { [
        (kCGImagePropertyExifDictionary, "exif"),
        (kCGImagePropertyExifAuxDictionary, "exifAux"),
        (kCGImagePropertyTIFFDictionary, "tiff"),
        (kCGImagePropertyIPTCDictionary, "iptc"),
        (kCGImagePropertyGPSDictionary, "gps"),
        (kCGImagePropertyJFIFDictionary, "jfif"),
        (kCGImagePropertyPNGDictionary, "png"),
        (kCGImagePropertyGIFDictionary, "gif"),
        (kCGImagePropertyHEIFDictionary, "heif"),
        (kCGImagePropertyHEICSDictionary, "heics"),
        (kCGImagePropertyWebPDictionary, "webp"),
        (kCGImagePropertyTGADictionary, "tga"),
        (kCGImagePropertyAVISDictionary, "avis"),
        (kCGImagePropertyOpenEXRDictionary, "openEXR"),
        (kCGImagePropertyDNGDictionary, "dng"),
        (kCGImagePropertyCIFFDictionary, "ciff"),
        (kCGImagePropertyRawDictionary, "raw"),
        (kCGImagePropertyFileContentsDictionary, "fileContents"),
        (kCGImageProperty8BIMDictionary, "photoshop"),
        (kCGImagePropertyMakerAppleDictionary, "makerApple"),
        (kCGImagePropertyMakerCanonDictionary, "makerCanon"),
        (kCGImagePropertyMakerNikonDictionary, "makerNikon"),
        (kCGImagePropertyMakerFujiDictionary, "makerFuji"),
        (kCGImagePropertyMakerMinoltaDictionary, "makerMinolta"),
        (kCGImagePropertyMakerOlympusDictionary, "makerOlympus"),
        (kCGImagePropertyMakerPentaxDictionary, "makerPentax")
    ] }

    /// Every property of the first image in the file.
    ///
    /// Top-level properties — pixel dimensions, colour model, depth — are
    /// namespaced `image`; everything else keeps the prefix of the dictionary
    /// it came from.
    public static func read(_ url: URL) -> [String: FieldValue] {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any]
        else { return [:] }

        var values: [String: FieldValue] = [:]
        let nested = Set(namespaces.map { $0.key })

        // Top level, minus the sub-dictionaries handled below.
        var top: [String: Any] = [:]
        for (key, value) in properties where !nested.contains(key) {
            top[key as String] = value
        }
        RawValue.flatten(top, prefix: "image", into: &values)

        for (key, prefix) in namespaces {
            guard let dictionary = properties[key] as? [CFString: Any] else { continue }
            let bridged = Dictionary(uniqueKeysWithValues: dictionary.map { ($0.key as String, $0.value) })
            RawValue.flatten(bridged, prefix: prefix, into: &values)
        }

        // Container facts that are not properties of any one image.
        if let containerProperties = CGImageSourceCopyProperties(source, options) as? [CFString: Any] {
            var container: [String: Any] = [:]
            for (key, value) in containerProperties where !nested.contains(key) {
                container[key as String] = value
            }
            RawValue.flatten(container, prefix: "container", into: &values)
        }
        values["container.ImageCount"] = .integer(CGImageSourceGetCount(source))

        return values
    }
}
