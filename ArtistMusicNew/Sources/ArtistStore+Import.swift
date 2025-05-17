//
//  ArtistStore+Import.swift
//  ArtistMusic
//
//  Created 15 May 2025
//

import Foundation
import UniformTypeIdentifiers

// MARK: – Public API
extension ArtistStore {

    /// Copy an audio file into **App Support/ArtistMusic/Audio/**,
    /// preserving the original filename (adding “-1,-2 …” on collision),
    /// then registers it as a new `Song` for `artistID`.
    @MainActor
    public func importSong(from sourceURL: URL, artistID: UUID) {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        // ── Destination folder
        let support  = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask)[0]
        let audioDir = support.appendingPathComponent("ArtistMusic/Audio",
                                                      isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir,
                                                 withIntermediateDirectories: true)

        // ── Preserve filename
        var dest = audioDir.appendingPathComponent(sourceURL.lastPathComponent)
        var idx  = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let base = sourceURL.deletingPathExtension().lastPathComponent
            let ext  = sourceURL.pathExtension
            dest = audioDir.appendingPathComponent("\(base)-\(idx).\(ext)")
            idx += 1
        }

        // ── Copy
        do    { try FileManager.default.copyItem(at: sourceURL, to: dest) }
        catch { print("❌ Import copy error:", error); return }

        // ── Register
        let newSong = Song(id: UUID(),
                           title: sourceURL.deletingPathExtension().lastPathComponent,
                           version: "",
                           creators: [],
                           date: Date(),
                           notes: "",
                           artworkData: nil,
                           fileName: dest.lastPathComponent)

        add(newSong, to: artistID)
        print("✅ Imported", newSong.title)
    }

    /// Placeholder so `FileSystemManager` continues to compile.
    /// Implement actual logic if/when playlist-file syncing is required.
    @MainActor
    public func syncPlaylists() {
        print("ℹ️ ArtistStore.syncPlaylists() – placeholder")
    }
}
