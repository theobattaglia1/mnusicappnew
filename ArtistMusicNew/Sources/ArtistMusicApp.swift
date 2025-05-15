import SwiftUI
import UniformTypeIdentifiers

@main
struct ArtistMusicApp: App {
    @StateObject private var store  = ArtistStore()
    @StateObject private var player = AudioPlayer()

    @State private var selectedArtistID: UUID?
    @State private var showingAddArtist = false

    var body: some Scene {
        WindowGroup {
            TabView {
                // ───────── ARTISTS TAB ─────────
                ZStack(alignment: .bottom) {
                    NavigationStack {
                        if let id = selectedArtistID ?? store.artists.first?.id {
                            ArtistDetailView(
                                artistID: id,
                                selectedArtistID: $selectedArtistID
                            )
                            .environmentObject(store)
                            .environmentObject(player)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button { showingAddArtist = true } label: {
                                        Image(systemName: "plus")
                                    }
                                }
                            }
                            .sheet(isPresented: $showingAddArtist) {
                                AddArtistSheet(selectedArtistID: $selectedArtistID)
                                    .environmentObject(store)
                            }
                        } else {
                            // No artists yet → prompt to create
                            VStack(spacing: 16) {
                                Text("No artists yet")
                                Button("Add Artist") {
                                    showingAddArtist = true
                                }
                            }
                            .sheet(isPresented: $showingAddArtist) {
                                AddArtistSheet(selectedArtistID: $selectedArtistID)
                                    .environmentObject(store)
                            }
                        }
                    }

                    // Now‐playing bar at bottom
                    if player.current != nil {
                        NowPlayingBar()
                            .environmentObject(player)
                            .transition(.move(edge: .bottom))
                    }
                }
                .tabItem { Label("Artists", systemImage: "music.mic") }

                // ───────── IMPORT TAB ─────────
                ZStack(alignment: .bottom) {
                    FileSystemView()
                        .environmentObject(store)
                        .environmentObject(player)

                    if player.current != nil {
                        NowPlayingBar()
                            .environmentObject(player)
                            .transition(.move(edge: .bottom))
                    }
                }
                .tabItem { Label("Import", systemImage: "tray.and.arrow.down") }
            }
            .onAppear {
                registerForDragAndDrop()
            }
        }
    }
    
    // Register for drag and drop events at the application level
    private func registerForDragAndDrop() {
        #if targetEnvironment(macCatalyst)
        // Add a slight delay to ensure the scene is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔵 Registering for global drag and drop")
            let dragTypes = [
                UTType.audio.identifier,
                UTType.fileURL.identifier,
                "com.apple.finder.node",
                "com.apple.m4a-audio",
                "com.microsoft.waveform-audio",
                "public.mp3"
            ]
            
            // Register on all available scenes
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .forEach { windowScene in
                    windowScene.windows.forEach { window in
                        if let rootView = window.rootViewController?.view {
                            for dragType in dragTypes {
                                rootView.addInteraction(UIDragInteraction(delegate: RootDragDelegate()))
                                print("🔵 Registered type: \(dragType)")
                            }
                        }
                    }
                }
            
            // Optionally also register on the application
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
    }
}

#if targetEnvironment(macCatalyst)
// Simple delegate to enable drag interactions app-wide
class RootDragDelegate: NSObject, UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        return [] // This is just to enable drop reception
    }
}
#endif
