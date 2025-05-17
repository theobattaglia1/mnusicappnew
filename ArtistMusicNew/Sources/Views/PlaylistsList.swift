//
//  PlaylistsList.swift
//  ArtistMusic
//
//  Swift 6 – overlay “+ / Edit | Done” anchored top‑trailing
//             (matches SongsList behaviour)
//
import SwiftUI
import UIKit

struct PlaylistsList: View {
    @EnvironmentObject private var store : ArtistStore
    let artistID: UUID

    @State private var editMode   = EditMode.inactive
    @State private var showingAdd = false
    @State private var newName    = ""

    // Original order so drag‑reorder persists
    private var playlists: [Playlist] {
        store.artists.first { $0.id == artistID }?.playlists ?? []
    }

    // MARK: body
    var body: some View {
        ZStack(alignment: .topTrailing) {
            listView
            overlayButtons
        }
        .navigationTitle("Playlists")
        .environment(\.editMode, $editMode)
        .alert("New Playlist", isPresented: $showingAdd) {
            TextField("Name", text: $newName)
            Button("Add", action: addPlaylist)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for your new playlist")
        }
    }

    // MARK: list
    private var listView: some View {
        List {
            ForEach(playlists) { pl in
                NavigationLink {
                    if let artist = store.artists.first(where: { $0.id == artistID }) {
                        PlaylistDetailSheet(
                            playlistID: pl.id,
                            artistID:   artist.id
                        )
                        .environmentObject(store)
                    }
                } label: {
                    PlaylistRow(playlist: pl)
                }

            }
            .onMove { src, dst in
                store.movePlaylists(for: artistID, fromOffsets: src, toOffset: dst)
            }
        }
        .listStyle(.plain)
    }

    // MARK: overlay buttons
    private var overlayButtons: some View {
        HStack(spacing: 20) {
            if editMode == .inactive {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                Button("Edit") { editMode = .active }
            } else {
                Button("Done") { editMode = .inactive }
            }
        }
        .padding(.top, 4)
        .padding(.trailing, 24)
    }

    // MARK: actions
    private func addPlaylist() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let pl = Playlist(id: UUID(), name: trimmed, songIDs: [], artworkData: nil)
        store.add(playlist: pl, to: artistID)
        newName = ""
    }
}

// MARK: Playlist row
private struct PlaylistRow: View {
    let playlist: Playlist
    var body: some View {
        HStack {
            thumbnail.resizable().frame(width: 40, height: 40).cornerRadius(4)
            VStack(alignment: .leading) {
                Text(playlist.name).font(.headline)
                Text("\(playlist.songIDs.count) song\(playlist.songIDs.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    private var thumbnail: Image {
        if let data = playlist.artworkData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
        } else {
            Image(systemName: "rectangle.stack")
        }
    }
}
