//
//  FileSystemRaw.swift
//  MediaMetadata
//
//  Every resource value the file system will answer, namespaced `fs`.
//
//  The obvious implementation asks for all 127 declared keys and reports
//  `URLResourceValues.allValues`. It does not work, and it fails quietly.
//  Measured on an ordinary text file: 50 keys requested, **7 returned** by
//  `allValues` — no size, no dates, no `isDirectory`. Everything with a typed
//  property on `URLResourceValues` is readable only through that property, and
//  `allValues` carries the remainder.
//
//  So the typed accessors are listed out here, and `allValues` is merged in
//  afterwards for whatever the SDK exposes that way. Nothing is lost either
//  side of the line.
//
//  There is a second trap underneath the first. Including
//  `.directoryEntryCountKey` in a request set **silently nils out every other
//  value in the result** — no throw, no partial answer, just a
//  `URLResourceValues` where `fileSize`, `creationDate` and `isDirectory` are
//  all nil. Measured directly: requesting `[.fileSizeKey]` gives 3 bytes,
//  requesting `[.fileSizeKey, .directoryEntryCountKey]` on the same file gives
//  nil. So it is asked for on its own, and only for directories, where it is
//  the only thing it can mean.
//
//  Created by David Sherlock on 9/15/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import UniformTypeIdentifiers

/// Reads the file system's own metadata in full.
public enum FileSystemRaw {

    /// Every printable resource key, as declared by the SDK.
    public static var keys: Set<URLResourceKey> {
        var keys: Set<URLResourceKey> = [
            .addedToDirectoryDateKey, .attributeModificationDateKey, .canonicalPathKey,
            .contentAccessDateKey, .contentModificationDateKey, .contentTypeKey,
            .creationDateKey, .fileAllocatedSizeKey,
            .fileResourceTypeKey, .fileSizeKey, .hasHiddenExtensionKey,
            .isAliasFileKey, .isApplicationKey, .isDirectoryKey,
            .isExcludedFromBackupKey, .isExecutableKey, .isHiddenKey,
            .isPackageKey, .isReadableKey, .isRegularFileKey,
            .isSymbolicLinkKey, .isSystemImmutableKey, .isUbiquitousItemKey,
            .isUserImmutableKey, .isVolumeKey, .isWritableKey,
            .linkCountKey, .localizedNameKey, .localizedTypeDescriptionKey,
            .mayHaveExtendedAttributesKey, .mayShareFileContentKey, .nameKey,
            .pathKey, .preferredIOBlockSizeKey, .totalFileAllocatedSizeKey,
            .totalFileSizeKey, .ubiquitousItemContainerDisplayNameKey,
            .ubiquitousItemDownloadRequestedKey, .ubiquitousItemHasUnresolvedConflictsKey,
            .ubiquitousItemIsDownloadingKey, .ubiquitousItemIsUploadedKey,
            .ubiquitousItemIsUploadingKey, .isPurgeableKey, .isSparseKey
        ]
        #if os(macOS)
        keys.formUnion([
            .applicationIsScriptableKey, .isMountTriggerKey, .labelNumberKey,
            .localizedLabelKey, .tagNamesKey
        ])
        #endif
        return keys
    }

    /// Everything the file system will say about the file.
    public static func read(_ url: URL) -> [String: FieldValue] {
        var values: [String: FieldValue] = [:]
        guard let resources = try? url.resourceValues(forKeys: keys) else { return values }

        func put(_ name: String, _ value: FieldValue?) {
            guard let value, !value.isEmpty else { return }
            values["fs.\(name)"] = value
        }
        func text(_ name: String, _ value: String?) { put(name, value.map { .text($0) }) }
        func date(_ name: String, _ value: Date?) { put(name, value.map { .date($0) }) }
        func flag(_ name: String, _ value: Bool?) { put(name, value.map { .boolean($0) }) }
        func count(_ name: String, _ value: Int?) { put(name, value.map { .integer($0) }) }
        func bytes(_ name: String, _ value: Int?) { put(name, value.map { .bytes(Int64($0)) }) }

        // Names and paths
        text("name", resources.name)
        text("localizedName", resources.localizedName)
        text("path", resources.path)
        text("canonicalPath", resources.canonicalPath)

        // Type
        text("contentType", resources.contentType?.identifier)
        text("localizedTypeDescription", resources.localizedTypeDescription)
        text("fileResourceType", resources.fileResourceType?.rawValue)

        // Size
        bytes("fileSize", resources.fileSize)
        bytes("fileAllocatedSize", resources.fileAllocatedSize)
        bytes("totalFileSize", resources.totalFileSize)
        bytes("totalFileAllocatedSize", resources.totalFileAllocatedSize)
        count("preferredIOBlockSize", resources.preferredIOBlockSize)
        count("linkCount", resources.linkCount)

        // Asked for alone — see the note at the top of this file.
        if resources.isDirectory == true,
           let entries = try? url.resourceValues(forKeys: [.directoryEntryCountKey]).directoryEntryCount {
            count("directoryEntryCount", entries)
        }

        // Dates
        date("creationDate", resources.creationDate)
        date("contentModificationDate", resources.contentModificationDate)
        date("contentAccessDate", resources.contentAccessDate)
        date("attributeModificationDate", resources.attributeModificationDate)
        date("addedToDirectoryDate", resources.addedToDirectoryDate)

        // What it is
        flag("isDirectory", resources.isDirectory)
        flag("isRegularFile", resources.isRegularFile)
        flag("isSymbolicLink", resources.isSymbolicLink)
        flag("isAliasFile", resources.isAliasFile)
        flag("isVolume", resources.isVolume)
        flag("isPackage", resources.isPackage)
        flag("isApplication", resources.isApplication)

        // Visibility and protection
        flag("isHidden", resources.isHidden)
        flag("hasHiddenExtension", resources.hasHiddenExtension)
        flag("isReadable", resources.isReadable)
        flag("isWritable", resources.isWritable)
        flag("isExecutable", resources.isExecutable)
        flag("isSystemImmutable", resources.isSystemImmutable)
        flag("isUserImmutable", resources.isUserImmutable)
        flag("isExcludedFromBackup", resources.isExcludedFromBackup)
        flag("isPurgeable", resources.isPurgeable)
        flag("isSparse", resources.isSparse)
        flag("mayHaveExtendedAttributes", resources.mayHaveExtendedAttributes)
        flag("mayShareFileContent", resources.mayShareFileContent)

        // iCloud
        flag("isUbiquitousItem", resources.isUbiquitousItem)
        flag("ubiquitousItemIsUploaded", resources.ubiquitousItemIsUploaded)
        flag("ubiquitousItemIsUploading", resources.ubiquitousItemIsUploading)
        flag("ubiquitousItemIsDownloading", resources.ubiquitousItemIsDownloading)
        flag("ubiquitousItemDownloadRequested", resources.ubiquitousItemDownloadRequested)
        flag("ubiquitousItemHasUnresolvedConflicts", resources.ubiquitousItemHasUnresolvedConflicts)
        text("ubiquitousItemContainerDisplayName", resources.ubiquitousItemContainerDisplayName)

        #if os(macOS)
        if let tags = resources.tagNames, !tags.isEmpty { put("tagNames", .list(tags)) }
        count("labelNumber", resources.labelNumber)
        text("localizedLabel", resources.localizedLabel)
        flag("isMountTrigger", resources.isMountTrigger)
        flag("applicationIsScriptable", resources.applicationIsScriptable)
        #endif

        // Whatever the SDK exposes only through the untyped dictionary.
        for (key, value) in resources.allValues {
            let name = normalise(key.rawValue)
            guard values["fs.\(name)"] == nil else { continue }
            if let type = value as? UTType {
                values["fs.\(name)"] = .text(type.identifier)
            } else if let converted = RawValue.convert(value) {
                values["fs.\(name)"] = converted
            }
        }

        // POSIX facts, which resource values do not carry at all.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            text("owner", attributes[.ownerAccountName] as? String)
            text("group", attributes[.groupOwnerAccountName] as? String)
            if let posix = attributes[.posixPermissions] as? NSNumber {
                put("permissions", .text(String(posix.intValue, radix: 8)))
            }
            if let inode = attributes[.systemFileNumber] as? NSNumber {
                put("inode", .integer(inode.intValue))
            }
        }

        #if os(macOS)
        text("finderComment", ExtendedAttributes.finderComment(of: url))
        text("whereFrom", ExtendedAttributes.whereFrom(of: url))
        #endif

        return values
    }

    /// `_NSURLPathKey` becomes `path`.
    ///
    /// Some keys are exported with a leading underscore, which is an
    /// implementation detail rather than part of the name.
    static func normalise(_ rawValue: String) -> String {
        var name = rawValue
        while name.hasPrefix("_") { name.removeFirst() }
        if name.hasPrefix("NSURL") { name.removeFirst(5) }
        if name.hasSuffix("Key") { name.removeLast(3) }
        guard let first = name.first else { return rawValue }
        return first.lowercased() + name.dropFirst()
    }
}
