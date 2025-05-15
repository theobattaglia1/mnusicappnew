//
//  PlaylistDetailSheet.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct PlaylistDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer

    let artist: Artist
    let playlist: Playlist

    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var editName = ""
    @State private var showRenameAlert = false
    @State private var isDropTargeted = false

    private var playlistSongs: [Song] {
        playlist.songIDs.compactMap { id in
            artist.songs.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // — Header with artwork + play button —
                PlaylistHeaderView(
                    playlist: playlist,
                    artist: artist,
                    playlistSongs: playlistSongs,
                    onImageTap: { showImagePicker = true }
                )
                Divider()

                // — List of songs with improved drop handling —
                ZStack {
                    List {
                        if !playlistSongs.isEmpty {
                            ForEach(playlistSongs) { song in
                                HStack {
                                    // Song artwork
                                    Group {
                                        if let data = song.artworkData, let ui = UIImage(data: data) {
                                            Image(uiImage: ui).resizable().scaledToFill()
                                        } else {
                                            Image(systemName: "music.note")
                                                .resizable().scaledToFit()
                                                .padding(8)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    // Song details
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .fontWeight(.medium)
                                        Text(song.artistLine)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    
                                    // Play button
                                    Button {
                                        player.playSong(song)
                                    } label: {
                                        Image(systemName: "play.circle")
                                            .font(.title3)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    player.playSong(song)
                                }
                            }
                            .onDelete { idxs in
                                let toRemove = idxs.map { playlistSongs[$0].id }
                                for id in toRemove {
                                    store.removeSong(id: id,
                                                     from: playlist.id,
                                                     for: artist.id)
                                }
                            }
                        } else {
                            Text("No songs in this playlist")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                // Apply our custom drop target modifier with a completion handler to add to playlist
                .audioFileDropTarget(
                    isTargeted: $isDropTargeted,
                    artistID: artist.id,
                    store: store,
                    onImportComplete: { newSongID in
                        // Add the newly imported song to this playlist
                        store.add(songID: newSongID, to: playlist.id, for: artist.id)
                    }
                )
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Rename") {
                                editName = playlist.name
                                showRenameAlert = true
                            }
                            Button("Set Cover Image") {
                                showImagePicker = true
                            }
                            if playlist.name != "All Songs" {
                                Button("Delete Playlist", role: .destructive) {
                                    store.deletePlaylist(
                                        playlist.id,
                                        for: artist.id
                                    )
                                    dismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(data: Binding(
                    get: { playlist.artworkData },
                    set: { newData in
                        store.setPlaylistArtwork(
                            newData,
                            for: playlist.id,
                            artistID: artist.id
                        )
                    }
                ))
            }
            .alert("Rename Playlist", isPresented: $showRenameAlert) {
                TextField("Playlist Name", text: $editName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if !editName.isEmpty {
                        store.updatePlaylistName(
                            playlist.id,
                            newName: editName,
                            for: artist.id
                        )
                    }
                }
            } message: {
                Text("Enter a new name for this playlist.")
            }
        }
    }
}

// MARK: - PlaylistHeaderView (used by PlaylistDetailSheet)
struct PlaylistHeaderView: View {
    let playlist: Playlist
    let artist: Artist
    let playlistSongs: [Song]
    let onImageTap: () -> Void

    @EnvironmentObject private var player: AudioPlayer

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 15) {
                Button(action: onImageTap) {
                    Group {
                        if let d = playlist.artworkData,
                           let ui = UIImage(data: d)
                        {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color.gray.opacity(0.2)
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(playlist.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(playlistSongs.count) songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !playlistSongs.isEmpty {
                        Button {
                            player.enqueue(playlistSongs)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 5)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color.secondary.opacity(0.05))
    }
}