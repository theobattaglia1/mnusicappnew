//
//  PlaylistDetailView.swift
//  ArtistMusic
//
//  Swift 6-ready — 16 May 2025
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaylistDetailView: View {

    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer

    let artistID  : UUID
    let playlistID: UUID

    @State private var isDropTargeted = false
    @State private var hoverID        : UUID?

    // Convenience
    private var artist  : Artist?   { store.artists.first(where: { $0.id == artistID }) }
    private var playlist: Playlist? { artist?.playlists.first(where:{ $0.id == playlistID }) }
    private var songs   : [Song]    {
        guard let a = artist, let p = playlist else { return [] }
        return p.songIDs.compactMap { id in a.songs.first(where: { $0.id == id }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(songs) { song in
                    SongRowView(song: song,
                                isHighlighted: hoverID == song.id,
                                isCurrent:     player.current == song,
                                isPlaying:     player.isPlaying)
                        .onTapGesture { player.playSong(song) }
                        .onHover { hovering in
                            #if targetEnvironment(macCatalyst)
                            hoverID = hovering ? song.id : nil
                            #endif
                        }
                }
            }
            .padding(.horizontal)
        }
        .onDrop(of: [.fileURL, .audio],
                isTargeted: $isDropTargeted,
                perform: handleDrop(providers:))
        .background(isDropTargeted
                    ? Color.accentColor.opacity(0.08)
                    : Color.clear)
        .navigationTitle(playlist?.name ?? "Playlist")
    }

    // MARK: drop handler
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers {

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                  options: nil) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in await addSong(from: url) }
                    } else if let data = item as? Data,
                              let url  = URL(dataRepresentation: data,
                                             relativeTo: nil) {
                        Task { @MainActor in await addSong(from: url) }
                    }
                }
                accepted = true
            }

            else if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.audio.identifier) {
                    url, _, _ in
                    if let url {
                        Task { @MainActor in await addSong(from: url) }
                    }
                }
                accepted = true
            }
        }
        return accepted
    }

    // MARK: helper
    @MainActor
    private func addSong(from url: URL) async {
        store.importSong(from: url, artistID: artistID)
        if let newID = store.artists
            .first(where: { $0.id == artistID })?
            .songs.last?.id
        {
            store.add(songID: newID, to: playlistID, for: artistID)
        }
    }
}
