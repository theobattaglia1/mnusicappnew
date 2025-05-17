//
//  SongsList.swift
//  ArtistMusic
//
//  Multi‑select outside Edit, drag carries all selected rows, double‑click plays.
//  Uses AppKit modifiers only on real macOS (not Catalyst) to avoid NSEvent errors.
//
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit   // for NSEvent on native macOS
#endif

struct SongsList: View {
    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer
    let artistID: UUID

    @State private var editMode     = EditMode.inactive
    @State private var selection    = Set<UUID>()
    @State private var showImporter = false

    // Keep artist.songs order so drag‑reorder persists
    private var songs: [Song] {
        store.artists.first { $0.id == artistID }?.songs ?? []
    }

    // MARK: body
    var body: some View {
        ZStack(alignment: .topTrailing) {
            list
            overlay
        }
        .navigationTitle("All Songs")
        .environment(\.editMode, $editMode)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType.audio],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                urls.forEach { store.importSong(from: $0, artistID: artistID) }
            }
        }
    }

    // MARK: list
    private var list: some View {
        List(selection: $selection) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongRowView(song: song,
                            isHighlighted: selection.contains(song.id),
                            isCurrent:     player.current == song,
                            isPlaying:     player.isPlaying)
                    .contentShape(Rectangle())
                    .simultaneousGesture( singleClick(index: index, id: song.id) )
                    .highPriorityGesture( doubleClick(song: song) )
                    .onDrag { provider(for: song) }
            }
            .onMove { src, dst in
                store.moveSongs(for: artistID, fromOffsets: src, toOffset: dst)
            }
        }
        .listStyle(.plain)
    }

    // MARK: gestures
    private func singleClick(index: Int, id: UUID) -> some Gesture {
        TapGesture(count: 1).onEnded {
            if editMode == .inactive { handleSelection(index: index, id: id) }
        }
    }

    private func doubleClick(song: Song) -> some Gesture {
        TapGesture(count: 2).onEnded {
            if editMode == .inactive { player.playSong(song) }
        }
    }

    // MARK: selection logic
    private func handleSelection(index: Int, id: UUID) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let mods = NSEvent.modifierFlags
        if mods.contains(.shift), let anchor = selection.first,
           let first = songs.firstIndex(where: { $0.id == anchor }) {
            let range = songs[min(first,index)...max(first,index)]
            selection.formUnion(range.map(\.id))
        } else if mods.contains(.command) {
            toggle(id)
        } else {
            selection = [id]
        }
        #else
        toggle(id)
        #endif
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    // MARK: overlay
    private var overlay: some View {
        HStack(spacing: 20) {
            if editMode == .inactive {
                Button { showImporter = true } label: { Image(systemName: "plus") }
                Button("Edit") { editMode = .active }
            } else {
                Button("Select All") { selection = Set(songs.map(\.id)) }
                Button(role: .destructive) {
                    store.delete(songs: Array(selection), for: artistID)
                    selection.removeAll()
                    editMode = .inactive
                } label: { Image(systemName: "trash") }
                Button("Done") { editMode = .inactive }
            }
        }
        .padding(.top, 4)
        .padding(.trailing, 24)
    }

    // MARK: drag provider
    private func provider(for song: Song) -> NSItemProvider {
        let ids = selection.isEmpty ? [song.id] : Array(selection)
        let payload = try? JSONEncoder().encode(ids)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: "com.theo.artistmusic.song-id",
                                            visibility: .all) { completion -> Progress? in
            completion(payload, nil)
            return nil
        }
        provider.registerObject(ids.map(\.uuidString).joined(separator: ", ") as NSString,
                                visibility: .all)
        return provider
    }
}
