//  ArtistStore.swift
//  ArtistMusic
//
//  JSON-backed store for artists, songs, and playlists,
//  stored in iCloud Drive’s Documents (or App Support fallback).

import Foundation
import Combine

@MainActor
final class ArtistStore: ObservableObject {
    
    // ───────── Published to UI
    @Published var artists: [Artist] = []
    
    // ───────── File location for JSON in iCloud Drive or fallback
    private let fileURL: URL = {
        // 1) Try iCloud Drive container’s Documents folder first
        if let ubiq = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true) {
            let folder = ubiq.appendingPathComponent("ArtistMusic", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            return folder.appendingPathComponent("artists.json")
        }
        // 2) Fallback to Application Support
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("ArtistMusic", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder.appendingPathComponent("artists.json")
    }()
    
    // MARK: – init
    init() {
        // 1) Load existing JSON if present
        load()
        // 2) If still empty, seed demo then save
        if artists.isEmpty {
            artists = Self.demoArtists()
            save()
        }
    }
    
    // MARK: – Artist helpers
    func update(_ artist: Artist) {
        guard let i = artists.firstIndex(where: { $0.id == artist.id }) else { return }
        artists[i] = artist
        save()
    }
    
    func updateName(_ name: String, for id: UUID) {
        guard let i = artists.firstIndex(where: { $0.id == id }) else { return }
        artists[i].name = name
        save()
    }
    
    /// Create a new artist (with an empty “All Songs” playlist) and save.
    func addArtist(name: String) {
        let new = Artist(
            name:       name,
            bannerData: nil,
            avatarData: nil,
            songs:      [],
            playlists:  [Playlist(name: "All Songs", songIDs: [])]
        )
        artists.append(new)
        save()
    }
    
    // MARK: – Song helpers
    func add(_ song: Song, to artistID: UUID) {
        guard let a = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[a].songs.append(song)
        ensureAllSongsPlaylistContains(id: song.id, atArtist: a)
        save()
    }
    
    func update(_ song: Song, for artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let s = artists[a].songs.firstIndex(where: { $0.id == song.id })
        else { return }
        artists[a].songs[s] = song
        save()
    }
    
    func delete(songID: UUID, for artistID: UUID) {
        guard let a = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[a].songs.removeAll { $0.id == songID }
        for i in artists[a].playlists.indices {
            artists[a].playlists[i].songIDs.removeAll { $0 == songID }
        }
        save()
    }
    
    func removeSong(id songID: UUID, from playlistID: UUID, for artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let p = artists[a].playlists.firstIndex(where: { $0.id == playlistID })
        else { return }
        artists[a].playlists[p].songIDs.removeAll { $0 == songID }
        save()
    }
    
    func updatePlaylist(
        id: UUID,
        for artistID: UUID,
        newName: String? = nil,
        newDescription: String? = nil
    ) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let p = artists[a].playlists.firstIndex(where: { $0.id == id })
        else { return }
        if let name = newName { artists[a].playlists[p].name = name }
        if let desc = newDescription { artists[a].playlists[p].description = desc }
        save()
    }
    
    func setPlaylistArtwork(_ data: Data?, for playlistID: UUID, artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let p = artists[a].playlists.firstIndex(where: { $0.id == playlistID })
        else { return }
        artists[a].playlists[p].artworkData = data
        save()
    }
    
    func deletePlaylist(_ playlistID: UUID, for artistID: UUID) {
        guard let a = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[a].playlists.removeAll { $0.id == playlistID }
        save()
    }
    
    // ─────── Batch helpers
    func delete(songs ids: [UUID], for artistID: UUID) {
        guard let a = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[a].songs.removeAll { ids.contains($0.id) }
        for i in artists[a].playlists.indices {
            artists[a].playlists[i].songIDs.removeAll { ids.contains($0) }
        }
        save()
    }
    
    func batchUpdate(
        _ ids: [UUID],
        for artistID: UUID,
        newVersion:  String?,
        newCreators: [String]?,
        newArtwork:  Data?
    ) {
        guard let a = artists.firstIndex(where: { $0.id == artistID }) else { return }
        for i in artists[a].songs.indices where ids.contains(artists[a].songs[i].id) {
            if let v  = newVersion  { artists[a].songs[i].version     = v }
            if let cr = newCreators { artists[a].songs[i].creators    = cr }
            if let da = newArtwork  { artists[a].songs[i].artworkData = da }
        }
        save()
    }
    
    private func ensureAllSongsPlaylistContains(id: UUID, atArtist a: Int) {
        if let p = artists[a].playlists.firstIndex(where: { $0.name == "All Songs" }) {
            if !artists[a].playlists[p].songIDs.contains(id) {
                artists[a].playlists[p].songIDs.insert(id, at: 0)
            }
        } else {
            let list = Playlist(name: "All Songs", songIDs: [id])
            artists[a].playlists.insert(list, at: 0)
        }
    }
    
    // ───────── Playlist helpers
    func addPlaylist(name: String, for artistID: UUID) {
        guard let i = artists.firstIndex(where: { $0.id == artistID }) else { return }
        let p = Playlist(name: name, songIDs: [])
        artists[i].playlists.insert(p, at: 0)
        save()
    }
    
    func movePlaylists(of artistID: UUID, from src: IndexSet, to dst: Int) {
        guard let i = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[i].playlists.move(fromOffsets: src, toOffset: dst)
        save()
    }
    
    func add(songID: UUID, to listID: UUID, for artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let l = artists[a].playlists.firstIndex(where: { $0.id == listID })
        else { return }
        var ids = artists[a].playlists[l].songIDs
        if !ids.contains(songID) { ids.append(songID) }
        artists[a].playlists[l].songIDs = ids
        save()
    }
    
    func updatePlaylistName(_ playlistID: UUID, newName: String, for artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let p = artists[a].playlists.firstIndex(where: { $0.id == playlistID })
        else { return }
        artists[a].playlists[p].name = newName
        save()
    }
    
    // ───────── Artwork setters
    func setBanner(_ data: Data?, for artistID: UUID) {
        guard let i = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[i].bannerData = data
        save()
    }
    
    func setAvatar(_ data: Data?, for artistID: UUID) {
        guard let i = artists.firstIndex(where: { $0.id == artistID }) else { return }
        artists[i].avatarData = data
        save()
    }
    
    func setArtwork(_ data: Data?, for songID: UUID, artistID: UUID) {
        guard
            let a = artists.firstIndex(where: { $0.id == artistID }),
            let s = artists[a].songs.firstIndex(where: { $0.id == songID })
        else { return }
        artists[a].songs[s].artworkData = data
        save()
    }
    
    // MARK: – Persistence
    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            artists = try JSONDecoder().decode([Artist].self, from: data)
            print("✅ ArtistStore loaded", artists.count, "artist(s) from", fileURL.path)
        } catch {
            print("🛑 ArtistStore load error:", error.localizedDescription)
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(artists)
            try data.write(to: fileURL, options: .atomic)
            print("💾 ArtistStore saved", artists.count, "artist(s) to", fileURL.path)
        } catch {
            print("🛑 ArtistStore save error:", error.localizedDescription)
        }
    }
    
    // MARK: – Demo seed
    private static func demoArtists() -> [Artist] {
        let demoSong = Song(
            title:       "Me & You",
            version:     "Master",
            creators:    ["Alex Skrindo","Uplink"],
            date:        .now,
            notes:       "",
            artworkData: nil,
            fileName:    "MeAndYou.mp3"
        )
        return [
            Artist(
                name:       "Demo Artist",
                bannerData: nil,
                avatarData: nil,
                songs:      [demoSong],
                playlists:  [Playlist(name: "All Songs", songIDs: [demoSong.id])]
            )
        ]
    }
    
}
