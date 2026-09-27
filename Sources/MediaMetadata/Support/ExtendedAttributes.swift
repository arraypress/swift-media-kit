//
//  ExtendedAttributes.swift
//  MediaMetadata
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

#if os(macOS)

    /// Reads the two Finder facts that live in extended attributes rather than in
    /// resource values.
    ///
    /// Both are binary property lists behind an `xattr` name: the Finder comment has no
    /// `URLResourceKey`, and the download origin says where the bytes came from.
    public enum ExtendedAttributes {

        /// The Finder comment, or `nil` when there is none.
        public static func finderComment(of url: URL) -> String? {
            guard let data = data(named: "com.apple.metadata:kMDItemFinderComment", of: url),
                let comment = try? PropertyListSerialization.propertyList(from: data, format: nil) as? String,
                !comment.isEmpty
            else { return nil }
            return comment
        }

        /// Where a downloaded file came from — the first URL Safari or curl recorded.
        public static func whereFrom(of url: URL) -> String? {
            guard let data = data(named: "com.apple.metadata:kMDItemWhereFroms", of: url),
                let origins = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
            else { return nil }
            return origins.first { !$0.isEmpty }
        }

        /// Raw bytes of one extended attribute.
        ///
        /// Asked for its size first, because passing a buffer that is too small
        /// fails with `ERANGE` rather than truncating.
        static func data(named name: String, of url: URL) -> Data? {
            url.withUnsafeFileSystemRepresentation { path -> Data? in
                guard let path else { return nil }
                let length = getxattr(path, name, nil, 0, 0, 0)
                guard length > 0 else { return nil }
                var buffer = Data(count: length)
                let read = buffer.withUnsafeMutableBytes { bytes in
                    getxattr(path, name, bytes.baseAddress, length, 0, 0)
                }
                guard read >= 0 else { return nil }
                return buffer.prefix(read)
            }
        }
    }

#endif
