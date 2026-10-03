//
//  CodecWarmUp.swift
//  MediaMetadata
//
//  Starts the system's HEVC image decoder before the first HEIC is opened.
//
//  Created by David Sherlock on 10/3/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import ImageIO

/// The first HEIC a process decodes pays for starting the HEVC decoder: about 80 ms, against
/// 3–8 ms for the decode itself once it runs. Decoding a 16×16 HEIC held in memory on a
/// background queue at launch moves that cost off the first open.
public enum CodecWarmUp {
    /// Decodes the embedded HEIC once. Blocking: call from a background queue.
    public static func warmUp() {
        guard let data = Data(base64Encoded: tinyHEIC),
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return }
        _ = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    /// A 16×16 solid HEIC (651 bytes).
    static let tinyHEIC =
        "AAAAJGZ0eXBoZWljAAAAAG1pZjFNaVBybWlhZk1pSEJoZWljAAABw21ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAHBpY3QAAAAA"
        + "AAAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAAADnBpdG0AAAAAAAEAAAA4aWluZgAAAAAA"
        + "AgAAABVpbmZlAgAAAAABAABodmMxAAAAABVpbmZlAgAAAQACAABFeGlmAAAAABppcmVmAAAAAAAAAA5jZHNjAAIAAQABAAAA"
        + "5mlwcnAAAADFaXBjbwAAABNjb2xybmNseAACAAIABoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAAAAAAAAAQAAAAEAAAAAlpcm90"
        + "AAAAABBwaXhpAAAAAAMICAgAAABxaHZjQwEDcAAAALAAAAAAAB7wAPz9+PgAAAsDoAABABdAAQwB//8DcAAAAwCwAAADAAAD"
        + "AB5wJKEAAQAjQgEBA3AAAAMAsAAAAwAAAwAeoBQgQcCTDOIe5FlU3AgIGAKiAAEACUQBwGFyyERTZAAAABlpcG1hAAAAAAAA"
        + "AAEAAQaBAgMFhoQAAAAsaWxvYwAAAABEAAACAAEAAAABAAACRQAAAEYAAgAAAAEAAAH3AAAATgAAAAFtZGF0AAAAAAAAAKQA"
        + "AAAGRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAADIKADAAQAAAABAAAC"
        + "WAAAAAAAAABCKAGvovJGgXzF8CP//Cv7L5N59X/3J8j1b0v81E90yyZ/oD6DYP/STT4xnS6smYGyc/e2IPevfcUWd8TxqaOy" + "Lnp+"
}
