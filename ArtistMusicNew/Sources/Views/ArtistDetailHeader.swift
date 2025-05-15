//
//  ArtistDetailHeader.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/15/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct ArtistDetailHeader: View {
    let artist: Artist
    let onEdit: () -> Void
    let onChangeArtist: () -> Void
    
    @Binding var selectedArtistID: UUID?
    @EnvironmentObject private var store: ArtistStore
    
    // how long to hold before you can swipe:
    private let holdDuration: Double = 0.5
    @State private var dragOffset: CGSize = .zero
    @State private var isPressing = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner with drag-&-drop + swipe gestures
            banner
                .resizable()
                .scaledToFill()
                .frame(height: 260)
                .clipped()
                .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                    // 1) Prefer file URLs
                    if let provider = providers.first(where: {
                        $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                    }) {
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                          options: nil) { item, _ in
                            guard
                                let data = item as? Data,
                                let url  = URL(dataRepresentation: data, relativeTo: nil),
                                let imgD = try? Data(contentsOf: url)
                            else { return }
                            DispatchQueue.main.async {
                                store.setBanner(imgD, for: artist.id)
                            }
                        }
                        return true
                    }
                    // 2) Otherwise accept raw image data
                    if let provider = providers.first(where: {
                        $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                    }) {
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            guard let imgD = data else { return }
                            DispatchQueue.main.async {
                                store.setBanner(imgD, for: artist.id)
                            }
                        }
                        return true
                    }
                    return false
                }
                // long-press to enable swipe
                .gesture(
                    LongPressGesture(minimumDuration: holdDuration)
                        .onEnded { _ in isPressing = true }
                )
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { g in
                            guard isPressing else { return }
                            dragOffset = g.translation
                        }
                        .onEnded { _ in
                            guard isPressing else { return }
                            handleSwipe(translation: dragOffset)
                            isPressing = false
                            dragOffset = .zero
                        }
                )
            
            HStack(spacing: 12) {
                // Avatar with drag-&-drop + long-press to switch
                avatar
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                        // file URLs
                        if let provider = providers.first(where: {
                            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                        }) {
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                                              options: nil) { item, _ in
                                guard
                                    let data = item as? Data,
                                    let url  = URL(dataRepresentation: data, relativeTo: nil),
                                    let imgD = try? Data(contentsOf: url)
                                else { return }
                                DispatchQueue.main.async {
                                    store.setAvatar(imgD, for: artist.id)
                                }
                            }
                            return true
                        }
                        // raw image data
                        if let provider = providers.first(where: {
                            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                        }) {
                            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                                guard let imgD = data else { return }
                                DispatchQueue.main.async {
                                    store.setAvatar(imgD, for: artist.id)
                                }
                            }
                            return true
                        }
                        return false
                    }
                    .onLongPressGesture {
                        onChangeArtist()
                    }
                
                // Artist name (long-press to switch)
                Text(artist.name)
                    .font(.title).bold()
                    .foregroundColor(.white)
                    .shadow(radius: 3)
                    .onLongPressGesture(minimumDuration: holdDuration) {
                        onChangeArtist()
                    }
                
                // Edit pencil
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 32, height: 32)    // larger hit area
                        .contentShape(Rectangle())
                        .foregroundColor(.white)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding([.leading, .bottom], 16)
        }
    }
    
    // ────────────────────────────────────────────────────────────
    private func handleSwipe(translation: CGSize) {
        let threshold: CGFloat = 50
        guard let idx = store.artists.firstIndex(where: { $0.id == artist.id }) else { return }
        if translation.width < -threshold, idx < store.artists.count - 1 {
            selectedArtistID = store.artists[idx + 1].id
        } else if translation.width > threshold, idx > 0 {
            selectedArtistID = store.artists[idx - 1].id
        }
    }
    
    // ────────────────────────────────────────────────────────────
    private var banner: Image {
        artist.bannerData
            .flatMap(UIImage.init(data:))
            .map(Image.init(uiImage:))
        ?? Image(systemName: "photo")
    }
    
    // ────────────────────────────────────────────────────────────
    private var avatar: Image {
        artist.avatarData
            .flatMap(UIImage.init(data:))
            .map(Image.init(uiImage:))
        ?? Image(systemName: "person.circle")
    }
}