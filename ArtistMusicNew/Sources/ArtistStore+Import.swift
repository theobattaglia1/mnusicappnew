// ─── ArtistStore+Import.swift ────────────────────────────────────────────────
import Foundation

extension ArtistStore {
    /// Import a file and add to the specified artist
    public func importSong(from url: URL, artistID: UUID) {
        // 1) Access the external file
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        // 2) Copy into App Support/ArtistMusic/Audio
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let audioDir = supportDir
            .appendingPathComponent("ArtistMusic/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: audioDir,
            withIntermediateDirectories: true
        )

        let dest = audioDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            print("❌ Copy error:", error)
        }

        // 3) Build the Song—fileName must match the copied filename
        let song = Song(
            id: UUID(),
            title: dest.deletingPathExtension().lastPathComponent,
            version: "",
            creators: [],
            date: Date(),
            notes: "",
            artworkData: nil,
            fileName: dest.lastPathComponent
        )

        // 4) Add to the specified artist
        add(song, to: artistID)
    }

    /// Sync playlists from a folder→files map
    /// Called by FileSystemManager.refreshAllFiles()
    public func syncPlaylists(from map: [URL: [URL]]) {
        guard !artists.isEmpty else { return }
        let artistIndex = 0
        var names = Set<String>()

        for (folder, urls) in map {
            let name = folder.lastPathComponent
            names.insert(name)

            let ids: [UUID] = urls.compactMap { fileURL in
                artists[artistIndex]
                  .songs
                  .first(where: { $0.fileName == fileURL.lastPathComponent })?
                  .id
            }

            if let idx = artists[artistIndex].playlists.firstIndex(where: { $0.name == name }) {
                artists[artistIndex].playlists[idx].songIDs = ids
            } else {
                artists[artistIndex].playlists.append(Playlist(name: name, songIDs: ids))
            }
        }

        // Remove any playlists that no longer have a backing folder
        artists[artistIndex].playlists.removeAll { pl in
            pl.name != "All Songs" && !names.contains(pl.name)
        }
    }
}
