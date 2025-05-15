//
//  ArtistDetailView.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI

struct ArtistDetailView: View {
    // Store + nav
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    // UI state
    @State private var tab: Tab = .allSongs
    @State private var showingImporter = false
    @State private var showingArtistPicker = false
    
    // Single‐sheet handler
    enum ActiveSheet: Identifiable {
        case addPlaylist
        case songArt(UUID)
        case collaborator(String)
        case editArtist(Artist)
        var id: String {
            switch self {
            case .addPlaylist:        return "addPlaylist"
            case .songArt(let id):    return "songArt-\(id)"
            case .collaborator(let n):return "collab-\(n)"
            case .editArtist(let a):  return "editArtist-\(a.id)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?
    
    // Input
    let artistID: UUID
    @Binding var selectedArtistID: UUID?
    private var artist: Artist? { store.artists.first { $0.id == artistID } }
    
    enum Tab: String, CaseIterable, Identifiable {
        case allSongs, playlists, collaborators
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    
    var body: some View {
        if let artist = artist {
            content(for: artist)
        } else {
            VStack { Spacer(); Text("Artist not found").foregroundColor(.secondary); Spacer() }
                .onAppear { dismiss() }
        }
    }
    
    @ViewBuilder
    private func content(for artist: Artist) -> some View {
        VStack(spacing: 0) {
            // ───────── HEADER ─────────
            ArtistDetailHeader(
                artist: artist,
                onEdit: { activeSheet = .editArtist(artist) },
                onChangeArtist: { showingArtistPicker = true },
                selectedArtistID: $selectedArtistID
            )
            
            CustomTabBar(selectedTab: $tab)
            
            // ───────── BODY TABS ─────────
            switch tab {
            case .allSongs:
                SongsList(
                    showingImporter: $showingImporter,
                    artistID: artist.id,
                    onArtTap: { id in activeSheet = .songArt(id) }
                )
            case .playlists:
                PlaylistsList(artistID: artist.id)
            case .collaborators:
                CollaboratorsList(
                    artist: artist,
                    onTap: { name in activeSheet = .collaborator(name) }
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name("AddPlaylistTapped"))
        ) { _ in activeSheet = .addPlaylist }
        .confirmationDialog("Switch artist…",
                            isPresented: $showingArtistPicker,
                            titleVisibility: .visible) {
            ForEach(store.artists) { a in
                Button(a.name) { selectedArtistID = a.id }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addPlaylist:
                AddPlaylistSheet(artistID: artistID)
                    .environmentObject(store)
            case .songArt(let id):
                ImagePicker(data: Binding<Data?>(
                    get: {
                        store.artists
                            .first { $0.id == artistID }?
                            .songs
                            .first  { $0.id == id }?
                            .artworkData
                    },
                    set: { newData in
                        store.setArtwork(newData, for: id, artistID: artistID)
                    }
                ))
            case .collaborator(let name):
                CollaboratorDetailView(name: name)
                    .environmentObject(store)
            case .editArtist(let artist):
                EditArtistSheet(artist: artist)
                    .environmentObject(store)
            }
        }
    }
}