import SwiftUI

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
        }
    }
}
