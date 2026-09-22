//
//  Coordinate.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//

import Foundation

/// Where a file says it was made.
///
/// Degrees only. Turning these into a city name is a network request to a
/// geocoding service, which is the one thing that would stop a file list being
/// answerable with the machine offline — so this package stops here. The
/// photographer's own ``MetadataField/iptcCity`` is the offline answer.
public struct Coordinate: Sendable, Equatable, Hashable, Codable {

    /// Signed degrees north of the equator.
    public let latitude: Double

    /// Signed degrees east of Greenwich.
    public let longitude: Double

    /// Metres above sea level, where the file records it.
    public let altitude: Double?

    public init(latitude: Double, longitude: Double, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    /// Whether the pair is inside the range degrees can hold.
    ///
    /// A camera with no fix writes zeroes rather than nothing, and `0, 0` is a
    /// real place in the Atlantic, so that pair is treated as absent.
    public var isPlausible: Bool {
        guard latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return false }
        return !(latitude == 0 && longitude == 0)
    }

    /// Both degrees, six places each.
    public var formatted: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
