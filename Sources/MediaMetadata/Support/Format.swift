//
//  Format.swift
//  MediaMetadata
//
//  Turning a number a camera wrote into the string a person expects to read.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Renders the handful of camera values that have a conventional written form.
public enum Format {

    /// `35mm`, `24.5mm`.
    public static func millimetres(_ value: Double) -> String {
        "\(trimmed(value))mm"
    }

    /// `f/2.8`.
    public static func fNumber(_ value: Double) -> String {
        "f/\(trimmed(value))"
    }

    /// `1/250` below a second, `2s` above it.
    ///
    /// Photographers write and read fractions; `0.004` is the same number and
    /// tells nobody anything.
    public static func shutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0 else { return "" }
        if seconds >= 1 { return "\(trimmed(seconds))s" }
        return "1/\(Int((1 / seconds).rounded()))"
    }

    /// `+2/3 EV`, `-1 EV`, `0 EV`.
    public static func stops(_ value: Double) -> String {
        if value == 0 { return "0 EV" }
        let sign = value > 0 ? "+" : "-"
        return "\(sign)\(trimmed(abs(value))) EV"
    }

    /// `1920x1080`.
    public static func dimensions(_ width: Int, _ height: Int) -> String {
        "\(width)x\(height)"
    }

    /// The shorthand a person uses for a frame size.
    ///
    /// Measured on the SHORT edge, not the height. A phone clip at 1080x1920
    /// is 1080p vertical to everyone who handles it; calling it 1440p because
    /// it is 1920 tall describes a frame nobody shot. Measured on a real
    /// portrait video, which is how this was found.
    ///
    /// Bands rather than exact matches, because real footage is rarely the
    /// round number the name suggests — a 1920x1038 letterboxed master is
    /// still 1080p, and a 1080x1350 social crop is too.
    public static func resolutionLabel(width: Int, height: Int) -> String {
        resolutionLabel(shortEdge: width > 0 ? min(width, height) : height)
    }

    /// The label for a known short edge.
    public static func resolutionLabel(shortEdge: Int) -> String {
        switch shortEdge {
        case 4320...: "8K"
        case 2160..<4320: "4K"
        case 1400..<2160: "1440p"
        case 1000..<1400: "1080p"
        case 700..<1000: "720p"
        case 400..<700: "480p"
        case 1..<400: "SD"
        default: ""
        }
    }

    /// `5s`, `2m30s`, `1h05m30s` — sortable by eye and safe in a file name.
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%dh%02dm%02ds", hours, minutes, secs) }
        if minutes > 0 { return String(format: "%dm%02ds", minutes, secs) }
        return "\(secs)s"
    }

    /// Drops a trailing `.0`.
    static func trimmed(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%g", value)
    }
}
