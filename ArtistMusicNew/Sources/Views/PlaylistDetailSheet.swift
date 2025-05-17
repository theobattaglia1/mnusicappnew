//
//  PlaylistDetailSheet.swift
//  ArtistMusic
//
//  Drag-reorder + multi-select delete inside a playlist
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaylistDetailSheet: View {

    // Inputs
    let playlistID: UUID
    let artistID  : UUID

    // Environment
    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss

    // UI State
    @State private var editMode  = EditMode.inactive
    @State private var selection = Set<UUID>()
    @State private var hoverID   : UUID?

    // Live look-ups
    private var artist  : Artist?   { store.artists.first { $0.id == artistID  } }
    private var playlist: Playlist? { artist?.playlists.first { $0.id == playlistID } }
    private var songs   : [Song]    {
        guard let art = artist, let pl = playlist else { return [] }
        return pl.songIDs.compactMap { id in art.songs.first { $0.id == id } }
    }

    // MARK: Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                listView
                overlayButtons
            }
            .navigationTitle(playlist?.name ?? "Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar { closeToolbar }
        }
    }

    // MARK: List with reorder + multi-select
    private var listView: some View {
        List(selection: $selection) {
            ForEach(songs) { song in
                SongRowView(song: song,
                            isHighlighted: hoverID == song.id,
                            isCurrent:     player.current == song,
                            isPlaying:     player.isPlaying)
                    .buttonStyle(.plain)           // lets double-click/tap through
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { player.playSong(song) }
                    .onHover { hovering in
                        #if targetEnvironment(macCatalyst)
                        hoverID = hovering ? song.id : nil
                        #endif
                    }
            }
            .onMove { src, dst in
                store.moveSongs(in: playlistID,
                                for: artistID,
                                fromOffsets: src,
                                toOffset: dst)
            }
        }
        .listStyle(.plain)
    }

    // MARK: Overlay top-right controls
    private var overlayButtons: some View {
        HStack(spacing: 20) {
            if editMode == .inactive {
                Button("Edit") { editMode = .active }
            } else {
                Button(role: .destructive) {
                    store.remove(songIDs: Array(selection),
                                 from: playlistID,
                                 artistID: artistID)
                    selection.removeAll()
                    editMode = .inactive
                } label: { Image(systemName: "trash") }

                Button("Done") { editMode = .inactive }
            }
        }
        .padding(.top, 4)
        .padding(.trailing, 24)
    }

    // Close (Done) button in nav bar
    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
    }
}
