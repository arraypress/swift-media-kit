//
//  Lookup.swift
//  MediaMetadata
//
//  EXIF stores settings as small integers and the SDK names only the keys, not
//  what the numbers mean — so the tables live here, taken from the EXIF
//  specification rather than guessed. A column reading "5" where it should
//  read "Pattern" is worse than an empty one, because it looks like data.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Turns EXIF's enumerated integers into the words they stand for.
public enum Lookup {

    /// EXIF `MeteringMode`.
    public static func meteringMode(_ value: Int) -> String? {
        switch value {
        case 0: "Unknown"
        case 1: "Average"
        case 2: "Centre-weighted average"
        case 3: "Spot"
        case 4: "Multi-spot"
        case 5: "Pattern"
        case 6: "Partial"
        case 255: "Other"
        default: nil
        }
    }

    /// EXIF `ExposureProgram`.
    public static func exposureProgram(_ value: Int) -> String? {
        switch value {
        case 0: "Not defined"
        case 1: "Manual"
        case 2: "Normal program"
        case 3: "Aperture priority"
        case 4: "Shutter priority"
        case 5: "Creative"
        case 6: "Action"
        case 7: "Portrait"
        case 8: "Landscape"
        default: nil
        }
    }

    /// EXIF `ExposureMode`.
    public static func exposureMode(_ value: Int) -> String? {
        switch value {
        case 0: "Auto"
        case 1: "Manual"
        case 2: "Auto bracket"
        default: nil
        }
    }

    /// EXIF `SceneCaptureType`.
    public static func sceneCaptureType(_ value: Int) -> String? {
        switch value {
        case 0: "Standard"
        case 1: "Landscape"
        case 2: "Portrait"
        case 3: "Night"
        default: nil
        }
    }

    /// EXIF `SensingMethod`.
    public static func sensingMethod(_ value: Int) -> String? {
        switch value {
        case 1: "Not defined"
        case 2: "One-chip colour area"
        case 3: "Two-chip colour area"
        case 4: "Three-chip colour area"
        case 5: "Colour sequential area"
        case 7: "Trilinear"
        case 8: "Colour sequential linear"
        default: nil
        }
    }

    /// EXIF `LightSource`.
    public static func lightSource(_ value: Int) -> String? {
        switch value {
        case 0: "Unknown"
        case 1: "Daylight"
        case 2: "Fluorescent"
        case 3: "Tungsten"
        case 4: "Flash"
        case 9: "Fine weather"
        case 10: "Cloudy"
        case 11: "Shade"
        case 12: "Daylight fluorescent"
        case 13: "Day white fluorescent"
        case 14: "Cool white fluorescent"
        case 15: "White fluorescent"
        case 17: "Standard light A"
        case 18: "Standard light B"
        case 19: "Standard light C"
        case 20: "D55"
        case 21: "D65"
        case 22: "D75"
        case 23: "D50"
        case 24: "ISO studio tungsten"
        case 255: "Other"
        default: nil
        }
    }

    /// EXIF `ColorSpace`.
    public static func colorSpace(_ value: Int) -> String? {
        switch value {
        case 1: "sRGB"
        case 2: "Adobe RGB"
        case 0xFFFF: "Uncalibrated"
        default: nil
        }
    }

    /// TIFF `ResolutionUnit`.
    public static func resolutionUnit(_ value: Int) -> String? {
        switch value {
        case 1: "None"
        case 2: "Inches"
        case 3: "Centimetres"
        default: nil
        }
    }

    /// EXIF `Contrast`, `Saturation` and `Sharpness` share one scale.
    public static func normalLowHigh(_ value: Int) -> String? {
        switch value {
        case 0: "Normal"
        case 1: "Low"
        case 2: "High"
        default: nil
        }
    }

    /// EXIF `SubjectDistanceRange`.
    public static func subjectDistanceRange(_ value: Int) -> String? {
        switch value {
        case 0: "Unknown"
        case 1: "Macro"
        case 2: "Close"
        case 3: "Distant"
        default: nil
        }
    }

    /// EXIF `Flash`, which packs five facts into one integer.
    ///
    /// Bit 0 is whether it fired; bits 3–4 carry the mode; bit 5 says the
    /// camera has no flash at all. Reporting only "fired" throws away the
    /// distinction between a camera that chose not to fire and one that
    /// could not.
    public static func flash(_ value: Int) -> String {
        if value & 0x20 != 0 { return "No flash function" }
        var parts = [value & 1 == 1 ? "Fired" : "Did not fire"]
        switch (value >> 3) & 0x3 {
        case 1: parts.append("compulsory")
        case 2: parts.append("suppressed")
        case 3: parts.append("auto")
        default: break
        }
        if value & 0x40 != 0 { parts.append("red-eye reduction") }
        return parts.joined(separator: ", ")
    }

    /// A channel count as the word an engineer uses.
    public static func channelLayout(_ count: Int) -> String {
        switch count {
        case 1: "Mono"
        case 2: "Stereo"
        case 6: "5.1"
        case 8: "7.1"
        default: "\(count)ch"
        }
    }

    /// A four character code as its common name, or the code itself.
    ///
    /// `CMFormatDescription` reports the codec as a `FourCharCode`; `avc1` is
    /// technically right and "H.264" is what anyone reading a file list is
    /// looking for.
    public static func codecName(_ code: String) -> String {
        switch code.lowercased() {
        case "avc1", "h264": "H.264"
        case "hvc1", "hev1": "HEVC"
        case "ap4h", "apch", "apcn", "apcs", "apco": "ProRes"
        case "mp4v": "MPEG-4"
        case "vp09": "VP9"
        case "av01": "AV1"
        case "jpeg": "Motion JPEG"
        case "aac", "aac ", "mp4a": "AAC"
        case "lpcm", "sowt", "twos": "PCM"
        case "alac": "Apple Lossless"
        case ".mp3", "mp3", "mp3 ", ".mp3 ": "MP3"
        case "ac-3": "AC-3"
        case "ec-3": "E-AC-3"
        case "opus": "Opus"
        case "flac": "FLAC"
        default: code
        }
    }
}
