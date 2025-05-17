//
//  ArtistDetailView.swift
//  ArtistMusic
//
//  Updated 16 May 2025 — Swift 6–friendly
//

import SwiftUI

struct ArtistDetailView: View {
    // MARK: Environment
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss

    // MARK: UI State
    @State private var tab: Tab = .allSongs
    @State private var showingImporter = false
    @State private var showingArtistPicker = false

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

    // MARK: Input
    let artistID: UUID
    @Binding var selectedArtistID: UUID?
    private var artist: Artist? { store.artists.first { $0.id == artistID } }

    enum Tab: String, CaseIterable, Identifiable {
        case allSongs, playlists, collaborators
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    // MARK: Body
    var body: some View {
        Group {
            if let artist = artist {
                content(for: artist)
            } else {
                VStack {
                    Spacer()
                    Text("Artist not found")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .onAppear { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func content(for artist: Artist) -> some View {
        VStack(spacing: 0) {
            // ───────── HEADER ─────────
            ArtistDetailHeader(
                artist: artist,
                onEdit:         { activeSheet = .editArtist(artist) },
                onChangeArtist: { showingArtistPicker = true },
                selectedArtistID: $selectedArtistID
            )

            CustomTabBar(selectedTab: $tab)

            // ───────── BODY ─────────
            switch tab {
            case .allSongs:
                SongsList(artistID: artist.id)
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
        ) { _ in
            activeSheet = .addPlaylist
        }
        // Switch‐artist confirmationDialog
        .confirmationDialog("Switch Artist",
                            isPresented: $showingArtistPicker) {
            ForEach(store.artists) { a in
                Button(a.name) { selectedArtistID = a.id }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Active sheet handler
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addPlaylist:
                AddPlaylistSheet(artistID: artistID)
                    .environmentObject(store)

            case .songArt(let id):
                ImagePicker(
                    data: Binding<Data?>(
                        get: {
                            store.artists
                                .first { $0.id == artistID }?
                                .songs.first  { $0.id == id }?
                                .artworkData
                        },
                        set: { newData in
                            store.setArtwork(newData, for: id, artistID: artistID)
                        }
                    )
                )

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
