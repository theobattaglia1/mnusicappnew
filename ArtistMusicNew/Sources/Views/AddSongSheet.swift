//
//  AddSongSheet.swift
//  ArtistMusic
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct AddSongSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject     private var store: ArtistStore

    let artistID: UUID

    // ───────── form fields
    @State private var title        = ""
    @State private var version      = "Master"
    @State private var creatorsText = ""
    @State private var notes        = ""
    @State private var artworkData: Data?

    // ───────── pickers
    @State private var showImporter      = false
    @State private var pickedURL: URL?
    @State private var showArtworkPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Title",   text: $title)
                    TextField("Version", text: $version)
                    TextField("Creators (comma-separated)",
                              text: $creatorsText)
                }

                Section("Artwork") {
                    Button { showArtworkPicker = true } label: {
                        if let data = artworkData,
                           let ui   = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Choose Image", systemImage: "photo.on.rectangle")
                        }
                    }
                }

                Section("Audio file") {
                    if let pickedURL {
                        Text(pickedURL.lastPathComponent)
                            .lineLimit(2)
                    }
                    Button("Select File") { showImporter = true }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Song")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.isEmpty || pickedURL == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // MARK: – file importer for audio
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                guard let url = try? result.get().first else { return }
                pickedURL = url
            }
            // MARK: – artwork picker
            .sheet(isPresented: $showArtworkPicker) {
                ImagePicker(data: Binding(
                    get: { artworkData },
                    set: { artworkData = $0 }
                ))
            }
        }
    }

    // MARK: – Save action
    private func save() {
        guard let src = pickedURL else { return }

        // 1) Security-scope if needed (iCloud/files app)
        let didStart = src.startAccessingSecurityScopedResource()
        defer { if didStart { src.stopAccessingSecurityScopedResource() } }

        // 2) Ensure ~/Library/Application Support/ArtistMusic/Audio exists
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory,
                  in: .userDomainMask)[0]
        let audioDir = support
            .appendingPathComponent("ArtistMusic/Audio", isDirectory: true)
        try? FileManager.default
            .createDirectory(at: audioDir,
                             withIntermediateDirectories: true)

        // 3) Copy the picked file into our Audio folder
        let dest = audioDir.appendingPathComponent(src.lastPathComponent)
        do {
            // If there’s an existing file with the same name, remove it
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
        } catch {
            print("❌ Copy failed:", error)
        }

        // 4) Build our Song model
        let song = Song(
            id:         UUID(),
            title:      title,
            version:    version,
            creators:   creatorsText
                          .split(separator: ",")
                          .map { $0.trimmingCharacters(in: .whitespaces) },
            date:       Date(),
            notes:      notes,
            artworkData: artworkData,
            fileName:   dest.lastPathComponent
        )

        // 5) Add + save via ArtistStore
        store.add(song, to: artistID)

        // 6) Dismiss sheet
        dismiss()
    }
}
