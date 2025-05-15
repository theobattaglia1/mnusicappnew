//
//  SongsList.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SongsList: View {
    @Binding var showingImporter: Bool
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    let artistID: UUID
    let onArtTap: (UUID) -> Void

    @State private var selection: Set<UUID> = []
    @State private var editMode: EditMode = .inactive
    @State private var batchSheet = false
    @State private var editSong: Song?
    @State private var isDropTargeted = false
    @State private var selectedSongID: UUID?

    private var artist: Artist? {
        store.artists.first { $0.id == artistID }
    }

    var body: some View {
        if let artist = artist {
            VStack(spacing: 0) {
                // ── TOP BAR ──
                HStack {
                    Text("Songs")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
                    if editMode == .active {
                        if !selection.isEmpty {
                            Button(role: .destructive) {
                                let ids = Array(selection)
                                store.delete(songs: ids, for: artistID)
                                selection.removeAll()
                                editMode = .inactive
                            } label: {
                                Text("Delete (\(selection.count))")
                            }
                            .padding(.trailing, 8)
                        }
                        Button("Done") {
                            editMode = .inactive
                            selection.removeAll()
                        }
                    } else {
                        Button { showingImporter = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .padding(.trailing, 8)
                        Button("Edit") { editMode = .active }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // ── CUSTOM SONGS LIST ──
                ZStack {
                    // Background for drop target
                    Rectangle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // ScrollView for song list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(artist.chronologicalSongs) { song in
                                SongRowButton(
                                    song: song,
                                    isSelected: selectedSongID == song.id,
                                    artist: artist,
                                    onTap: {
                                        print("🎵 Button tapped for song: \(song.title)")
                                        selectedSongID = song.id
                                        player.playSong(song)
                                    },
                                    onArtTap: { onArtTap(song.id) },
                                    onEdit: { editSong = song },
                                    onAddToPlaylist: { playlistID in
                                        store.add(songID: song.id, to: playlistID, for: artistID)
                                    }
                                )
                                .padding(.horizontal)
                                
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                // Apply our custom drop target modifier
                .audioFileDropTarget(
                    isTargeted: $isDropTargeted,
                    artistID: artistID,
                    store: store
                )
                
                // ── bulk importer & sheets ──
                .fileImporter(
                    isPresented: $showingImporter,
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            let didAccess = url.startAccessingSecurityScopedResource()
                            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                            store.importSong(from: url, artistID: artistID)
                        }
                    case .failure(let err):
                        print("Import error:", err)
                    }
                }
                .sheet(isPresented: $batchSheet) {
                    BatchEditSheet(
                        artistID: artist.id,
                        songIDs: Array(selection)
                    )
                    .environmentObject(store)
                    .onDisappear { selection.removeAll() }
                }
                .sheet(item: $editSong) { song in
                    EditSongSheet(artistID: artist.id, song: song)
                        .environmentObject(store)
                }
            }
        }
    }
}

// MARK: - SongRowButton
// A dedicated button component for song rows to improve clicking reliability
struct SongRowButton: View {
    let song: Song
    let isSelected: Bool
    let artist: Artist
    let onTap: () -> Void
    let onArtTap: () -> Void
    let onEdit: () -> Void
    let onAddToPlaylist: (UUID) -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Artwork with its own tap handler
                SongArtwork(song: song, onTap: onArtTap)
                
                // Song details
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .foregroundColor(.primary)
                        .font(.body)
                        .lineLimit(1)
                    
                    if !song.version.isEmpty {
                        Text(song.version)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if !song.creators.isEmpty {
                        Text(song.creators.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .opacity(isSelected ? 1.0 : 0.6)
                
                // More options menu
                Menu {
                    Button("Play", action: onTap)
                    Button("Edit", action: onEdit)
                    
                    if !artist.playlists.isEmpty {
                        Menu("Add to Playlist") {
                            ForEach(artist.playlists.filter { $0.name != "All Songs" }) { playlist in
                                Button(playlist.name) {
                                    onAddToPlaylist(playlist.id)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Play", action: onTap)
            Button("Edit", action: onEdit)
            
            if !artist.playlists.isEmpty {
                Menu("Add to Playlist") {
                    ForEach(artist.playlists.filter { $0.name != "All Songs" }) { playlist in
                        Button(playlist.name) {
                            onAddToPlaylist(playlist.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SongArtwork
// Dedicated component for the song artwork with tap handling
struct SongArtwork: View {
    let song: Song
    let onTap: () -> Void
    
    var body: some View {
        Group {
            if let data = song.artworkData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .resizable().scaledToFit()
                    .padding(12)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            onTap()
        }
    }
}
