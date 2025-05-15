// ─── FileSystemView.swift ─────────────────────────────────────────────────────
import SwiftUI
import UniformTypeIdentifiers

struct FileSystemView: View {
    @EnvironmentObject private var store: ArtistStore
    @StateObject private var fs = FileSystemManager()
    @State private var showingPicker = false

    // Computed ID for the "External Imports" artist
    private var importArtistID: UUID? {
        store.artists.first(where: { $0.name == "External Imports" })?.id
    }

    var body: some View {
        NavigationStack {
            List {
                if fs.files.isEmpty {
                    ContentUnavailableView(
                        "Drop audio files into any selected folder",
                        systemImage: "tray.and.arrow.down"
                    )
                } else {
                    ForEach(fs.files, id: \.self) { url in
                        HStack {
                            Image(systemName: "music.note")
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button("Add") {
                                guard let artistID = importArtistID else { return }
                                store.importSong(from: url, artistID: artistID)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showingPicker = true
                        } label: {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                                .labelStyle(.iconOnly)
                        }
                        Button {
                            if let first = fs.folders.first {
                                UIApplication.shared.open(first)
                            }
                        } label: {
                            Label("Open in Files", systemImage: "folder")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    urls.forEach { fs.addFolder($0) }
                }
            }
            .onAppear { fs.attach(store) }
        }
    }
}
