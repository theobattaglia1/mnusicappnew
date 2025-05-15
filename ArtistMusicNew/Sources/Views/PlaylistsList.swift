//
//  PlaylistsList.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct PlaylistsList: View {
    @EnvironmentObject private var store: ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    
    let artistID: UUID
    @State private var selectedPlaylist: UUID?
    @State private var isEditMode = false
    @State private var selectedPlaylists = Set<UUID>()
    
    private var artist: Artist? {
        store.artists.first { $0.id == artistID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(artist?.playlists ?? []) { pl in
                        playlistRow(pl)
                    }
                }
            }
            .toolbar { ToolbarItemGroup(placement: .navigationBarTrailing) { EditButton() } }
            .fullScreenCover(item: $selectedPlaylist) { openPlaylistDetail($0) }
        }
    }
    
    // ────────────────────────────────────────────────────────────
    // Header
    private var header: some View {
        HStack {
            Text("Playlists (\(artist?.playlists.count ?? 0))")
                .font(.title3).fontWeight(.semibold)
            Spacer()
            Button { NotificationCenter.default.post(name: .init("AddPlaylistTapped"), object: nil) }
            label: { Image(systemName: "plus.circle.fill").font(.title3) }
            Button(isEditMode ? "Done" : "Edit") { toggleEditMode() }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, isEditMode ? 4 : 12)
    }
    
    private func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode { selectedPlaylists.removeAll() }
    }
    
    // ────────────────────────────────────────────────────────────
    // Single‐row
    @ViewBuilder
    private func playlistRow(_ pl: Playlist) -> some View {
        HStack(spacing: 12) {
            Group {
                if let d = pl.artworkData, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "music.note.list")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(pl.name).lineLimit(1)
                Text("\(pl.songIDs.count) track\(pl.songIDs.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isEditMode {
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(isEditMode && selectedPlaylists.contains(pl.id)
                    ? Color.accentColor.opacity(0.05)
                    : .clear)
        .contentShape(Rectangle())
        .onTapGesture { if !isEditMode { selectedPlaylist = pl.id } }
        .onDrop(of: [UTType.fileURL, UTType.audio, UTType.item, UTType.plainText], isTargeted: nil) {
            handleDrop($0, into: pl)
        }
        Divider().padding(.leading, isEditMode ? 56 : 78)
    }
    
    // ────────────────────────────────────────────────────────────
    // Open detail
    private func openPlaylistDetail(_ playlistID: UUID) -> some View {
        guard let pl = artist?.playlists.first(where: { $0.id == playlistID }) else {
            return AnyView(EmptyView())
        }
        return AnyView(
            PlaylistDetailSheet(artist: artist!, playlist: pl)
                .environmentObject(store)
                .environmentObject(player)
                .padding(.bottom, player.current != nil ? 90 : 0)
        )
    }
    
    // ────────────────────────────────────────────────────────────
    // Drop handler
    private func handleDrop(_ providers: [NSItemProvider], into pl: Playlist) -> Bool {
        // 1) Plain-text = existing song UUID
        if let p = providers.first(
            where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        ) {
            p.loadObject(ofClass: NSString.self) { reading, _ in
                // downcast from NSItemProviderReading → NSString → String
                guard
                    let ns = reading as? NSString,
                    let sid = UUID(uuidString: ns as String)
                else { return }
                
                DispatchQueue.main.async {
                    _ = store.add(songID: sid, to: pl.id, for: artistID)
                }
            }
            return true
        }
        
        
        // 2) File URL
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) })
        {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url  = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                store.importSong(from: url, artistID: artistID)
                if let newSong = store.artists.first(where: { $0.id == artistID })?.songs.last {
                    DispatchQueue.main.async {
                        _ = store.add(songID: newSong.id, to: pl.id, for: artistID)
                    }
                }
            }
            return true
        }
        
        // 2) Drop raw-audio blob → write & import on main thread
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }) {
            p.loadDataRepresentation(forTypeIdentifier: UTType.audio.identifier) { data, _ in
                guard let data = data else { return }
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")
                do {
                    try data.write(to: tmp)
                    DispatchQueue.main.async {
                        store.importSong(from: tmp, artistID: artistID)
                    }
                } catch {
                    print("❌ temp write failed:", error)
                }
            }
            return true
        }
        return false
    }
}
