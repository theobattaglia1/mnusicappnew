//
//  ArtistMusicApp.swift
//  ArtistMusic
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit   // for UIDragInteraction

@main
struct ArtistMusicApp: App {
    @StateObject private var store  = ArtistStore()
    @StateObject private var player = AudioPlayer()

    @State private var selectedArtistID: UUID?
    @State private var showingAddArtist = false

    var body: some Scene {
        WindowGroup {
            TabView {
                // ───────── Artists tab ─────────
                ArtistsTab(
                    selectedArtistID: $selectedArtistID,
                    showingAddArtist: $showingAddArtist
                )
                .environmentObject(store)
                .environmentObject(player)
                .tabItem { Label("Artists", systemImage: "music.mic") }

                // ───────── Import tab ─────────
                ImportTab()                       // uses FileSystemView internally
                    .environmentObject(store)
                    .environmentObject(player)
                    .tabItem { Label("Import", systemImage: "tray.and.arrow.down") }
            }
            .onAppear { registerForDragAndDrop() }
        }
        // Space-bar play / pause
        .commands {
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    player.isPlaying ? player.pause() : player.play()
                }
                .keyboardShortcut(" ", modifiers: [])
            }
        }
    }

    // MARK: – Global drag registration (macCatalyst)
    private func registerForDragAndDrop() {
        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { win in
                    win.rootViewController?.view.addInteraction(
                        UIDragInteraction(delegate: RootDragDelegate())
                    )
                }
        }
        #endif
    }
}

#if targetEnvironment(macCatalyst)
class RootDragDelegate: NSObject, UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction,
                         itemsForBeginning session: UIDragSession) -> [UIDragItem] { [] }
}
#endif
